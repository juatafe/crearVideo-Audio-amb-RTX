---
name: scene-prompt-authoring
description: 'Use when converting a Catalan or Valencian video script into validated scenes and English SDXL image prompts while preserving dialogue, character counts, camera framing, and visual continuity.'
argument-hint: 'Provide the script path or scene blocks to validate.'
user-invocable: true
---

# Scene Prompt Authoring

## Procedure

1. Read `guio/guio.txt` and identify `VEU:`, `IMATGE:`, `IMATGE_EN:` and `---` boundaries.
2. Keep spoken text exactly as authored.
3. Require one visual action and one camera framing per scene.
4. If the workflow uses separate agents, pass the approved `IMATGE:` to `Visual Prompt Translator`; that agent alone writes `IMATGE_EN:` in precise English for SDXL.
5. State the exact number and identity of people.
6. Run `python3 02-prepara-escenes.py`.
7. Inspect `manifest.json` and reject missing or contradictory prompts.

## Output

Report scene count, voices, spoken text preservation, person count, and any prompt risks.
