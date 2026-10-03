---
name: Run Video Supervisor
description: "Run the complete supervised AI video workflow from the current Valencian/Catalan script."
agent: "Video Supervisor"
argument-hint: "Use guio/guio.txt or provide a script path."
---

Run the Video Supervisor workflow for the current script.

Require these gates before reporting success:

1. Scene and voice validation.
2. English visual prompt validation.
3. TTS fragment validation.
4. Per-image visual inspection.
5. `scripts/validate-video-project.sh`.

Do not push to GitHub automatically.
