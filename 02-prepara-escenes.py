#!/usr/bin/env python3
from pathlib import Path
import json
import os
import re

ROOT = Path(__file__).resolve().parent


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
script_file = ROOT / cfg.get("SCRIPT_FILE", "guio/guio.txt")
visual_style = cfg.get("VISUAL_STYLE", "cinematic illustration")
negative_prompt = cfg.get("NEGATIVE_PROMPT", "text, watermark, logo, blurry, low quality")

if not script_file.exists():
    raise SystemExit(f"ERROR: no trobe el guió: {script_file}")

text = script_file.read_text(encoding="utf-8").strip()
if not text:
    raise SystemExit("ERROR: el guió està buit.")

# Separació preferent per delimitador explícit ---.
blocks = [b.strip() for b in re.split(r"(?m)^\s*---\s*$", text) if b.strip()]

# Si no hi ha delimitadors, fem paràgrafs no buits.
if len(blocks) == 1:
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    if len(paragraphs) > 1:
        blocks = paragraphs

manifest = []
for i, block in enumerate(blocks, 1):
    scene_id = f"{i:03d}"
    prompt = (
        f"{visual_style}. Scene inspired by this narration: {block}. "
        "No written text in the image. Keep characters, clothing, setting and visual language coherent with adjacent scenes."
    )
    manifest.append({
        "id": scene_id,
        "text": block,
        "audio": f"locucio/fragments/{scene_id}.wav",
        "image": f"imatges/{scene_id}.png",
        "image_prompt": prompt,
        "negative_prompt": negative_prompt,
    })

out = ROOT / "manifest.json"
out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"OK: {len(manifest)} escenes creades en {out}")
