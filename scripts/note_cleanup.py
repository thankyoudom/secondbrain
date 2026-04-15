#!/usr/bin/env python3
"""
note_cleanup.py

Cleans up brain-dump notes in 00_inbox/ using a local Ollama LLM.
Rewrites messy Q&A/chat-formatted notes into clean prose with atomic insights.
Saves cleaned versions to 00_inbox/cleaned/ and leaves originals untouched.

Usage:
    python3 note_cleanup.py --zk-root ~/SecondBrain
    python3 note_cleanup.py --zk-root ~/SecondBrain --model llama3.1
    python3 note_cleanup.py --zk-root ~/SecondBrain --dry-run
"""

import argparse
import re
import sys
import time
from pathlib import Path

import requests

# ---------------------------------------------------------------------------
# Ollama
# ---------------------------------------------------------------------------

OLLAMA_URL = "http://localhost:11434/api/generate"

SYSTEM_PROMPT = """\
You are a personal knowledge management assistant. Your job is to clean up messy \
brain-dump notes exported from a chat or AI conversation into clean, readable \
Markdown notes for a Zettelkasten second brain.

Rules:
- Rewrite the body into clear, flowing prose. Remove all Q&A formatting, chatbot \
  preambles ("Great question!", "Here's the breakdown:", etc.), and filler phrases.
- Preserve every meaningful idea — do not drop insights.
- Fix broken formatting: convert weird bullet symbols (•, ·, ?, ?) to proper \
  Markdown dashes, fix broken tables, clean up headers.
- Extract the most important ideas as a short "## Key Insights" bullet list \
  at the TOP of the note, before the prose body.
- Keep the prose under the key insights, organized with clean ## headers.
- Do NOT rewrite the YAML frontmatter — output only the note body (everything \
  after the frontmatter closing ---).
- Do NOT add any preamble or explanation. Output ONLY the cleaned Markdown body.
- Maintain a neutral, first-person-friendly tone suitable for personal notes.
"""

def call_ollama(model: str, note_body: str, timeout: int = 120) -> str:
    prompt = f"Clean up this brain-dump note:\n\n{note_body}"
    payload = {
        "model": model,
        "prompt": prompt,
        "system": SYSTEM_PROMPT,
        "stream": False,
        "options": {
            "temperature": 0.3,
            "num_predict": 2048,
        },
    }
    try:
        resp = requests.post(OLLAMA_URL, json=payload, timeout=timeout)
        resp.raise_for_status()
        return resp.json().get("response", "").strip()
    except requests.exceptions.ConnectionError:
        print("\n  ERROR: Cannot connect to Ollama. Is it running? (ollama serve)")
        raise
    except requests.exceptions.Timeout:
        print(f"\n  ERROR: Ollama timed out after {timeout}s.")
        raise


def check_ollama_available(model: str) -> bool:
    try:
        resp = requests.get("http://localhost:11434/api/tags", timeout=5)
        tags = resp.json().get("models", [])
        names = [m.get("name", "").split(":")[0] for m in tags]
        model_base = model.split(":")[0]
        if model_base not in names:
            print(f"  WARNING: Model '{model}' not found in Ollama.")
            print(f"  Available: {names}")
            print(f"  Run: ollama pull {model}")
            return False
        return True
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Note parsing
# ---------------------------------------------------------------------------

FRONTMATTER_RE = re.compile(r"^---\n.*?\n---\n", re.DOTALL)

def split_frontmatter(text: str):
    """Returns (frontmatter_str, body_str). frontmatter_str includes --- delimiters."""
    m = FRONTMATTER_RE.match(text)
    if m:
        return m.group(0), text[m.end():]
    return "", text


def looks_like_brain_dump(body: str) -> bool:
    """Heuristic: is this note a messy brain dump worth cleaning?"""
    signals = [
        # Chatbot preamble patterns
        r"(here'?s? (a |the )?(breakdown|dissection|map|insight|truth|move|flow|key)|let'?s (zoom|map|break|look))",
        # Section emoji decorators common in AI outputs
        r"^[?????]\s",
        # Heavy Q&A structure
        r"\|\s+•\s+\|",
        # "The X" heading style typical in AI lists
        r"^\d+\.\s+The \"",
    ]
    for pattern in signals:
        if re.search(pattern, body, re.IGNORECASE | re.MULTILINE):
            return True
    # Also flag if it has lots of table rows (from messy import)
    table_rows = len(re.findall(r"^\|", body, re.MULTILINE))
    if table_rows > 8:
        return True
    return False


def is_technical_reference(body: str) -> bool:
    """Skip notes that are command references, code-heavy, or already clean."""
    code_blocks = len(re.findall(r"```", body))
    if code_blocks >= 4:
        return True
    if re.search(r"(kubectl|docker|gcloud|k3s|bash|kubectl)", body, re.IGNORECASE):
        if code_blocks >= 2:
            return True
    return False


# ---------------------------------------------------------------------------
# Progress bar
# ---------------------------------------------------------------------------

def format_duration(seconds: float) -> str:
    if seconds < 60:
        return f"{int(seconds)}s"
    m, s = divmod(int(seconds), 60)
    return f"{m}m{s:02d}s"


