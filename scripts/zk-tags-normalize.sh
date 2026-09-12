#!/usr/bin/env bash
# zk-tags-normalize.sh
#
# Audits and normalizes YAML frontmatter tags across the vault into one
# convention: a block-style list, lowercase-kebab-case, alphabetically
# sorted:
#   tags:
#     - tag-one
#     - tag-two
#
# Handles both existing conventions found in the vault:
#   tags: [a, b]          (flow style)
#   tags:
#     - a
#     - b                 (block style)
#
# Also builds a tag-frequency reference file (for search) and flags
# likely near-duplicate tags (same letters, different formatting).
#
# This is a pure text transform — no model calls, no non-determinism —
# so unlike zk-cleanup-batch.sh it doesn't need output sanity-checking,
# just the same resumability pattern for --apply on large vaults.
#
# Usage:
#   ./zk-tags-normalize.sh [VAULT_DIR]             dry run: report only
#   ./zk-tags-normalize.sh [VAULT_DIR] --apply     rewrite files in place
#   ./zk-tags-normalize.sh --file PATH [--apply]   single file
#
# Optional: $VAULT_DIR/.zk-tag-aliases.txt, one mapping per line:
#   musicprod=music-production
# Known synonyms get folded into the canonical tag on normalize.

set -uo pipefail

VAULT_DIR="${1:-$HOME/Documents/repos/secondbrain}"
APPLY=0
SINGLE_FILE=""

for arg in "$@"; do
  [ "$arg" = "--apply" ] && APPLY=1
done
if [ "${1:-}" = "--file" ]; then
  VAULT_DIR="$HOME/Documents/repos/secondbrain"
  SINGLE_FILE="$2"
elif [ "${2:-}" = "--file" ]; then
  SINGLE_FILE="$3"
fi

REF_FILE="$VAULT_DIR/.zk-tags-reference.md"
ALIAS_FILE="$VAULT_DIR/.zk-tag-aliases.txt"
LOG_FILE="$VAULT_DIR/.zk-tag-normalize.log"
DONE_FILE="$VAULT_DIR/.zk-tag-normalize-done.txt"
FILE_LIST="$VAULT_DIR/.zk-tag-normalize-filelist.txt"
TMP_FREQ="$(mktemp)"
trap 'rm -f "$TMP_FREQ"' EXIT

touch "$LOG_FILE" "$DONE_FILE"
[ -f "$ALIAS_FILE" ] || touch "$ALIAS_FILE"

normalize_tag() {
  # lowercase, strip quotes/whitespace, spaces/underscores -> hyphens,
  # drop anything outside [a-z0-9-], collapse repeat hyphens
  local t canon
  t=$(printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E "s/^[[:space:]\"']+//; s/[[:space:]\"']+\$//" \
    | sed -E 's/[_ ]+/-/g' \
    | sed -E 's/[^a-z0-9-]//g' \
    | sed -E 's/-+/-/g; s/^-//; s/-$//')
  canon=$(awk -F= -v k="$t" '$1==k {print $2; f=1} END{if(!f) print ""}' "$ALIAS_FILE" 2>/dev/null)
  [ -n "$canon" ] && echo "$canon" || echo "$t"
}

extract_raw_tags() {
  # one raw (unnormalized) tag per line, from either style
  awk '
    NR==1 && $0 ~ /^---[[:space:]]*$/ { infm=1; next }
    infm && $0 ~ /^---[[:space:]]*$/ { exit }
    infm && $0 ~ /^tags:[[:space:]]*\[/ {
      line=$0
      sub(/^tags:[[:space:]]*\[/, "", line)
      sub(/\][[:space:]]*$/, "", line)
      n = split(line, parts, ",")
      for (i=1; i<=n; i++) print parts[i]
      next
    }
    infm && $0 ~ /^tags:[[:space:]]*$/ { inlist=1; next }
    infm && inlist && $0 ~ /^[[:space:]]*-[[:space:]]+/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]+/, "", line)
      print line
      next
    }
    infm && inlist { inlist=0 }
  ' "$1"
}

build_normalized_block() {
  # reads raw tags on stdin -> normalized, deduped, sorted block
  local tags=() raw n
  while IFS= read -r raw; do
    [ -z "$raw" ] && continue
    n=$(normalize_tag "$raw")
    [ -z "$n" ] && continue
    tags+=("$n")
  done
  if [ "${#tags[@]}" -eq 0 ]; then
    echo "tags: []"
    return
  fi
  printf '%s\n' "${tags[@]}" | sort -u | awk 'BEGIN{print "tags:"} {print "  - " $0}'
}

