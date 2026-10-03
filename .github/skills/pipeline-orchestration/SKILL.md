---
name: pipeline-orchestration
description: 'Use when running the complete local AI video pipeline from script to TTS, ComfyUI images, FFmpeg master video, compressed video, and final validation.'
argument-hint: 'Run the pipeline for the current guion.txt.'
user-invocable: true
---

# Pipeline Orchestration

## Gates

1. Services: ComfyUI and Matxa/Aina API respond.
2. Scenes: `python3 02-prepara-escenes.py` creates the expected manifest.
3. Audio: every non-visual scene has a WAV fragment.
4. Images: every scene has a valid PNG and passes visual inspection.
5. Video: `video/master.mp4` and `video/final-15mb.mp4` exist.
6. Final: run `scripts/validate-video-project.sh`.

## Command

```bash
./genera-video-complet.sh
scripts/validate-video-project.sh
```

Do not push generated media or model files to GitHub. Report failures with the phase, command and relevant log.
