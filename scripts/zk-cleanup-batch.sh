#!/usr/bin/env bash
# zk-cleanup-batch.sh
# Runs the markdown-cleanup + tagging task across every .md file in the
# vault, one fresh opencode session per file, with progress + resumability.
#
# NOTE: does NOT rely on `@file` referencing or in-place file writing via
# opencode. Testing showed `opencode run --auto` passes "@path" through
# literally (including the "@") instead of resolving it to file content,
# so every file was silently failing with "File not found: .../@00_inbox/...".
# Instead: the file's content is inlined directly into the prompt, the
# model is asked to return the full edited file as plain text, and this
# script captures stdout and writes it back to disk itself.
set -uo pipefail
VAULT_DIR="${1:-$HOME/Documents/repos/secondbrain}"
LOG_FILE="$VAULT_DIR/.zk-cleanup.log"
DONE_FILE="$VAULT_DIR/.zk-cleanup-done.txt"
FILE_LIST="$VAULT_DIR/.zk-cleanup-filelist.txt"
TRASH_DIR="$VAULT_DIR/trash"
TRASH_LOG="$VAULT_DIR/.zk-trash-log.txt"
SMALL_WORD_THRESHOLD=20

touch "$DONE_FILE" "$LOG_FILE" "$TRASH_LOG"
mkdir -p "$TRASH_DIR"

# body word count with YAML frontmatter stripped
body_word_count() {
  awk '
    NR==1 && $0 ~ /^---[[:space:]]*$/ { infm=1; next }
    infm && $0 ~ /^---[[:space:]]*$/ { infm=0; next }
    infm { next }
    { print }
  ' "$1" | wc -w | tr -d ' '
}

find "$VAULT_DIR" -type f -name '*.md' -not -path "$TRASH_DIR/*" | sort > "$FILE_LIST"
TOTAL=$(wc -l < "$FILE_LIST" | tr -d ' ')
COUNT=0
SKIPPED=0
FAILED=0
TRASHED=0
echo "Found $TOTAL markdown files under $VAULT_DIR"
echo "Progress + errors logged to: $LOG_FILE"
echo "Resumable via: $DONE_FILE"
echo "Trash log: $TRASH_LOG"
echo
while IFS= read -r FILE; do
  COUNT=$((COUNT + 1))
  if grep -qxF "$FILE" "$DONE_FILE"; then
    SKIPPED=$((SKIPPED + 1))
    printf "\r[%d/%d] skip (already done): %s" "$COUNT" "$TOTAL" "$FILE"
    continue
  fi
  REL_FILE="${FILE#$VAULT_DIR/}"

  WC=$(body_word_count "$FILE")
  if [ "$WC" -le "$SMALL_WORD_THRESHOLD" ]; then
    printf "\r[%d/%d] trash (body: %s words): %s\n" "$COUNT" "$TOTAL" "$WC" "$REL_FILE"
    mkdir -p "$TRASH_DIR/$(dirname "$REL_FILE")"
    mv "$FILE" "$TRASH_DIR/$REL_FILE"
    echo "$REL_FILE — $WC words" >> "$TRASH_LOG"
    echo "$FILE" >> "$DONE_FILE"
    TRASHED=$((TRASHED + 1))
    continue
  fi

  printf "\r[%d/%d] processing: %s" "$COUNT" "$TOTAL" "$REL_FILE"

  CONTENT=$(cat "$FILE")
  PROMPT="Act as a Markdown editor for my Zettelkasten.
Below is the full content of a note. Improve its formatting without changing ideas.
Rules:
- Preserve every fact and idea. Never invent information. Never summarize.
- Preserve all code blocks and links exactly.
- Remove stray characters and accidental whitespace.
- Fix grammar and punctuation.
- Break long paragraphs into readable sections. Add headings where appropriate.
- Convert obvious lists into Markdown bullet lists.
- In the YAML frontmatter, add 1-2 tags to tags: [] based on actual content. Lowercase, hyphenated. Never invent a tag for a topic not covered.
- Leave title, date, and source-folder frontmatter fields unchanged.

Respond with ONLY the full updated file content, nothing else — no preamble, no explanation, no markdown code fences around it.

--- FILE CONTENT START ---
$CONTENT
--- FILE CONTENT END ---"

  # NOTE: no --auto here. --auto is opencode's agentic mode, which grants
  # tool access (file search etc). On a plain formatting task it went off
  # and pulled unrelated files from across the vault into the output. This
  # needs to be a plain completion, not an agent session.
  RAW_OUTPUT=$(cd "$VAULT_DIR" && opencode run "$PROMPT" 2>>"$LOG_FILE")

  # strip the CLI's own "> build · <model>" status line and any stray
  # code-fence wrapper the model might add despite instructions not to
  CLEANED=$(printf '%s\n' "$RAW_OUTPUT" | sed '/^> build/d' | sed '/^```/d')

  # This model has a habit of tacking on agentic-style scaffolding after
  # finishing the actual edit (## Objective, ## Work State, ## Relevant
  # Files, ## Next Move). None of that belongs in a note. Truncate at the
  # first such marker and keep only what came before it.
  CLEANED=$(printf '%s\n' "$CLEANED" | awk '
    /^## (Objective|Work State|Relevant Files|Next Move|Important Details)[[:space:]]*$/ { exit }
    { print }
  ')
  # trim trailing blank lines left over from the truncation
  CLEANED=$(printf '%s\n' "$CLEANED" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

  FIRST_LINE=$(printf '%s\n' "$CLEANED" | head -n1)
  IN_WC=$(printf '%s\n' "$CONTENT" | wc -w | tr -d ' ')
  OUT_WC=$(printf '%s\n' "$CLEANED" | wc -w | tr -d ' ')
  # flag degenerate repetition: count lines appearing 5+ times
  DUPE_LINES=$(printf '%s\n' "$CLEANED" | sort | uniq -c | awk '$1>=5' | wc -l | tr -d ' ')

  # sanity checks — do NOT overwrite the original file unless all pass:
  # 1. starts with YAML frontmatter
  # 2. output isn't wildly longer than input (formatting shouldn't 3x+ the word count)
  # 3. no significant duplicate-line repetition (degenerate small-model loop)
  if [ "$FIRST_LINE" = "---" ] && [ -n "$CLEANED" ] \
     && [ "$OUT_WC" -le $((IN_WC * 3 + 50)) ] \
     && [ "$DUPE_LINES" -eq 0 ]; then
    printf '%s\n' "$CLEANED" > "$FILE"
    echo "$FILE" >> "$DONE_FILE"
    echo "OK: $REL_FILE (in=$IN_WC words, out=$OUT_WC words)" >> "$LOG_FILE"
  else
    FAILED=$((FAILED + 1))
    echo "FAILED (bad output, in=$IN_WC out=$OUT_WC dupe_lines=$DUPE_LINES): $REL_FILE" >> "$LOG_FILE"
    echo "--- raw output was: ---" >> "$LOG_FILE"
    printf '%s\n' "$RAW_OUTPUT" >> "$LOG_FILE"
    echo "--- end raw output ---" >> "$LOG_FILE"
  fi
done < "$FILE_LIST"
echo
echo "Done. $((COUNT - SKIPPED - TRASHED)) processed, $TRASHED trashed, $SKIPPED skipped, $FAILED failed."
echo "Check $LOG_FILE for details on any failures."
