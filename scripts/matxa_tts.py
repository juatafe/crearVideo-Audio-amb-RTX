#!/usr/bin/env python3
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