rewrite_file_tags() {
  local file="$1" newblock="$2"
  awk -v newblock="$newblock" '
    BEGIN { infm=0; done=0; skipping=0 }
    NR==1 && /^---[[:space:]]*$/ { infm=1; print; next }
    infm && /^---[[:space:]]*$/ { infm=0; print; next }
    infm && !done && /^tags:[[:space:]]*\[/ { print newblock; done=1; next }
    infm && !done && /^tags:[[:space:]]*$/ { print newblock; done=1; skipping=1; next }
    skipping && /^[[:space:]]*-[[:space:]]+/ { next }
    skipping { skipping=0 }
    { print }
  ' "$file"
}

# ---- build file list ----
if [ -n "$SINGLE_FILE" ]; then
  [[ "$SINGLE_FILE" != /* ]] && SINGLE_FILE="$VAULT_DIR/$SINGLE_FILE"
  [ -f "$SINGLE_FILE" ] || { echo "File not found: $SINGLE_FILE"; exit 1; }
  printf '%s\n' "$SINGLE_FILE" > "$FILE_LIST"
else
  find "$VAULT_DIR" -type f -name '*.md' -not -path "$VAULT_DIR/trash/*" | sort > "$FILE_LIST"
fi

TOTAL=$(wc -l < "$FILE_LIST" | tr -d ' ')
COUNT=0
CHANGED=0
echo "Found $TOTAL markdown files under $VAULT_DIR"
echo "Mode: $([ "$APPLY" -eq 1 ] && echo APPLY || echo 'dry run (report only)')"
echo

while IFS= read -r FILE; do
  COUNT=$((COUNT + 1))
  REL="${FILE#$VAULT_DIR/}"

  RAW=$(extract_raw_tags "$FILE")
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    n=$(normalize_tag "$r")
    [ -n "$n" ] && echo "$n" >> "$TMP_FREQ"
  done <<< "$RAW"

  if [ "$APPLY" -eq 1 ]; then
    if grep -qxF "$FILE" "$DONE_FILE"; then
      printf "\r[%d/%d] skip (already normalized): %s" "$COUNT" "$TOTAL" "$REL"
      continue
    fi
    NEWBLOCK=$(printf '%s\n' "$RAW" | build_normalized_block)
    NEW_CONTENT=$(rewrite_file_tags "$FILE" "$NEWBLOCK")
    if [ "$NEW_CONTENT" != "$(cat "$FILE")" ]; then
      printf '%s\n' "$NEW_CONTENT" > "$FILE"
      CHANGED=$((CHANGED + 1))
      echo "NORMALIZED: $REL" >> "$LOG_FILE"
    fi
    echo "$FILE" >> "$DONE_FILE"
    printf "\r[%d/%d] done: %s" "$COUNT" "$TOTAL" "$REL"
  else
    printf "\r[%d/%d] scanned: %s" "$COUNT" "$TOTAL" "$REL"
  fi
done < "$FILE_LIST"
echo
echo

# ---- frequency reference file ----
{
  echo "# Tag reference"
  echo "_generated $(date '+%Y-%m-%d %H:%M') — $TOTAL notes scanned_"
  echo
  echo "| tag | count |"
  echo "|---|---|"
  sort "$TMP_FREQ" | uniq -c | sort -rn | awk '{c=$1; $1=""; sub(/^ /,""); print "| " $0 " | " c " |"}'
  echo
  echo "## Possible near-duplicates (same letters, different formatting)"
  echo
  DUPES=$(sort -u "$TMP_FREQ" | awk '
    {
      tag=$0; key=tag; gsub(/-/, "", key)
      group[key] = (group[key]=="" ? tag : group[key] ", " tag)
      cnt[key]++
    }
    END { for (k in cnt) if (cnt[k] > 1) print "- " group[k] }
  ')
  if [ -n "$DUPES" ]; then
    echo "$DUPES"
  else
    echo "_none found_"
  fi
} > "$REF_FILE"

echo "Tag reference written to: $REF_FILE"
[ "$APPLY" -eq 1 ] && echo "$CHANGED files normalized. Log: $LOG_FILE"
echo
echo "Tip: add lines like 'oldtag=canonical-tag' to $ALIAS_FILE to fold"
echo "near-duplicates from the reference file together on the next run."
