---
name: image-validation
description: 'Use when validating ComfyUI image outputs against scene prompts, including resolution, person count, composition, continuity, unwanted characters, and regeneration decisions.'
argument-hint: 'Inspect the generated images for the current manifest.'
user-invocable: true
---

# Image Validation

## Procedure

1. Read `manifest.json` and the active ComfyUI workflow.
2. Confirm every scene has a PNG and that its dimensions match the workflow.
3. View every PNG, not only the first one.
4. Compare the image with `image_prompt` and `negative_prompt`.
5. Mark each scene `PASS`, `REGEN`, or `BLOCKED`.
6. If a prompt changed, confirm its `.prompt` fingerprint caused regeneration.
7. Never accept an output solely because the API returned success.

## Required checks

- exact person count and identities
- correct indoor/outdoor location
- requested camera shot and action
- historical clothes and objects
- no text, crowd, children, or modern objects unless requested
- continuity with adjacent scenes
