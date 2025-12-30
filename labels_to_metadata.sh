#!/bin/bash
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 episode_raw.mp3 episode_labels.txt"
  exit 1
fi

AUDIO="$1"
LABELS="$2"

BASE="${AUDIO%.*}"
META="${BASE}_metadata.txt"
OUT="${BASE}_chapters.mp3"

# Make variables available to Python
export AUDIO
export LABELS
export META

###############################################
# Generate metadata.txt using embedded Python #
###############################################
python3 << 'PYEOF'
import os
import pathlib

audio = os.environ["AUDIO"]
labels = os.environ["LABELS"]
meta   = os.environ["META"]

chapters = []

with open(labels, "r", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue

        parts = line.split("\t")
        if len(parts) < 3:
            continue

        start_s = float(parts[0])
        title = parts[2]

        start_ms = int(round(start_s * 1000))
        chapters.append((start_ms, title))

meta_lines = [";FFMETADATA1"]

for i, (start, title) in enumerate(chapters):
    if i + 1 < len(chapters):
        end = chapters[i+1][0] - 1
        if end < start:
            end = start
    else:
        end = start + 3600 * 1000   # last chapter placeholder

    safe_title = title.replace("\n", " ").replace("=", "-")

    meta_lines.append("[CHAPTER]")
    meta_lines.append("TIMEBASE=1/1000")
    meta_lines.append(f"START={start}")
    meta_lines.append(f"END={end}")
    meta_lines.append(f"title={safe_title}")
    meta_lines.append("")

with open(meta, "w", encoding="utf-8") as f:
    f.write("\n".join(meta_lines))

print("Metadata written to", meta)
PYEOF
###############################################

echo "Metadata file created: $META"

###############################################
# Inject metadata into MP3 using ffmpeg      #
###############################################
echo "Writing MP3 with chapters to: $OUT"

ffmpeg -y -i "$AUDIO" -i "$META" \
  -map_metadata 1 -codec copy \
  -id3v2_version 3 -write_id3v1 1 \
  "$OUT"

echo "Done. Open '$OUT' in Forecast."
