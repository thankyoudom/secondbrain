#!/usr/bin/env python3
"""
import_to_zk.py

Converts ~/notes_export.json -> zk-compatible .md files in 00_inbox.
After this runs successfully, run mark_imported.applescript to move
the originals into Notes' "Imported" folder.

Usage:
    python3 import_to_zk.py --zk-root ~/Documents/repos/secondbrain
    python3 import_to_zk.py --zk-root ~/Documents/repos/secondbrain --dry-run
"""

import json
import re
import sys
import argparse
from pathlib import Path
from datetime import datetime


# ---------------------------------------------------------------------------
# URL helpers
# ---------------------------------------------------------------------------

URL_RE = re.compile(
    r"(https?://[^\s\)\]\>\"]+)",
    re.IGNORECASE,
)

MEDIA_KEYWORDS = re.compile(
    r"(youtube\.com|youtu\.be|spotify\.com|soundcloud\.com|"
    r"instagram\.com|tiktok\.com|twitter\.com|x\.com|"
    r"\.(mp3|mp4|wav|mov|pdf|png|jpg|jpeg|gif|webp))",
    re.IGNORECASE,
)


def is_pure_url_note(body: str) -> bool:
    """Return True if the note body contains nothing meaningful besides URLs."""
    stripped = body.strip()
    if not stripped:
        return False
    without_urls = URL_RE.sub("", stripped).strip()
    without_urls = re.sub(r"[\-\*•·\s]", "", without_urls)
    return len(without_urls) < 15


def has_links(body: str) -> bool:
    return bool(URL_RE.search(body))


def has_media_links(body: str) -> bool:
    return bool(MEDIA_KEYWORDS.search(body))


def linkify(body: str) -> str:
    """Convert bare URLs to markdown links."""
    def replace_url(m):
        url = m.group(1)
        start = m.start()
        if start > 0 and body[start - 1] == "(":
            return url
        domain_match = re.match(r"https?://(?:www\.)?([^/\s]+)", url)
        label = domain_match.group(1) if domain_match else url
        return f"[{label}]({url})"
    return URL_RE.sub(replace_url, body)


# ---------------------------------------------------------------------------
# Table helpers
# ---------------------------------------------------------------------------

def convert_tab_table(lines):
    rows = [l.split("\t") for l in lines]
    col_count = max(len(r) for r in rows)
    rows = [r + [""] * (col_count - len(r)) for r in rows]
    md_rows = []
    for i, row in enumerate(rows):
        cells = " | ".join(cell.strip() for cell in row)
        md_rows.append(f"| {cells} |")
        if i == 0:
            separator = "|" + "|".join([" --- "] * col_count) + "|"
            md_rows.append(separator)
    return "\n".join(md_rows)


def try_convert_table_block(block_lines):
    try:
        if any("\t" in l for l in block_lines):
            return convert_tab_table(block_lines), True
        return "\n".join(block_lines), True
    except Exception:
        code = "\n".join(block_lines)
        return f"```\n{code}\n```", False


# ---------------------------------------------------------------------------
# Markdown body cleanup
# ---------------------------------------------------------------------------

def slugify(text):
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-") or "untitled"


