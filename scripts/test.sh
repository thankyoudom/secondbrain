cd ~/Documents/repos/secondbrain
FILE="00_inbox/2023-05-06-tampa-23ptwmay-5th-7th.md"
CONTENT=$(cat "$FILE")

opencode run "Act as a Markdown editor for my Zettelkasten.
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