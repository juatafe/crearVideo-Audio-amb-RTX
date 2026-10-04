#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"

ROOT="$(pwd)"

# Les variables exportades tenen prioritat sobre config.env.
_COMFYUI_DIR="${COMFYUI_DIR-}"
_COMFYUI_URL="${COMFYUI_URL-}"
_COMFYUI_HOST="${COMFYUI_HOST-}"
_COMFYUI_PORT="${COMFYUI_PORT-}"
_COMFYUI_VENV="${COMFYUI_VENV-}"
_TTS_API_URL="${TTS_API_URL-}"
_TTS_CONTAINER="${TTS_CONTAINER-}"
_TTS_IMAGE="${TTS_IMAGE-}"
_TTS_PORT="${TTS_PORT-}"
_TTS_VOICE="${TTS_VOICE-}"
_TTS_LANGUAGE="${TTS_LANGUAGE-}"
_PIPER_BIN="${PIPER_BIN-}"
_PIPER_MODEL="${PIPER_MODEL-}"

mkdir -p tmp

# Carrega la configuració del projecte si existeix.
if [[ -f config.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source config.env
  set +a
fi

# Permet sobreescriure valors carregats de config.env amb variables d'entorn.
[[ -n "$_COMFYUI_DIR" ]] && COMFYUI_DIR="$_COMFYUI_DIR"
[[ -n "$_COMFYUI_URL" ]] && COMFYUI_URL="$_COMFYUI_URL"
[[ -n "$_COMFYUI_HOST" ]] && COMFYUI_HOST="$_COMFYUI_HOST"
[[ -n "$_COMFYUI_PORT" ]] && COMFYUI_PORT="$_COMFYUI_PORT"
[[ -n "$_COMFYUI_VENV" ]] && COMFYUI_VENV="$_COMFYUI_VENV"
[[ -n "$_TTS_API_URL" ]] && TTS_API_URL="$_TTS_API_URL"
[[ -n "$_TTS_CONTAINER" ]] && TTS_CONTAINER="$_TTS_CONTAINER"
[[ -n "$_TTS_IMAGE" ]] && TTS_IMAGE="$_TTS_IMAGE"
[[ -n "$_TTS_PORT" ]] && TTS_PORT="$_TTS_PORT"
[[ -n "$_TTS_VOICE" ]] && TTS_VOICE="$_TTS_VOICE"
[[ -n "$_TTS_LANGUAGE" ]] && TTS_LANGUAGE="$_TTS_LANGUAGE"
[[ -n "$_PIPER_BIN" ]] && PIPER_BIN="$_PIPER_BIN"
[[ -n "$_PIPER_MODEL" ]] && PIPER_MODEL="$_PIPER_MODEL"

: "${COMFYUI_DIR:=$HOME/Projectes/ComfyUI}"
: "${COMFYUI_URL:=http://127.0.0.1:8188}"
: "${COMFYUI_HOST:=127.0.0.1}"
: "${COMFYUI_PORT:=8188}"
: "${TTS_API_URL:=http://127.0.0.1:8000}"
: "${TTS_CONTAINER:=crearvideo-aina-tts}"
: "${TTS_IMAGE:=projecteaina/tts-api:latest}"
: "${TTS_PORT:=8000}"
: "${TTS_VOICE:=quim}"
: "${TTS_LANGUAGE:=ca-va}"
: "${PIPER_BIN:=.venv/bin/piper}"
: "${PIPER_MODEL:=models/tts/piper/es_ES-davefx-medium.onnx}"

wait_http() {
  local url="$1"
  local description="$2"
  local attempts="${3:-60}"

  echo "Esperant $description..."
  for ((i = 1; i <= attempts; i++)); do
    if curl --silent --fail --max-time 2 "$url" >/dev/null; then
      echo "$description disponible."
      return 0
    fi
    sleep 2
  done

  echo "ERROR: $description no respon en $url" >&2
  return 1
}

echo "=== Comprovant requisits ==="
command -v python3 >/dev/null || {
  echo "ERROR: falta python3." >&2
  exit 1
}
command -v curl >/dev/null || {
  echo "ERROR: falta curl." >&2
  exit 1
}
command -v docker >/dev/null || {
  echo "ERROR: falta Docker." >&2
  exit 1
}

# Arranca ComfyUI només si no respon ja.
if ! curl --silent --fail --max-time 2 \
  "${COMFYUI_URL%/}/system_stats" >/dev/null; then

  if [[ ! -f "$COMFYUI_DIR/main.py" ]]; then
    echo "ERROR: no trobe ComfyUI a $COMFYUI_DIR" >&2
    echo "Indica la ruta així: COMFYUI_DIR=/ruta/ComfyUI ./genera-video-complet.sh" >&2
    exit 1
  fi

  if [[ ! -f "$COMFYUI_DIR/${COMFYUI_VENV:-.venv}/bin/python" ]]; then
    echo "ERROR: no trobe l'entorn $COMFYUI_DIR/${COMFYUI_VENV:-.venv}/bin/python" >&2
    exit 1
  fi

  echo "=== Arrancant ComfyUI ==="
  (
    cd "$COMFYUI_DIR"
    nohup "${COMFYUI_VENV:-.venv}/bin/python" main.py \
      --listen "$COMFYUI_HOST" --port "$COMFYUI_PORT" \
      >"$ROOT/tmp/comfyui.log" 2>&1 \
      </dev/null &
    echo "$!" >"$ROOT/tmp/comfyui.pid"
  )
fi

wait_http "${COMFYUI_URL%/}/system_stats" "ComfyUI" 120

# Arranca l'API Matxa/Aina si no respon ja.
if ! curl --silent --fail --max-time 2 \
  "${TTS_API_URL%/}/openapi.json" >/dev/null; then

  if docker container inspect "$TTS_CONTAINER" >/dev/null 2>&1; then
    docker start "$TTS_CONTAINER" >/dev/null
  else
    docker run -d \
      --name "$TTS_CONTAINER" \
      --restart unless-stopped \
      -p "127.0.0.1:${TTS_PORT}:8000" \
      "$TTS_IMAGE" >/dev/null
  fi
fi

wait_http "${TTS_API_URL%/}/openapi.json" "API de Matxa/Aina" 120

# Crea el pont entre l'estructura del projecte i l'API TTS.
cat > tmp/matxa_tts.py <<'PY'
import argparse
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

parser = argparse.ArgumentParser()
parser.add_argument("--text-file", required=True)
parser.add_argument("--output", required=True)
args = parser.parse_args()

text = Path(args.text_file).read_text(encoding="utf-8").strip()
if not text:
    raise SystemExit(f"ERROR: el text està buit: {args.text_file}")

payload = {
    "voice": os.environ.get("TTS_VOICE", "quim"),
    "type": "text",
    "text": text,
    "language": os.environ.get("TTS_LANGUAGE", "ca-va"),
}

api_url = os.environ.get("TTS_API_URL", "http://127.0.0.1:8000").rstrip("/")
request = Request(
    f"{api_url}/api/tts",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)

with urlopen(request, timeout=300) as response:
    audio = response.read()

if not audio.startswith(b"RIFF") or audio[8:12] != b"WAVE":
    raise SystemExit(
        "ERROR: l'API no ha retornat un WAV vàlid. "
        "Comprova la veu, l'idioma i els logs del contenidor."
    )

output = Path(args.output)
output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(audio)
print(f"OK: locució creada en {output}")
PY

export TTS_API_URL TTS_VOICE TTS_LANGUAGE
export TTS_COMMAND="python3 $ROOT/tmp/matxa_tts.py --text-file \"{text_file}\" --output \"{output_wav}\""
export PIPER_BIN PIPER_MODEL
export TTS_COMMAND_ES="python3 $ROOT/scripts/piper_tts.py --text-file \"{text_file}\" --output \"{output_wav}\""

echo "=== 1/5 Preparant escenes ==="
python3 02-prepara-escenes.py

if [[ "${SKIP_TTS:-0}" != "1" ]]; then
  echo "=== 2/5 Generant locució amb Matxa/Aina ==="
  python3 01-genera-locucio.py
else
  echo "=== 2/5 Locució: SKIP ==="
fi

if [[ "${SKIP_IMAGES:-0}" != "1" ]]; then
  echo "=== 3/5 Generant imatges ==="
  python3 03-genera-imatges.py
else
  echo "=== 3/5 Imatges: SKIP ==="
fi

echo "=== 4/5 Muntant vídeo mestre ==="
./04-munta-video.sh

echo "=== 5/5 Comprimint ==="
./05-comprimeix-15mb.sh

echo "=== 6/6 Validant projecte ==="
./scripts/validate-video-project.sh

ARCHIVE_ROOT="${VIDEO_ARCHIVE_DIR:-videos-generats}"
RUN_NAME="${PROJECT_NAME:-projecte-video}-$(date +%Y%m%d-%H%M%S)"
ARCHIVE_DIR="$ROOT/$ARCHIVE_ROOT/$RUN_NAME"
mkdir -p "$ARCHIVE_DIR"
cp -- "$FINAL_VIDEO" "$ARCHIVE_DIR/"
cp -- manifest.json "$ARCHIVE_DIR/manifest.json"
printf '%s\n' "PROJECT_NAME=${PROJECT_NAME:-projecte-video}" "CREATED_AT=$(date --iso-8601=seconds)" > "$ARCHIVE_DIR/README.txt"

echo "=== VÍDEO ARXIVAT ==="
echo "$ARCHIVE_DIR/$(basename "$FINAL_VIDEO")"

read -r -p "Vols eliminar els fitxers residuals de treball? [y/N] " CLEANUP || CLEANUP=""
if [[ "$CLEANUP" =~ ^[YySs]$ ]]; then
  rm -f -- \
    tmp/scene-*.mp4 \
    tmp/concat.txt \
    tmp/base-video.mp4 \
    tmp/ffmpeg-pass* \
    tmp/tts_concat.txt \
    tmp/matxa_tts.py \
    video/master.mp4 \
    video/final-15mb.mp4 \
    locucio/locucio.wav \
    locucio/locucio-amb-musica.mp3
  rm -f -- locucio/fragments/*.wav locucio/fragments/*.wav.voice
  rm -f -- imatges/*.png imatges/*.png.prompt imatges/*.jpg imatges/*.jpeg
  echo "Residus eliminats. L'arxiu del vídeo es conserva en: $ARCHIVE_DIR"
else
  echo "Residus conservats. L'arxiu del vídeo es conserva en: $ARCHIVE_DIR"
fi

echo "=== FET ==="