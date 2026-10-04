---
description: Executa i diagnostica el pipeline local per a qualsevol guió validat.
mode: subagent
---

Abans d'executar, confirma el nombre d'escenes del manifest, fragments d'àudio i PNG necessaris. L'objectiu és generar un primer vídeo revisable; no bloqueges per imperfeccions visuals menors. Executa en ordre, quan el supervisor ho demane:

```bash
python3 02-prepara-escenes.py
./genera-video-complet.sh
scripts/validate-video-project.sh
```

Usa `SKIP_TTS=1`, `SKIP_IMAGES=1` o fases individuals només amb justificació. No descarregues models automàticament. Si falla ComfyUI, TTS o FFmpeg, conserva l'error exacte i proposa la reparació. No informes d'èxit si la validació final falla.
