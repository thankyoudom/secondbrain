#!/usr/bin/env bash
# zk-tags-add-hubs.sh
#
# Appends a shared "hub" tag to any note carrying a specific tag mapped
# to it in .zk-tag-hubs.txt — WITHOUT removing the specific tag. Point
# is to surface clusters (e.g. all your islam-adjacent notes, all your
# mixing notes) in Obsidian's graph view / tag pane while keeping the
# granular tags intact for precise search.
#
# This is the opposite operation from zk-tags-normalize.sh's alias
# folding: aliases REPLACE (same tag, different spelling); hubs ADD
# (related tag, both stay).
#
# Run this after zk-tags-normalize.sh --apply, since it assumes tags
# are already in the block/kebab-case convention. Run
# zk-tags-normalize.sh (no --apply) again afterward to refresh the
# frequency reference file with the new hub-tag counts.
#
# Usage:
#   ./zk-tags-add-hubs.sh [VAULT_DIR]            dry run: report only
#   ./zk-tags-add-hubs.sh [VAULT_DIR] --apply    write changes
#   ./zk-tags-add-hubs.sh --file PATH [--apply]

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

HUBS_FILE="$VAULT_DIR/.zk-tag-hubs.txt"
LOG_FILE="$VAULT_DIR/.zk-tag-hubs.log"
DONE_FILE="$VAULT_DIR/.zk-tag-hubs-done.txt"
FILE_LIST="$VAULT_DIR/.zk-tag-hubs-filelist.txt"

touch "$LOG_FILE" "$DONE_FILE"

if [ ! -f "$HUBS_FILE" ]; then
  echo "No $HUBS_FILE found. Create it (specific-tag=hub-tag per line) first." >&2
  exit 1
fi

declare -A HUBMAP
while IFS='=' read -r k v; do
  [[ "$k" =~ ^[[:space:]]*# ]] && continue
  [ -z "$k" ] && continue
  [ -z "${v:-}" ] && continue
  HUBMAP["$k"]="$v"
done < "$HUBS_FILE"

extract_raw_tags() {
  awk '
    NR==1 && $0 ~ /^---[[:space:]]*$/ { infm=1; next }
    infm && $0 ~ /^---[[:space:]]*$/ { exit }
    infm && $0 ~ /^tags:[[:space:]]*\[/ {
      line=$0; sub(/^tags:[[:space:]]*\[/, "", line); sub(/\][[:space:]]*$/, "", line)
      n=split(line, parts, ","); for (i=1;i<=n;i++) print parts[i]; next
    }
    infm && $0 ~ /^tags:[[:space:]]*$/ { inlist=1; next }
    infm && inlist && $0 ~ /^[[:space:]]*-[[:space:]]+/ {
      line=$0; sub(/^[[:space:]]*-[[:space:]]+/, "", line); print line; next
    }
    infm && inlist { inlist=0 }
  ' "$1"
}

clean_tag() {
  printf '%s\n' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E "s/^[[:space:]\"']+//; s/[[:space:]\"']+\$//"
}

build_tag_block() {
  # reads tags on stdin (one per line, already final set) -> sorted block
  local tags=()
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    tags+=("$t")
  done
  if [ "${#tags[@]}" -eq 0 ]; then echo "tags: []"; return; fi
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
echo "Loaded ${#HUBMAP[@]} hub mappings from $HUBS_FILE"
echo "Mode: $([ "$APPLY" -eq 1 ] && echo APPLY || echo 'dry run (report only)')"
echo

while IFS= read -r FILE; do
  COUNT=$((COUNT + 1))
  REL="${FILE#$VAULT_DIR/}"

  if [ "$APPLY" -eq 1 ] && grep -qxF "$FILE" "$DONE_FILE"; then
    printf "\r[%d/%d] skip (already done): %s" "$COUNT" "$TOTAL" "$REL"
    continue
  fi

  mapfile -t ORIG_TAGS < <(extract_raw_tags "$FILE" | while IFS= read -r t; do clean_tag "$t"; done | grep -v '^$')

  declare -A FINAL
  ADDED=()
  for t in "${ORIG_TAGS[@]}"; do
    FINAL["$t"]=1
    hub="${HUBMAP[$t]:-}"
    if [ -n "$hub" ] && [ -z "${FINAL[$hub]:-}" ]; then
      FINAL["$hub"]=1
      ADDED+=("$hub (via $t)")
    fi
  done

  if [ "${#ADDED[@]}" -gt 0 ]; then
    printf "\r[%d/%d] +hubs: %s -> %s\n" "$COUNT" "$TOTAL" "$REL" "$(IFS=,; echo "${ADDED[*]}")"
    if [ "$APPLY" -eq 1 ]; then
      NEWBLOCK=$(printf '%s\n' "${!FINAL[@]}" | build_tag_block)
      NEW_CONTENT=$(rewrite_file_tags "$FILE" "$NEWBLOCK")
      printf '%s\n' "$NEW_CONTENT" > "$FILE"
      CHANGED=$((CHANGED + 1))
      echo "ADDED to $REL: $(IFS=,; echo "${ADDED[*]}")" >> "$LOG_FILE"
    fi
  else
    printf "\r[%d/%d] no change: %s" "$COUNT" "$TOTAL" "$REL"
  fi
  [ "$APPLY" -eq 1 ] && echo "$FILE" >> "$DONE_FILE"
  unset FINAL
done < "$FILE_LIST"

echo
echo
if [ "$APPLY" -eq 1 ]; then
  echo "Done. $CHANGED files gained hub tags. Log: $LOG_FILE"
  echo "Run zk-tags-normalize.sh (no --apply) next to refresh the frequency"
  echo "reference file with the new hub-tag counts."
else
  echo "Dry run complete — no files changed. Review the +hubs lines above,"
  echo "then re-run with --apply."
fi
