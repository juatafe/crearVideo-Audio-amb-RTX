#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import json
import re
import subprocess
from pathlib import Path

root = Path.cwd()
manifest_path = root / "manifest.json"
workflow_path = root / "workflows" / "comfyui_api_workflow.json"

if not manifest_path.exists():
    raise SystemExit("ERROR: falta manifest.json")
if not workflow_path.exists():
    raise SystemExit("ERROR: falta el workflow actiu")

scenes = json.loads(manifest_path.read_text(encoding="utf-8"))
workflow = json.loads(workflow_path.read_text(encoding="utf-8"))
latent_nodes = [
    node for node in workflow.values()
    if node.get("class_type") == "EmptyLatentImage"
]
expected_size = None
if latent_nodes:
    inputs = latent_nodes[0].get("inputs", {})
    expected_size = (inputs.get("width"), inputs.get("height"))

errors = []
for scene in scenes:
    scene_id = scene["id"]
    image = root / scene["image"]
    if not image.exists() or image.stat().st_size <= 4096:
        errors.append(f"{scene_id}: falta imatge valida: {image}")
    else:
        image_info = subprocess.run(
            ["file", str(image)], capture_output=True, text=True, check=False
        ).stdout
        if expected_size:
            expected = f"{expected_size[0]} x {expected_size[1]}"
            if expected not in image_info:
                errors.append(f"{scene_id}: resolucio incorrecta ({image_info.strip()})")

    audio = scene.get("audio", "")
    if audio:
        audio_path = root / audio
        if not audio_path.exists() or audio_path.stat().st_size <= 1024:
            errors.append(f"{scene_id}: falta audio valid: {audio_path}")

for video_name in ("video/master.mp4", "video/final-15mb.mp4"):
    video = root / video_name
    if not video.exists() or video.stat().st_size <= 1024:
        errors.append(f"falta video valid: {video_name}")

if errors:
    print("VALIDATION: FAIL")
    print("\n".join(f"- {error}" for error in errors))
    raise SystemExit(1)

print(f"VALIDATION: PASS ({len(scenes)} escenes, resolucio esperada {expected_size})")
PY
