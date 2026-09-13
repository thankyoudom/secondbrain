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

# NOTE: this script intentionally avoids associative arrays (`declare -A`)
# and `mapfile`/`readarray` — both are bash 4+ only. macOS ships bash 3.2
# as /bin/bash (last GPLv2 release; Apple never upgraded it), so any
# script relying on them fails there with "declare: -A: invalid option"
# followed by confusing knock-on errors as the rest of the script treats
# the half-created array as a normal indexed one.
CLEAN_HUBS="$(mktemp)"
trap 'rm -f "$CLEAN_HUBS"' EXIT
grep -v '^[[:space:]]*#' "$HUBS_FILE" | grep -v '^[[:space:]]*$' | grep '=' > "$CLEAN_HUBS" || true
HUB_COUNT=$(wc -l < "$CLEAN_HUBS" | tr -d ' ')

lookup_hub() {
  # specific-tag -> hub-tag, or empty if none. Exact-match on the left
  # side of "key=value" lines in the cleaned hubs file.
  awk -F'=' -v k="$1" '$1==k{print $2; exit}' "$CLEAN_HUBS"
}

array_contains() {
  # array_contains needle "${arr[@]-}"  — bash-3.2-safe: expanding an
  # empty/unset array under `set -u` with plain "${arr[@]}" throws
  # "unbound variable" on bash <4.4, so every call site below passes
  # "${arr[@]-}" (note the -) instead.
  local needle="$1"; shift
  local x
  for x in "$@"; do
    [ "$x" = "$needle" ] && return 0
  done
  return 1
}

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
  local file="$1" newblock="$2" newblock_esc
  # awk -v assignments containing a literal newline byte fail to parse on
  # BWK/"one true awk" (macOS /usr/bin/awk, Debian's original-awk) with
  # "newline in string ... at source line 1", producing empty stdout.
  # gawk tolerates it silently, which is why this only broke on macOS.
  # Fix: escape real newlines to the two-char sequence \n in bash first
  # (safe for -v on every awk), then unescape them back to real newlines
  # inside the awk program before printing.
  newblock_esc=$(printf '%s' "$newblock" | awk 'NR>1{printf "\\n"} {printf "%s", $0}')
  awk -v newblock="$newblock_esc" '
    BEGIN { infm=0; done=0; skipping=0; gsub(/\\n/, "\n", newblock) }
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
echo "Loaded $HUB_COUNT hub mappings from $HUBS_FILE"
echo "Mode: $([ "$APPLY" -eq 1 ] && echo APPLY || echo 'dry run (report only)')"
echo

while IFS= read -r FILE; do
  COUNT=$((COUNT + 1))
  REL="${FILE#$VAULT_DIR/}"

  if [ "$APPLY" -eq 1 ] && grep -qxF "$FILE" "$DONE_FILE"; then
    printf "\r[%d/%d] skip (already done): %s" "$COUNT" "$TOTAL" "$REL"
    continue
  fi

  ORIG_TAGS=()
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    ORIG_TAGS+=("$t")
  done < <(extract_raw_tags "$FILE" | while IFS= read -r t; do clean_tag "$t"; done | grep -v '^$')

  FINAL_TAGS=()
  ADDED=()
  for t in "${ORIG_TAGS[@]-}"; do
    [ -z "$t" ] && continue
    array_contains "$t" "${FINAL_TAGS[@]-}" || FINAL_TAGS+=("$t")
    hub=$(lookup_hub "$t")
    if [ -n "$hub" ] && ! array_contains "$hub" "${FINAL_TAGS[@]-}"; then
      FINAL_TAGS+=("$hub")
      ADDED+=("$hub (via $t)")
    fi
  done

  if [ "${#ADDED[@]}" -gt 0 ]; then
    printf "\r[%d/%d] +hubs: %s -> %s\n" "$COUNT" "$TOTAL" "$REL" "$(IFS=,; echo "${ADDED[*]}")"
    if [ "$APPLY" -eq 1 ]; then
      NEWBLOCK=$(printf '%s\n' "${FINAL_TAGS[@]-}" | build_tag_block)
      NEW_CONTENT=$(rewrite_file_tags "$FILE" "$NEWBLOCK")
      # Guard against a failed/empty rewrite ever wiping the file (this is
      # exactly how the original -v newline bug destroyed content: awk
      # errored, NEW_CONTENT was empty, and it got written anyway).
      if [ -z "$NEW_CONTENT" ]; then
        echo "SKIPPED (empty rewrite output, file left untouched): $REL" >> "$LOG_FILE"
      else
        printf '%s\n' "$NEW_CONTENT" > "$FILE"
        CHANGED=$((CHANGED + 1))
        echo "ADDED to $REL: $(IFS=,; echo "${ADDED[*]}")" >> "$LOG_FILE"
      fi
    fi
  else
    printf "\r[%d/%d] no change: %s" "$COUNT" "$TOTAL" "$REL"
  fi
  [ "$APPLY" -eq 1 ] && echo "$FILE" >> "$DONE_FILE"
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