def print_progress(current: int, total: int, completed_times: list, note_name: str, status: str):
    pct = current / total if total else 0
    bar_width = 30
    filled = int(bar_width * pct)
    bar = "█" * filled + "░" * (bar_width - filled)

    if len(completed_times) >= 2:
        # Use median of last 5 completed notes for a stable estimate
        recent = completed_times[-5:]
        avg = sum(recent) / len(recent)
        remaining_secs = avg * (total - current)
        finish_at = time.time() + remaining_secs
        finish_str = time.strftime("%-I:%M %p", time.localtime(finish_at))
        time_left = format_duration(remaining_secs)
        eta = f"done ~{finish_str} ({time_left} left)"
    else:
        eta = "ETA: calculating..."

    name = note_name[:25].ljust(25)
    print(
        f"\r[{bar}] {current}/{total} ({pct:.0%})  {eta}  {status:<8}  {name}",
        end="",
        flush=True,
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Clean up 00_inbox notes with Ollama")
    parser.add_argument("--zk-root", required=True, help="Path to your SecondBrain root")
    parser.add_argument("--model", default="llama3.1", help="Ollama model name (default: llama3.1)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be processed, no writes")
    parser.add_argument("--timeout", type=int, default=300, help="Per-note Ollama timeout in seconds (default: 300)")
    parser.add_argument("--limit", type=int, default=0, help="Only process first N notes (for testing)")
    parser.add_argument("--force", action="store_true", help="Re-clean notes that already have a cleaned version")
    args = parser.parse_args()

    zk_root = Path(args.zk_root).expanduser()
    inbox = zk_root / "00_inbox"
    cleaned_dir = inbox / "cleaned"

    if not inbox.exists():
        print(f"ERROR: 00_inbox not found at {inbox}")
        sys.exit(1)

    if not args.dry_run:
        cleaned_dir.mkdir(exist_ok=True)

    # Gather candidates
    all_notes = sorted(inbox.glob("*.md"))
    candidates = []
    skipped_technical = []
    skipped_clean = []

    for note_path in all_notes:
        text = note_path.read_text(encoding="utf-8")
        _, body = split_frontmatter(text)

        if is_technical_reference(body):
            skipped_technical.append(note_path.name)
            continue

        if not looks_like_brain_dump(body):
            skipped_clean.append(note_path.name)
            continue

        # Skip if already cleaned (unless --force)
        dest = cleaned_dir / note_path.name
        if dest.exists() and not args.force:
            skipped_clean.append(note_path.name)
            continue

        candidates.append(note_path)

    if args.limit:
        candidates = candidates[:args.limit]

    print(f"\n{'='*60}")
    print(f"  note_cleanup.py  —  SecondBrain: {zk_root}")
    print(f"{'='*60}")
    print(f"  Model          : {args.model}")
    print(f"  Output folder  : {cleaned_dir}")
    print(f"  Notes to clean : {len(candidates)}")
    print(f"  Skipped (tech) : {len(skipped_technical)}")
    print(f"  Skipped (clean): {len(skipped_clean)}")
    if args.dry_run:
        print(f"  DRY RUN — no files will be written")
    print(f"{'='*60}\n")

    if skipped_technical:
        print("Skipping technical/code-heavy notes:")
        for n in skipped_technical:
            print(f"  ✗ {n}")
        print()

    if not candidates:
        print("Nothing to clean. All done!")
        return

    if args.dry_run:
        print("Would clean:")
        for p in candidates:
            print(f"  → {p.name}")
        return

    # Check Ollama
    print("Checking Ollama connection...", end=" ")
    if not check_ollama_available(args.model):
        print()
        sys.exit(1)
    print("OK\n")

    # Process
    stats = {"cleaned": 0, "errors": 0, "skipped_long": 0}
    start_time = time.time()
    completed_times = []  # track actual per-note durations for better ETA

    MAX_CHARS = 8000  # notes longer than this get skipped (too slow for LLM)

    print()  # blank line before progress bar

    for i, note_path in enumerate(candidates, 1):
        elapsed = time.time() - start_time
        print_progress(i - 1, len(candidates), completed_times, note_path.stem, "reading")

        text = note_path.read_text(encoding="utf-8")
        frontmatter, body = split_frontmatter(text)

        if len(body) > MAX_CHARS:
            stats["skipped_long"] += 1
            print(f"\n  SKIP (too long {len(body):,} chars): {note_path.name}")
            continue

        print_progress(i - 1, len(candidates), completed_times, note_path.stem, "cleaning")

        note_start = time.time()
        try:
            cleaned_body = call_ollama(args.model, body, timeout=args.timeout)
        except Exception:
            stats["errors"] += 1
            print(f"\n  FAILED: {note_path.name}")
            continue

        completed_times.append(time.time() - note_start)

        # Reassemble: original frontmatter + cleaned body
        cleaned_note = frontmatter + "\n" + cleaned_body + "\n"
        dest = cleaned_dir / note_path.name
        dest.write_text(cleaned_note, encoding="utf-8")
        stats["cleaned"] += 1

    elapsed = time.time() - start_time
    print_progress(len(candidates), len(candidates), completed_times, "done", "done")
    print()  # newline after progress bar

    print(f"\n{'='*60}")
    print(f"  Finished in {format_duration(elapsed)}")
    print(f"  Cleaned      : {stats['cleaned']}")
    print(f"  Errors       : {stats['errors']}")
    print(f"  Skipped long : {stats['skipped_long']}")
    print(f"  Output       : {cleaned_dir}")
    print(f"{'='*60}")
    print()
    print("Next steps:")
    print("  1. Review cleaned notes in 00_inbox/cleaned/")
    print("  2. Move the ones you're happy with back to 00_inbox/ (replacing originals)")
    print("  3. zk index   ← rebuild the zk index")


if __name__ == "__main__":
    main()
