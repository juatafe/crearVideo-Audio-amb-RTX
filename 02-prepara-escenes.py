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
character_bible = cfg.get("CHARACTER_BIBLE", "")
visual_only_voice = cfg.get("VISUAL_ONLY_VOICE", "").strip().lower()
negative_prompt = cfg.get("NEGATIVE_PROMPT", "text, watermark, logo, blurry, low quality")
voice_directive = re.compile(r"(?im)^\s*(?:VEU|VOICE)\s*:\s*([A-Za-z0-9_.-]+)\s*$")
image_directive = re.compile(r"(?im)^\s*(?:IMATGE|IMAGE)\s*:\s*(.+?)\s*$")
image_english_directive = re.compile(r"(?im)^\s*(?:IMATGE_EN|IMAGE_EN)\s*:\s*(.+?)\s*$")

if not script_file.exists():
    raise SystemExit(f"ERROR: no trobe el guió: {script_file}")

text = script_file.read_text(encoding="utf-8").strip()
if not text:
    raise SystemExit("ERROR: el guió està buit.")

# Separació preferent per delimitador explícit --- o per una nova directiva VEU:.
blocks = []
for explicit_block in re.split(r"(?m)^\s*---\s*$", text):
    blocks.extend(
        part.strip()
        for part in re.split(r"(?im)(?=^\s*(?:VEU|VOICE)\s*:)", explicit_block)
        if part.strip()
    )

# Si no hi ha delimitadors, fem paràgrafs no buits.
if len(blocks) == 1:
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    if len(paragraphs) > 1:
        blocks = paragraphs

manifest = []
for i, block in enumerate(blocks, 1):
    scene_id = f"{i:03d}"
    voice_match = voice_directive.search(block)
    voice = voice_match.group(1) if voice_match else None
    visual_only = bool(voice and voice.lower() == visual_only_voice)
    image_match = image_directive.search(block)
    image_description = image_match.group(1).strip() if image_match else ""
    image_english_match = image_english_directive.search(block)
    image_english_description = (
        image_english_match.group(1).strip() if image_english_match else ""
    )
    narration = voice_directive.sub("", block, count=1).strip()
    narration = image_directive.sub("", narration, count=1).strip()
    narration = image_english_directive.sub("", narration, count=1).strip()
    if not narration:
        raise SystemExit(f"ERROR: l'escena {scene_id} no té text després de VEU:.")
    visual_subject = image_english_description or image_description or narration
    prompt = (
        f"{visual_style}. {character_bible} Escena única i clara: {visual_subject}. "
        "Mostra exclusivament els personatges que apareixen explícitament en aquesta escena; "
        "no afegisques cap altre adult, xiquet, dona, home ni personatge del context. "
        "Respecta estrictament el nombre de persones, el pla, la postura, l'acció i l'espai descrits. "
        "Composició intencionada, acció visible, anatomia correcta, sense collage, sense multitud. "
        "Sense text escrit dins de la imatge. Mantín la continuïtat d'espai, colors i vestuari només "
        "per als personatges presents en aquesta escena."
    )
    scene = {
        "id": scene_id,
        "text": narration,
        "audio": "" if visual_only else f"locucio/fragments/{scene_id}.wav",
        "image": f"imatges/{scene_id}.png",
        "image_prompt": prompt,
        "negative_prompt": negative_prompt,
    }
    if voice:
        scene["voice"] = voice
    if visual_only:
        scene["visual_only"] = True
    manifest.append(scene)

out = ROOT / "manifest.json"
out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"OK: {len(manifest)} escenes creades en {out}")
