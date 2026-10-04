#!/usr/bin/env python3
from pathlib import Path
import json
import hashlib
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
language_directive = re.compile(r"(?im)^\s*(?:IDIOMA|LANGUAGE)\s*:\s*([A-Za-z0-9_.-]+)\s*$")
image_directive = re.compile(r"(?im)^\s*(?:IMATGE|IMAGE)\s*:\s*(.+?)\s*$")
image_english_directive = re.compile(r"(?im)^\s*(?:IMATGE_EN|IMAGE_EN)\s*:\s*(.+?)\s*$")


def scene_negative_prompt(visual_subject, base_prompt):
    """Add only the exclusions stated explicitly by the scene prompt."""
    exclusions = []
    subject = visual_subject.lower()
    if re.search(r"exactly\s+0\s+people|no\s+people|without\s+(?:any\s+)?people", subject):
        exclusions.extend(
            ["person", "people", "human", "man", "woman", "child", "face", "body", "silhouette", "figure"]
        )
    if re.search(r"no\s+(?:animals?|animal)", subject):
        exclusions.append("animal")
    if re.search(r"no\s+(?:children|child|kids?)", subject):
        exclusions.append("child")
    if re.search(r"no\s+(?:crowds?|crowd)", subject):
        exclusions.append("crowd")
    if re.search(r"no\s+(?:buildings?|houses?)", subject):
        exclusions.extend(["building", "house"])
    return ", ".join(dict.fromkeys([base_prompt, *exclusions]))

if not script_file.exists():
    raise SystemExit(f"ERROR: no trobe el guió: {script_file}")

text = script_file.read_text(encoding="utf-8").strip()
if not text:
    raise SystemExit("ERROR: el guió està buit.")


def clean_generated_outputs():
    """Remove outputs from a previous script before preparing a new project."""
    generated_paths = [
        ROOT / cfg.get("IMAGE_DIR", "imatges"),
        ROOT / "locucio" / "fragments",
        ROOT / "video",
    ]
    generated_patterns = {
        "imatges": ("*.png", "*.png.prompt", "*.jpg", "*.jpeg"),
        "fragments": ("*.wav", "*.wav.voice"),
        "video": ("master.mp4", "final-15mb.mp4"),
    }
    for directory in generated_paths:
        directory.mkdir(parents=True, exist_ok=True)
        patterns = generated_patterns.get(directory.name, ())
        for pattern in patterns:
            for path in directory.glob(pattern):
                if path.is_file():
                    path.unlink()
    for path in (ROOT / "tmp").glob("*"):
        if path.name != ".gitkeep" and path.is_file():
            path.unlink()


state_dir = ROOT / ".project-state"
state_dir.mkdir(exist_ok=True)
state_file = state_dir / "generation.sha256"
generation_settings = {
    "script": text,
    "visual_style": visual_style,
    "character_bible": character_bible,
    "negative_prompt": negative_prompt,
    "image_dir": cfg.get("IMAGE_DIR", "imatges"),
    "image_width": cfg.get("IMAGE_WIDTH", ""),
    "image_height": cfg.get("IMAGE_HEIGHT", ""),
    "checkpoint_name": cfg.get("CHECKPOINT_NAME", ""),
    "visual_only_voice": visual_only_voice,
    "tts_voice": cfg.get("TTS_VOICE", ""),
    "tts_language": cfg.get("TTS_LANGUAGE", ""),
    "piper_model": cfg.get("PIPER_MODEL", ""),
}
generation_fingerprint = hashlib.sha256(
    json.dumps(generation_settings, sort_keys=True, ensure_ascii=False).encode("utf-8")
).hexdigest()
previous_fingerprint = state_file.read_text(encoding="utf-8").strip() if state_file.exists() else ""
if previous_fingerprint != generation_fingerprint:
    if previous_fingerprint:
        print("NOVA CONFIGURACIÓ: netejant els artefactes generats anteriors")
    else:
        print("PRIMERA EXECUCIÓ: netejant possibles artefactes antics")
    clean_generated_outputs()
    state_file.write_text(generation_fingerprint + "\n", encoding="utf-8")

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
    language_match = language_directive.search(block)
    language = language_match.group(1) if language_match else cfg.get("TTS_LANGUAGE", "ca-va")
    visual_only = bool(voice and voice.lower() == visual_only_voice)
    image_match = image_directive.search(block)
    image_description = image_match.group(1).strip() if image_match else ""
    image_english_match = image_english_directive.search(block)
    image_english_description = (
        image_english_match.group(1).strip() if image_english_match else ""
    )
    narration = voice_directive.sub("", block, count=1).strip()
    narration = language_directive.sub("", narration, count=1).strip()
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
        "negative_prompt": scene_negative_prompt(visual_subject, negative_prompt),
    }
    if voice:
        scene["voice"] = voice
    scene["language"] = language
    if visual_only:
        scene["visual_only"] = True
    manifest.append(scene)

out = ROOT / "manifest.json"
out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"OK: {len(manifest)} escenes creades en {out}")
