#!/usr/bin/env python3
"""
debug_json2.py - find structural JSON errors in notes_export.json
"""
import re
from pathlib import Path

export_path = Path("~/notes_export.json").expanduser()

with open(export_path, "r", encoding="mac_roman") as f:
    raw = f.read()

# Strip control chars same as import script
raw = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', raw)

# Try to find exactly where JSON breaks by binary searching
lo, hi = 0, len(raw)
last_good = 0

import json

# First confirm it actually fails
try:
    json.loads(raw)
    print("JSON parsed fine! No error found.")
except json.JSONDecodeError as e:
    print(f"Confirmed error at char {e.pos}: {e.msg}")
    pos = e.pos
    
    # Show surrounding raw bytes
    ctx_start = max(0, pos - 200)
    ctx_end = min(len(raw), pos + 200)
    ctx = raw[ctx_start:ctx_end]
    
    print(f"\n--- Raw context around char {pos} ---")
    print(repr(ctx))
    print(f"\n--- Printable context ---")
    print(ctx)
    print(f"\n--- Char at position {pos} ---")
    print(f"  char: {repr(raw[pos])}")
    print(f"  hex:  0x{ord(raw[pos]):02x}")
    
    # Count how many notes we have up to that point
    note_count = raw[:pos].count('"title"')
    print(f"\nApprox note #{note_count} is causing the problem")
    
    # Try to extract the note title near the error
    title_matches = list(re.finditer(r'"title":"([^"]*)"', raw[:pos]))
    if title_matches:
        last_title = title_matches[-1].group(1)
        print(f"Last successfully started note title: {repr(last_title)}")