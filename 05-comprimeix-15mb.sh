#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./config.env

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: falta $1" >&2; exit 1; }; }
need ffmpeg
need ffprobe
need python3

[[ -f "$MASTER_VIDEO" ]] || { echo "ERROR: falta $MASTER_VIDEO" >&2; exit 1; }
mkdir -p video tmp

DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$MASTER_VIDEO")

calc_bitrate() {
python3 - "$DUR" "$TARGET_MB" "$AUDIO_BITRATE_K" "$MIN_VIDEO_BITRATE_K" "$MAX_VIDEO_BITRATE_K" "$1" <<'PY'
import sys
seconds=float(sys.argv[1])
target_mb=float(sys.argv[2])
audio_k=float(sys.argv[3])
min_k=float(sys.argv[4])
max_k=float(sys.argv[5])
safety=float(sys.argv[6])
# MB decimal -> bits, restant un marge per al contenidor.
total_k=(target_mb*1_000_000*8/seconds/1000)*safety
video_k=max(min_k, min(max_k, total_k-audio_k))
print(int(video_k))
PY
}

encode() {
  local VK="$1"
  local PASSLOG="tmp/ffmpeg-pass"
  rm -f "${PASSLOG}"* 2>/dev/null || true
  echo "Duració: ${DUR}s | vídeo: ${VK}k | àudio: ${AUDIO_BITRATE_K}k | objectiu: ${TARGET_MB} MB"

  ffmpeg -y -hide_banner -loglevel warning \
    -i "$MASTER_VIDEO" \
    -vf "scale=-2:${FINAL_HEIGHT},fps=${FINAL_FPS}" \
    -c:v libx264 -preset slow -b:v "${VK}k" \
    -pass 1 -passlogfile "$PASSLOG" -an -f mp4 /dev/null

  ffmpeg -y -hide_banner -loglevel warning \
    -i "$MASTER_VIDEO" \
    -vf "scale=-2:${FINAL_HEIGHT},fps=${FINAL_FPS}" \
    -c:v libx264 -preset slow -b:v "${VK}k" \
    -pass 2 -passlogfile "$PASSLOG" \
    -c:a aac -b:a "${AUDIO_BITRATE_K}k" \
    -movflags +faststart "$FINAL_VIDEO"

  rm -f "${PASSLOG}"* 2>/dev/null || true
}

VK=$(calc_bitrate 0.965)
encode "$VK"

SIZE=$(stat -c%s "$FINAL_VIDEO")
LIMIT=$(python3 - <<PY
print(int(float("$TARGET_MB")*1_000_000))
PY
)

if (( SIZE > LIMIT )); then
  echo "El primer intent s'ha passat un poc; reajustant..."
  VK=$(calc_bitrate 0.91)
  encode "$VK"
  SIZE=$(stat -c%s "$FINAL_VIDEO")
fi

python3 - <<PY
size=$SIZE/1_000_000
limit=float("$TARGET_MB")
print(f"OK: $FINAL_VIDEO -> {size:.2f} MB (objectiu {limit:.2f} MB)")
if size > limit:
    print("AVÍS: el fitxer supera lleugerament l'objectiu; baixa FINAL_HEIGHT o AUDIO_BITRATE_K si necessites més marge.")
PY
