#!/usr/bin/env python3
from pathlib import Path
import copy
import json
import os
import shutil
import time
import urllib.request
import urllib.parse

ROOT = Path(__file__).resolve().parent


def load_env(path: Path):
    env = {}
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


def http_json(url, data=None):
    body = None if data is None else json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=body)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def find_nodes(workflow):
    text_nodes = []
    save_nodes = []
    for node_id, node in workflow.items():
        cls = node.get("class_type", "")
        if cls == "CLIPTextEncode" and "text" in node.get("inputs", {}):
            text_nodes.append(node_id)
        if cls == "SaveImage":
            save_nodes.append(node_id)
    if len(text_nodes) < 1 or len(save_nodes) < 1:
        raise RuntimeError("No trobe CLIPTextEncode/SaveImage en el workflow API de ComfyUI.")
    return text_nodes, save_nodes

cfg = load_env(ROOT / "config.env")
base_url = cfg.get("COMFYUI_URL", "http://127.0.0.1:8188").rstrip("/")
workflow_path = ROOT / "workflows" / "comfyui_api_workflow.json"
manifest_path = ROOT / "manifest.json"
image_dir = ROOT / cfg.get("IMAGE_DIR", "imatges")
image_dir.mkdir(parents=True, exist_ok=True)

if not manifest_path.exists():
    raise SystemExit("ERROR: falta manifest.json. Executa primer 02-prepara-escenes.py")
if not workflow_path.exists():
    raise SystemExit(
        "ERROR: falta workflows/comfyui_api_workflow.json.\n"
        "Exporta des de ComfyUI un workflow en API format i guarda'l amb eixe nom."
    )

scenes = json.loads(manifest_path.read_text(encoding="utf-8"))
base_workflow = json.loads(workflow_path.read_text(encoding="utf-8"))
text_nodes, save_nodes = find_nodes(base_workflow)

# Convenció: primer CLIPTextEncode = positiu; segon, si existeix = negatiu.
pos_node = text_nodes[0]
neg_node = text_nodes[1] if len(text_nodes) > 1 else None
save_node = save_nodes[-1]

for scene in scenes:
    target = ROOT / scene["image"]
    if target.exists() and target.stat().st_size > 4096:
        print(f"SKIP: {target.name} ja existeix")
        continue

    wf = copy.deepcopy(base_workflow)
    wf[pos_node]["inputs"]["text"] = scene["image_prompt"]
    if neg_node:
        wf[neg_node]["inputs"]["text"] = scene.get("negative_prompt", "")
    prefix = f"auto_{scene['id']}"
    wf[save_node]["inputs"]["filename_prefix"] = prefix

    queued = http_json(f"{base_url}/prompt", {"prompt": wf})
    prompt_id = queued.get("prompt_id")
    if not prompt_id:
        raise RuntimeError(f"ComfyUI no ha retornat prompt_id per a {scene['id']}")

    print(f"COMFY: {scene['id']} ({prompt_id})")
    deadline = time.time() + 900
    output_meta = None
    while time.time() < deadline:
        history = http_json(f"{base_url}/history/{prompt_id}")
        item = history.get(prompt_id)
        if item and item.get("outputs"):
            output_meta = item["outputs"]
            break
        time.sleep(1.0)
    if output_meta is None:
        raise TimeoutError(f"Timeout esperant ComfyUI per a l'escena {scene['id']}")

    images = []
    for node_output in output_meta.values():
        images.extend(node_output.get("images", []))
    if not images:
        raise RuntimeError(f"ComfyUI no ha retornat cap imatge per a {scene['id']}")

    info = images[0]
    query = urllib.parse.urlencode({
        "filename": info["filename"],
        "subfolder": info.get("subfolder", ""),
        "type": info.get("type", "output"),
    })
    with urllib.request.urlopen(f"{base_url}/view?{query}", timeout=60) as r:
        target.write_bytes(r.read())
    print(f"OK: {target}")
