#!/usr/bin/env python3
import os
import argparse
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--text-file", required=True)
parser.add_argument("--output", required=True)
args = parser.parse_args()

text_file = Path(args.text_file)
output_wav = Path(args.output)
piper_bin = os.environ.get("PIPER_BIN", ".venv/bin/piper")
model = os.environ.get("PIPER_MODEL", "models/tts/piper/es_ES-davefx-medium.onnx")

if not text_file.exists():
    raise SystemExit(f"ERROR: no trobe el text per a Piper: {text_file}")
if not Path(piper_bin).exists():
    raise SystemExit(f"ERROR: no trobe Piper a {piper_bin}")
if not Path(model).exists():
    raise SystemExit(f"ERROR: no trobe el model Piper a {model}")

output_wav.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(
    [piper_bin, "--model", model, "--input-file", str(text_file), "--output-file", str(output_wav)],
    check=True,
)