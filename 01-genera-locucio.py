#!/usr/bin/env python3
from pathlib import Path
import json
import os
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / "manifest.json"


def load_env(path: Path):
    env = {}
    if not path.exists():
        return env
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        env[key.strip()] = value
    return env

cfg = load_env(ROOT / "config.env")
voice_wav = ROOT / cfg.get("VOICE_WAV", "locucio/locucio.wav")
voice_wav.parent.mkdir(parents=True, exist_ok=True)

if not MANIFEST.exists():
    subprocess.run(["python3", str(ROOT / "02-prepara-escenes.py")], check=True)

scenes = json.loads(MANIFEST.read_text(encoding="utf-8"))
tts_template = os.environ.get("TTS_COMMAND", "").strip()

if not tts_template:
    raise SystemExit(
        "ERROR: falta TTS_COMMAND.\n"
        "Configura un comandament de Matxa/Aina, per exemple:\n"
        "export TTS_COMMAND='python /ruta/matxa_tts.py --text-file \"{text_file}\" --output \"{output_wav}\"'"
    )

for scene in scenes:
    out = ROOT / scene["audio"]
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists() and out.stat().st_size > 1024:
        print(f"SKIP: {out.name} ja existeix")
        continue

    with tempfile.NamedTemporaryFile("w", suffix=".txt", encoding="utf-8", delete=False) as f:
        f.write(scene["text"].strip() + "\n")
        text_file = Path(f.name)

    try:
        cmd = tts_template.format(text_file=str(text_file), output_wav=str(out))
        print(f"TTS: {scene['id']}")
        subprocess.run(cmd, shell=True, check=True, cwd=ROOT)
        if not out.exists() or out.stat().st_size < 1024:
            raise RuntimeError(f"El TTS no ha generat correctament {out}")
    finally:
        text_file.unlink(missing_ok=True)

concat_file = ROOT / "tmp" / "tts_concat.txt"
concat_file.parent.mkdir(parents=True, exist_ok=True)
concat_file.write_text(
    "".join(f"file '{(ROOT / s['audio']).resolve()}'\n" for s in scenes),
    encoding="utf-8",
)

subprocess.run([
    "ffmpeg", "-y", "-hide_banner", "-loglevel", "warning",
    "-f", "concat", "-safe", "0", "-i", str(concat_file),
    "-c:a", "pcm_s16le", str(voice_wav)
], check=True)

print(f"OK: locució completa creada en {voice_wav}")
