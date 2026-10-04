#!/usr/bin/env python3
from pathlib import Path
import json
import hashlib
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
os.environ.setdefault("TTS_API_URL", cfg.get("TTS_API_URL", "http://127.0.0.1:8000"))
os.environ.setdefault("TTS_LANGUAGE", cfg.get("TTS_LANGUAGE", "ca-va"))
os.environ.setdefault("TTS_VOICE", cfg.get("TTS_VOICE", "quim"))
voice_wav = ROOT / cfg.get("VOICE_WAV", "locucio/locucio.wav")
voice_wav.parent.mkdir(parents=True, exist_ok=True)

if not MANIFEST.exists():
    subprocess.run(["python3", str(ROOT / "02-prepara-escenes.py")], check=True)

scenes = json.loads(MANIFEST.read_text(encoding="utf-8"))
tts_template = os.environ.get("TTS_COMMAND", "").strip()

if not tts_template:
    bridge = ROOT / "scripts" / "matxa_tts.py"
    if bridge.exists():
        tts_template = (
            f'python3 "{bridge}" --text-file "{{text_file}}" '
            '--output "{output_wav}"'
        )
        print(f"TTS_COMMAND no definit: usant {bridge}")
    else:
        raise SystemExit(
            "ERROR: falta TTS_COMMAND i no trobe el pont TTS: "
            f"{bridge}"
        )

for scene in scenes:
    if scene.get("visual_only") or not scene.get("audio"):
        print(f"SKIP: {scene['id']} és una escena només visual")
        continue
    out = ROOT / scene["audio"]
    voice = scene.get("voice", os.environ.get("TTS_VOICE", "quim"))
    voice_marker = out.with_suffix(out.suffix + ".voice")
    language = os.environ.get("TTS_LANGUAGE", "ca-va")
    audio_fingerprint = hashlib.sha256(
        f"{voice}\n{language}\n{scene['text']}".encode("utf-8")
    ).hexdigest()
    out.parent.mkdir(parents=True, exist_ok=True)
    previous_fingerprint = voice_marker.read_text(encoding="utf-8").strip() if voice_marker.exists() else ""
    if out.exists() and out.stat().st_size > 1024 and previous_fingerprint == audio_fingerprint:
        print(f"SKIP: {out.name} ja existeix")
        continue

    with tempfile.NamedTemporaryFile("w", suffix=".txt", encoding="utf-8", delete=False) as f:
        f.write(scene["text"].strip() + "\n")
        text_file = Path(f.name)

    try:
        cmd = tts_template.format(text_file=str(text_file), output_wav=str(out))
        print(f"TTS: {scene['id']}")
        scene_env = os.environ.copy()
        scene_env["TTS_VOICE"] = voice
        subprocess.run(cmd, shell=True, check=True, cwd=ROOT, env=scene_env)
        if not out.exists() or out.stat().st_size < 1024:
            raise RuntimeError(f"El TTS no ha generat correctament {out}")
        voice_marker.write_text(audio_fingerprint + "\n", encoding="utf-8")
    finally:
        text_file.unlink(missing_ok=True)

concat_file = ROOT / "tmp" / "tts_concat.txt"
concat_file.parent.mkdir(parents=True, exist_ok=True)
concat_file.write_text(
    "".join(
        f"file '{(ROOT / s['audio']).resolve()}'\n"
        for s in scenes
        if not s.get("visual_only") and s.get("audio")
    ),
    encoding="utf-8",
)

subprocess.run([
    "ffmpeg", "-y", "-hide_banner", "-loglevel", "warning",
    "-f", "concat", "-safe", "0", "-i", str(concat_file),
    "-c:a", "pcm_s16le", str(voice_wav)
], check=True)

print(f"OK: locució completa creada en {voice_wav}")
