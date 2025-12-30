#!/bin/bash
set -euo pipefail

if [ $# -ne 6 ]; then
  echo "Usage: $0 input.mp3 labels.txt \"Podcast Title\" \"Episode Title\" \"Summary\" artwork.(jpg|png)"
  exit 1
fi

AUDIO="$1"
LABELS="$2"
PODCAST_TITLE="$3"
EPISODE_TITLE="$4"
SUMMARY="$5"
ARTWORK="$6"

if [ ! -f "$AUDIO" ]; then
  echo "Input audio not found: $AUDIO" >&2
  exit 1
fi

if [ ! -f "$LABELS" ]; then
  echo "Labels file not found: $LABELS" >&2
  exit 1
fi

if [ ! -f "$ARTWORK" ]; then
  echo "Artwork file not found: $ARTWORK" >&2
  exit 1
fi

# Check ffmpeg / ffprobe
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not found in PATH" >&2
  exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffprobe not found in PATH" >&2
  exit 1
fi

BASE="${AUDIO%.*}"
META="${BASE}_metadata.txt"
OUT="${BASE}_chapters_64kbps_norm_tagged.mp3"

echo "Getting audio duration from ffprobe..."
AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$AUDIO")
echo "Audio duration (seconds): $AUDIO_DURATION"

# Export env vars for Python
export LABELS
export META
export AUDIO_DURATION

###############################################
# Generate metadata.txt using embedded Python #
# (chapters with real last-chapter duration)  #
###############################################
python3 << 'PYEOF'
import os

labels_path     = os.environ["LABELS"]
meta_path       = os.environ["META"]
duration_str    = os.environ["AUDIO_DURATION"]

audio_duration_s  = float(duration_str)
audio_duration_ms = int(round(audio_duration_s * 1000))

chapters = []

with open(labels_path, "r", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue

        parts = line.split("\t")
        if len(parts) < 3:
            continue

        start_s = float(parts[0])
        title   = parts[2]

        start_ms = int(round(start_s * 1000))
        chapters.append((start_ms, title))

meta_lines = [";FFMETADATA1"]

for i, (start, title) in enumerate(chapters):
    if i + 1 < len(chapters):
        # END = just before the next chapter start
        end = chapters[i + 1][0] - 1
        if end < start:
            end = start
    else:
        # LAST CHAPTER: use real audio duration
        end = audio_duration_ms
        if end < start:
            end = start

    safe_title = title.replace("\n", " ").replace("=", "-")

    meta_lines.append("[CHAPTER]")
    meta_lines.append("TIMEBASE=1/1000")
    meta_lines.append(f"START={start}")
    meta_lines.append(f"END={end}")
    meta_lines.append(f"title={safe_title}")
    meta_lines.append("")

with open(meta_path, "w", encoding="utf-8") as f:
    f.write("\n".join(meta_lines))

print("Metadata written to", meta_path)
PYEOF

echo "Metadata file created: $META"

###############################################
# Loudness normalize + 64 kbps MP3 + tags     #
###############################################
echo "Normalizing loudness, encoding to 64 kbps MP3,"
echo "embedding chapters + artwork + metadata..."

# Note: I=-23 is EBU R128; for podcast-style louder audio,
# you might prefer I=-16 (feel free to change below).
ffmpeg -y \
  -i "$AUDIO" \
  -i "$META" \
  -i "$ARTWORK" \
  -filter:a loudnorm=I=-23:LRA=7:TP=-2:dual_mono=true \
  -map 0:a \
  -map 2 \
  -map_metadata 1 \
  -codec:a libmp3lame -b:a 64k \
  -id3v2_version 3 -write_id3v1 1 \
  -metadata album="$PODCAST_TITLE" \
  -metadata title="$EPISODE_TITLE" \
  -metadata comment="$SUMMARY" \
  -metadata description="$SUMMARY" \
  -metadata:s:v title="Album cover" \
  -metadata:s:v comment="Cover (front)" \
  "$OUT"

echo
echo "Done. Output file created:"
echo "  $OUT"
echo "Open this file in Forecast."