def clean_body(raw):
    """Best-effort plain-text -> Markdown. Returns (cleaned_text, has_table)."""
    if not raw:
        return "", False

    text = raw.replace("\r\n", "\n").replace("\r", "\n")
    text = linkify(text)
    lines = text.split("\n")
    result = []
    prev_blank = False
    has_table = False

    # Table detection pass
    i = 0
    processed_lines = []
    while i < len(lines):
        line = lines[i]
        if "\t" in line and len(line.split("\t")) >= 2:
            block = []
            while i < len(lines) and ("\t" in lines[i] or lines[i].strip() == ""):
                if lines[i].strip():
                    block.append(lines[i])
                i += 1
            if len(block) >= 2:
                converted, success = try_convert_table_block(block)
                processed_lines.append(converted)
                has_table = True
            else:
                processed_lines.extend(block)
        else:
            processed_lines.append(line)
            i += 1

    # Line-by-line cleanup
    for line in processed_lines:
        stripped = line.strip()

        if stripped == "":
            if not prev_blank and result:
                result.append("")
            prev_blank = True
            continue
        prev_blank = False

        bullet = re.match(r"^[•·\-\*]\s+(.+)$", stripped)
        if bullet:
            result.append(f"- {bullet.group(1)}")
            continue

        num = re.match(r"^(\d+)[.)]\s+(.+)$", stripped)
        if num:
            result.append(f"{num.group(1)}. {num.group(2)}")
            continue

        check = re.match(r"^[☐□]\s+(.+)$", stripped)
        if check:
            result.append(f"- [ ] {check.group(1)}")
            continue

        done = re.match(r"^[☑✓✔]\s+(.+)$", stripped)
        if done:
            result.append(f"- [x] {done.group(1)}")
            continue

        words = stripped.split()
        is_short = len(words) <= 6
        if is_short and stripped.isupper() and len(stripped) > 2 and not re.search(r"[.!?,;]", stripped):
            result.append(f"## {stripped.title()}")
            continue

        if stripped.endswith(":") and is_short and not stripped.startswith("-"):
            result.append(f"### {stripped.rstrip(':')}")
            continue

        if stripped.startswith("|"):
            result.append(stripped)
            has_table = True
            continue

        result.append(stripped)

    while result and result[0] == "":
        result.pop(0)
    while result and result[-1] == "":
        result.pop()

    return "\n".join(result), has_table


# ---------------------------------------------------------------------------
# Note assembly
# ---------------------------------------------------------------------------

def determine_flags(note, body):
    flags = []
    if note.get("has_attachments"):
        flags.append("has-attachments")
    if has_media_links(body):
        flags.append("has-media-links")
    elif has_links(body):
        flags.append("has-links")
    return flags


def build_frontmatter(title, created, folder, flags, has_table):
    tags = []
    if bool(flags) or has_table:
        tags.append(":needs-review:")
    for flag in flags:
        tags.append(f":{flag}:")
    if has_table:
        tags.append(":has-table:")

    lines = ["---", f"title: {title}", f"date: {created}", f"source-folder: {folder}"]
    if tags:
        lines.append(f"tags: [{' '.join(tags)}]")
    else:
        lines.append("tags: []")
    if flags:
        lines.append(f"review-reasons: {', '.join(flags)}")
    lines.append("---")
    return "\n".join(lines)


def build_note(note):
    """Returns (content, flags, has_table)."""
    title = note.get("title", "").strip() or "Untitled"
    raw_body = note.get("body", "")
    created = note.get("created", datetime.today().strftime("%Y-%m-%d"))
    folder = note.get("folder", "Unknown")

    cleaned, has_table = clean_body(raw_body)
    flags = determine_flags(note, raw_body)

    first_line = cleaned.split("\n")[0].strip() if cleaned else ""
    if first_line.lower() == title.lower():
        cleaned = "\n".join(cleaned.split("\n")[1:]).lstrip("\n")

    frontmatter = build_frontmatter(title, created, folder, flags, has_table)
    parts = [frontmatter, "", f"# {title}", ""]
    if cleaned:
        parts.append(cleaned)

    return "\n".join(parts) + "\n", flags, has_table


# ---------------------------------------------------------------------------
# JSON loading with repair
# ---------------------------------------------------------------------------

