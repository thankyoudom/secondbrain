#!/usr/bin/env bash
# zk-tags-suggest.sh
#
# Step 3 of the tag pipeline (run after zk-tags-normalize.sh --apply):
#   1. normalize            (dry run, see the mess)
#   2. normalize --apply    (one consistent format)
#   3. THIS SCRIPT          (content-aware: prefer existing vocab tags)
#   4. normalize --apply    (fold any new tags into the same format)
#
# Per note: feeds the model the note body + the current vocabulary
# (from .zk-tags-reference.md, built by zk-tags-normalize.sh) and asks
# it to output an updated tag list — preferring an existing tag from
# the vocabulary over inventing a new one, only adding a new tag when
# nothing on the list genuinely fits.
#
# Only the `tags:` field is rewritten. The rest of the file (including
# body) is never touched, unlike zk-cleanup-batch.sh's full-file edit —
# this step only needs judgment about tags, so that's the only blast
# radius.
#
# Usage:
#   ./zk-tags-suggest.sh [VAULT_DIR]
#   ./zk-tags-suggest.sh [VAULT_DIR] --max-tags N     (default 5 per note)
#   ./zk-tags-suggest.sh --file PATH [--max-tags N]

set -uo pipefail

VAULT_DIR="${1:-$HOME/Documents/repos/secondbrain}"
SINGLE_FILE=""
MAX_TAGS=5
VOCAB_LIMIT=80

if [ "${1:-}" = "--file" ]; then
  VAULT_DIR="$HOME/Documents/repos/secondbrain"
  SINGLE_FILE="$2"
elif [ "${2:-}" = "--file" ]; then
  SINGLE_FILE="$3"
fi
prev=""
for i in "$@"; do
  if [ "$prev" = "--max-tags" ]; then MAX_TAGS="$i"; fi
  prev="$i"
done

REF_FILE="$VAULT_DIR/.zk-tags-reference.md"
LOG_FILE="$VAULT_DIR/.zk-tag-suggest.log"
DONE_FILE="$VAULT_DIR/.zk-tag-suggest-done.txt"
FILE_LIST="$VAULT_DIR/.zk-tag-suggest-filelist.txt"

touch "$LOG_FILE" "$DONE_FILE"

if [ ! -f "$REF_FILE" ]; then
  echo "No $REF_FILE found. Run zk-tags-normalize.sh --apply first." >&2
  exit 1
fi

# pull the top VOCAB_LIMIT tags (by frequency) out of the reference
# file's markdown table into a plain comma list for the prompt
VOCAB=$(awk -F'|' 'NR>4 && NF>=3 {gsub(/^[ \t]+|[ \t]+$/,"",$2); if($2!="" && $2 !~ /^-+$/) print $2}' "$REF_FILE" \
  | head -n "$VOCAB_LIMIT" | paste -sd ',' -)

normalize_tag() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E "s/^[[:space:]\"']+//; s/[[:space:]\"']+\$//" \
    | sed -E 's/[_ ]+/-/g; s/[^a-z0-9-]//g; s/-+/-/g; s/^-//; s/-$//'
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

strip_frontmatter_body() {
  awk 'NR==1 && $0 ~ /^---[[:space:]]*$/ {infm=1; c=1; next} infm && $0 ~ /^---[[:space:]]*$/ {c++; if(c==2){infm=0}; next} !infm {print}' "$1"
}

build_normalized_block() {
  local tags=() raw n
  while IFS= read -r raw; do
    [ -z "$raw" ] && continue
    n=$(normalize_tag "$raw")
    [ -z "$n" ] && continue
    tags+=("$n")
  done
  if [ "${#tags[@]}" -eq 0 ]; then echo "tags: []"; return; fi
  printf '%s\n' "${tags[@]}" | sort -u | head -n "$MAX_TAGS" | awk 'BEGIN{print "tags:"} {print "  - " $0}'
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
FAILED=0
echo "Found $TOTAL markdown files under $VAULT_DIR"
echo "Vocabulary: $(printf '%s' "$VOCAB" | tr ',' '\n' | wc -l | tr -d ' ') existing tags loaded from $REF_FILE"
echo

while IFS= read -r FILE; do
  COUNT=$((COUNT + 1))
  if grep -qxF "$FILE" "$DONE_FILE"; then
    printf "\r[%d/%d] skip (already done): %s" "$COUNT" "$TOTAL" "$FILE"
    continue
  fi
  REL="${FILE#$VAULT_DIR/}"
  printf "\r[%d/%d] processing: %s" "$COUNT" "$TOTAL" "$REL"

  CURRENT_TAGS=$(extract_raw_tags "$FILE" | tr '\n' ',' | sed 's/,$//')
  BODY=$(strip_frontmatter_body "$FILE")

  PROMPT="You are choosing tags for a note in my personal Zettelkasten.
Existing tag vocabulary (prefer reusing one of these if it genuinely fits):
$VOCAB

Current tags on this note: $CURRENT_TAGS

Note content:
--- NOTE START ---
$BODY
--- NOTE END ---

Rules:
- Prefer a tag from the existing vocabulary above over inventing a new one.
- Only invent a new tag if nothing in the vocabulary reasonably covers the note's topic.
- Lowercase, hyphenated, no spaces.
- At most $MAX_TAGS tags. At least 1.
- Do not tag based on formatting, length, or metadata — only actual topic/content.

Respond with ONLY the tags, one per line, nothing else — no preamble, no bullets, no explanation, no code fences."

  RAW_OUTPUT=$(cd "$VAULT_DIR" && opencode run "$PROMPT" < /dev/null 2>>"$LOG_FILE")
  CLEANED=$(printf '%s\n' "$RAW_OUTPUT" | sed '/^> build/d' | sed '/^```/d' | sed '/^-/s/^- *//' | sed '/^[[:space:]]*$/d')

  # sanity checks: at least one line, none look like a sentence (has a
  # space after normalization would strip it down to nothing meaningful)
  NUM_LINES=$(printf '%s\n' "$CLEANED" | grep -c .)
  BAD=0
  while IFS= read -r line; do
    n=$(normalize_tag "$line")
    [ -z "$n" ] && BAD=1
  done <<< "$CLEANED"

  if [ "$NUM_LINES" -ge 1 ] && [ "$NUM_LINES" -le $((MAX_TAGS + 2)) ] && [ "$BAD" -eq 0 ]; then
    NEWBLOCK=$(printf '%s\n' "$CLEANED" | build_normalized_block)
    NEW_CONTENT=$(rewrite_file_tags "$FILE" "$NEWBLOCK")
    if [ "$NEW_CONTENT" != "$(cat "$FILE")" ]; then
      printf '%s\n' "$NEW_CONTENT" > "$FILE"
      CHANGED=$((CHANGED + 1))
      echo "OK: $REL -> $(printf '%s\n' "$CLEANED" | tr '\n' ',' | sed 's/,$//')" >> "$LOG_FILE"
    fi
    echo "$FILE" >> "$DONE_FILE"
  else
    FAILED=$((FAILED + 1))
    echo "FAILED (bad output, lines=$NUM_LINES): $REL" >> "$LOG_FILE"
    echo "--- raw output was: ---" >> "$LOG_FILE"
    printf '%s\n' "$RAW_OUTPUT" >> "$LOG_FILE"
    echo "--- end raw output ---" >> "$LOG_FILE"
  fi
done < "$FILE_LIST"

echo
echo
echo "Done. $CHANGED files updated, $FAILED failed (unchanged, see $LOG_FILE)."
echo "Run zk-tags-normalize.sh --apply next to fold new tags into one format"
echo "and refresh the vocabulary reference file."
