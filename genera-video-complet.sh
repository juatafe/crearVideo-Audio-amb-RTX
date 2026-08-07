#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== 1/5 Preparant escenes ==="
python3 02-prepara-escenes.py

if [[ "${SKIP_TTS:-0}" != "1" ]]; then
  echo "=== 2/5 Generant locució ==="
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

echo "=== FET ==="