def load_notes(export_path):
    with open(export_path, "r", encoding="mac_roman") as f:
        raw = f.read()

    # Strip control characters that break JSON (keep \n \r \t)
    raw = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', raw)

    # Fix unescaped literal newlines inside JSON strings
    def fix_newlines(s):
        result = []
        in_string = False
        i = 0
        while i < len(s):
            c = s[i]
            if c == '\\' and i + 1 < len(s):
                result.append(c)
                result.append(s[i + 1])
                i += 2
                continue
            if c == '"':
                in_string = not in_string
            if in_string and c == '\n':
                result.append('\\n')
                i += 1
                continue
            if in_string and c == '\r':
                result.append('\\r')
                i += 1
                continue
            result.append(c)
            i += 1
        return ''.join(result)

    raw = fix_newlines(raw)
    return json.loads(raw)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Import Apple Notes -> zk second brain")
    parser.add_argument("--zk-root", required=True, help="Path to your zk notebook root")
    parser.add_argument("--export-file", default="~/notes_export.json",
                        help="Path to JSON export from export_notes.applescript")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview without writing files")
    args = parser.parse_args()

    export_path = Path(args.export_file).expanduser()
    zk_root = Path(args.zk_root).expanduser()
    inbox = zk_root / "00_inbox"
    log_path = Path("~/notes_import_log.txt").expanduser()

    if not export_path.exists():
        print(f"ERROR: Export file not found: {export_path}")
        print("Run export_notes.applescript first.")
        sys.exit(1)

    if not zk_root.exists():
        print(f"ERROR: zk root not found: {zk_root}")
        sys.exit(1)

    if not inbox.exists() and not args.dry_run:
        inbox.mkdir(parents=True)
        print(f"Created: {inbox}")

    print("Loading notes...")
    try:
        notes = load_notes(export_path)
    except Exception as e:
        print(f"ERROR loading JSON: {e}")
        sys.exit(1)

    print(f"Found {len(notes)} notes in export.\n")

    stats = {"created": 0, "skipped_exists": 0, "skipped_junk": 0,
             "needs_review": 0, "has_table": 0, "errors": 0}
    imported_titles = []

    for note in notes:
        title = note.get("title", "").strip() or "Untitled"
        raw_body = note.get("body", "")
        created = note.get("created", datetime.today().strftime("%Y-%m-%d"))

        if is_pure_url_note(raw_body):
            print(f"  SKIP (pure-url junk): {title}")
            stats["skipped_junk"] += 1
            continue

        slug = slugify(title)
        filename = f"{created}-{slug}.md"
        dest = inbox / filename

        if dest.exists():
            print(f"  SKIP (exists):        {filename}")
            stats["skipped_exists"] += 1
            continue

        try:
            content, flags, has_table = build_note(note)
            review = bool(flags) or has_table

            if args.dry_run:
                status = []
                if review:
                    status.append("needs-review")
                if has_table:
                    status.append("has-table")
                status_str = f" [{', '.join(status)}]" if status else ""
                print(f"  [dry-run]{status_str} {filename}")
                if flags:
                    print(f"           Flags: {', '.join(flags)}")
                preview = raw_body[:80].replace('\n', ' ')
                print(f"           Body:  {preview!r}")
                print()
            else:
                dest.write_text(content, encoding="utf-8")
                imported_titles.append(title)
                stats["created"] += 1
                if review:
                    stats["needs_review"] += 1
                if has_table:
                    stats["has_table"] += 1
                tag_info = f" [{', '.join(flags + (['has-table'] if has_table else []))}]" if review else ""
                print(f"  CREATED: {filename}{tag_info}")

        except Exception as e:
            print(f"  ERROR on '{title}': {e}")
            stats["errors"] += 1

    if not args.dry_run and imported_titles:
        log_path.write_text("\n".join(imported_titles), encoding="utf-8")
        print(f"\nImport log written to: {log_path}")

    print(f"\n{'[DRY RUN] ' if args.dry_run else ''}Summary")
    print(f"  Created       : {stats['created']}")
    print(f"  Skipped exist : {stats['skipped_exists']}")
    print(f"  Skipped junk  : {stats['skipped_junk']}")
    print(f"  Needs review  : {stats['needs_review']}")
    print(f"  Has tables    : {stats['has_table']}")
    print(f"  Errors        : {stats['errors']}")

    if not args.dry_run and stats["created"] > 0:
        print(f"\nNotes written to: {inbox}")
        print("Next steps:")
        print("  1. zk index                            <- rebuild zk index")
        print("  2. zk list --tag needs-review          <- review flagged notes")
        print("  3. osascript mark_imported.applescript <- move originals in Notes")


if __name__ == "__main__":
    main()