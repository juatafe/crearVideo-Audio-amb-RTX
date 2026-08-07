#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./config.env

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: falta $1" >&2; exit 1; }; }
need ffmpeg
need ffprobe
need python3

[[ -f manifest.json ]] || { echo "ERROR: falta manifest.json" >&2; exit 1; }
[[ -f "$VOICE_WAV" ]] || { echo "ERROR: falta la locució $VOICE_WAV" >&2; exit 1; }

mkdir -p tmp video
rm -f tmp/scene-*.mp4 tmp/concat.txt tmp/base-video.mp4

mapfile -t SCENES < <(python3 - <<'PY'
import json
for s in json.load(open('manifest.json', encoding='utf-8')):
    print(f"{s['id']}\t{s['image']}\t{s['audio']}")
PY
)

TOTAL=${#SCENES[@]}
(( TOTAL > 0 )) || { echo "ERROR: manifest sense escenes" >&2; exit 1; }

TOTAL_AUDIO=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$VOICE_WAV")
FALLBACK_DUR=$(python3 - <<PY
print(max(0.5, float("$TOTAL_AUDIO") / $TOTAL))
PY
)

idx=0
for line in "${SCENES[@]}"; do
  idx=$((idx+1))
  IFS=$'\t' read -r ID IMG AUD <<<"$line"
  [[ -f "$IMG" ]] || { echo "ERROR: falta $IMG" >&2; exit 1; }

  if [[ -f "$AUD" ]]; then
    DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$AUD")
  else
    DUR="$FALLBACK_DUR"
  fi

  FRAMES=$(python3 - <<PY
import math
print(max(2, math.ceil(float("$DUR") * int("$MASTER_FPS"))))
PY
)

  OUT=$(printf 'tmp/scene-%03d.mp4' "$idx")
  echo "Escena $idx/$TOTAL: $IMG (${DUR}s)"

  ffmpeg -y -hide_banner -loglevel warning \
    -loop 1 -i "$IMG" \
    -t "$DUR" \
    -vf "scale=${MASTER_WIDTH}:${MASTER_HEIGHT}:force_original_aspect_ratio=increase,crop=${MASTER_WIDTH}:${MASTER_HEIGHT},zoompan=z='min(zoom+0.00045,${KEN_BURNS_ZOOM})':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${FRAMES}:s=${MASTER_WIDTH}x${MASTER_HEIGHT}:fps=${MASTER_FPS},format=yuv420p" \
    -an -c:v libx264 -preset medium -crf 18 -movflags +faststart "$OUT"
done

for f in tmp/scene-*.mp4; do printf "file '%s'\n" "$(realpath "$f")"; done > tmp/concat.txt

ffmpeg -y -hide_banner -loglevel warning \
  -f concat -safe 0 -i tmp/concat.txt \
  -c copy tmp/base-video.mp4

if [[ "${USE_MUSIC:-0}" == "1" && -n "${MUSIC_FILE:-}" && -f "$MUSIC_FILE" ]]; then
  echo "Mesclant veu + música..."
  ffmpeg -y -hide_banner -loglevel warning \
    -i tmp/base-video.mp4 -i "$VOICE_WAV" -stream_loop -1 -i "$MUSIC_FILE" \
    -filter_complex "[2:a]volume=${MUSIC_VOLUME}[m];[1:a][m]amix=inputs=2:duration=first:dropout_transition=2[a]" \
    -map 0:v:0 -map "[a]" \
    -c:v copy -c:a aac -b:a 160k -shortest -movflags +faststart "$MASTER_VIDEO"
else
  ffmpeg -y -hide_banner -loglevel warning \
    -i tmp/base-video.mp4 -i "$VOICE_WAV" \
    -map 0:v:0 -map 1:a:0 \
    -c:v copy -c:a aac -b:a 160k -shortest -movflags +faststart "$MASTER_VIDEO"
fi

echo "OK: $MASTER_VIDEO"
