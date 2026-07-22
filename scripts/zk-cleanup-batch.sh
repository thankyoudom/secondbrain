#!/usr/bin/env bash
# zk-cleanup-batch.sh
# Runs the /zk-clean custom OpenCode command across every .md file in the
# vault, one fresh session per file, with progress + resumability.
#
# Requires: ~/.config/opencode/command/zk-clean.md already installed.

set -uo pipefail

VAULT_DIR="${1:-$HOME/Documents/repos/secondbrain}"
LOG_FILE="$VAULT_DIR/.zk-cleanup.log"
DONE_FILE="$VAULT_DIR/.zk-cleanup-done.txt"

touch "$DONE_FILE" "$LOG_FILE"

mapfile -t FILES < <(find "$VAULT_DIR" -type f -name '*.md' | sort)
TOTAL=${#FILES[@]}
COUNT=0
SKIPPED=0
FAILED=0

echo "Found $TOTAL markdown files under $VAULT_DIR"
echo "Progress + errors logged to: $LOG_FILE"
echo "Resumable via: $DONE_FILE"
echo

for FILE in "${FILES[@]}"; do
  COUNT=$((COUNT + 1))

  if grep -qxF "$FILE" "$DONE_FILE"; then
    SKIPPED=$((SKIPPED + 1))
    printf "\r[%d/%d] skip (already done): %s" "$COUNT" "$TOTAL" "$FILE"
    continue
  fi

  REL_FILE="${FILE#$VAULT_DIR/}"

  printf "\r[%d/%d] processing: %s" "$COUNT" "$TOTAL" "$REL_FILE"

  if (cd "$VAULT_DIR" && opencode run "/zk-clean $REL_FILE" >> "$LOG_FILE" 2>&1); then
    echo "$FILE" >> "$DONE_FILE"
  else
    FAILED=$((FAILED + 1))
    echo "FAILED: $FILE" >> "$LOG_FILE"
  fi
done

echo
echo "Done. $((COUNT - SKIPPED)) processed, $SKIPPED skipped, $FAILED failed."
echo "Check $LOG_FILE for details on any failures."
