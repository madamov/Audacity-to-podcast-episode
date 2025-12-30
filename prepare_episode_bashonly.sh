#!/bin/bash
set -euo pipefail

if [ $# -ne 6 ]; then
  echo "Usage: $0 input.(mp3|wav|m4a) labels.txt \"Podcast Title\" \"Episode Title\" \"Summary\" artwork.(jpg|png)"
  exit 1
fi

AUDIO="$1"
LABELS="$2"
PODCAST_TITLE="$3"
EPISODE_TITLE="$4"
SUMMARY="$5"
ARTWORK="$6"

for f in "$AUDIO" "$LABELS" "$ARTWORK"; do
  if [ ! -f "$f" ]; then
    echo "File not found: $f" >&2
    exit 1
  fi
done

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found in PATH" >&2; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe not found in PATH" >&2; exit 1; }

BASE="${AUDIO%.*}"
META="${BASE}_metadata.txt"
OUT="${BASE}_chapters_64kbps_norm_tagged.mp3"

echo "Getting audio duration..."
AUDIO_DURATION_S="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$AUDIO")"
AUDIO_DURATION_MS="$(awk -v s="$AUDIO_DURATION_S" 'BEGIN { printf("%d\n", (s*1000)+0.5) }')"
echo "Audio duration: ${AUDIO_DURATION_S}s (${AUDIO_DURATION_MS} ms)"

###############################################
# Build ffmetadata chapters from labels.txt   #
# Your format: start<TAB>end<TAB>title        #
# - take start as seconds                     #
# - ignore end                                #
# - title is everything after 2nd TAB         #
###############################################

TMP_CHAP="$(mktemp)"

awk 'BEGIN{FS="\t"} NF>=3 {
  start_s = $1 + 0.0
  start_ms = int(start_s*1000 + 0.5)

  # Title = everything from field 3 onward, joined by tabs (safe)
  title = $3
  for (i=4; i<=NF; i++) title = title "\t" $i

  # Cleanups for ffmetadata (don’t wreck UTF-8)
  sub(/\r$/, "", title)
  gsub(/\n/, " ", title)
  gsub(/=/, "-", title)

  printf("%d\t%s\n", start_ms, title)
}' "$LABELS" > "$TMP_CHAP"

# Write ffmetadata
echo ";FFMETADATA1" > "$META"

awk 'BEGIN{FS="\t"} {
  start[NR]=$1
  title[NR]=$2
} END {
  for (i=1; i<=NR; i++) {
    s=start[i]
    if (i<NR) {
      e=start[i+1]-1
      if (e<s) e=s
    } else {
      e=dur_ms
      if (e<s) e=s
    }
    print "[CHAPTER]"
    print "TIMEBASE=1/1000"
    print "START=" s
    print "END=" e
    print "title=" title[i]
    print ""
  }
}' dur_ms="$AUDIO_DURATION_MS" "$TMP_CHAP" >> "$META"

rm -f "$TMP_CHAP"
echo "Metadata written to: $META"

###############################################
# Loudness normalize + 64 kbps MP3 + tags     #
###############################################

echo "Encoding 64 kbps MP3 + loudnorm + chapters + tags + artwork..."

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
echo "Done. Output:"
echo "  $OUT"
echo "Open it in Forecast."
