# Project instructions

Aquest repositori genera vídeos a partir d'un guió valencià/català amb TTS, ComfyUI i FFmpeg.

## Workflow

- Llegeix `guio/guio.txt`, `config.env` i `workflows/comfyui_api_workflow.json` abans de decidir accions.
- Conserva exactament el diàleg de `guio/guio.txt`; les descripcions visuals van en `IMATGE:` i `IMATGE_EN:`.
- Executa `python3 02-prepara-escenes.py` després de canvis al guió o als prompts i revisa `manifest.json`.
- Executa `./genera-video-complet.sh` només quan les dependències locals estiguen disponibles.
- Valida sempre amb `scripts/validate-video-project.sh` abans d'informar que el vídeo està acabat.

## Quality gates

- Cada escena té una veu vàlida, una acció visual principal i un nombre explícit de personatges.
- Cada escena pot declarar `IDIOMA:`; usa Matxa/Aina per a `ca-*` i Piper per a `es-*`.
- Cada escena té àudio i imatge; no acceptes un fitxer només perquè existeix.
- Fes una revisió visual ràpida de resolució, enquadrament, continuïtat, persones extra, objectes moderns i text espuri.
- Atura només per errors objectius o bloquejants: escenes/veus absents, fitxers corruptes o que falten, dimensions incompatibles, configuració impossible o validació tècnica fallida.
- Els defectes estètics no bloquejants es documenten i es lliura el vídeo perquè l'usuari el revise; no regeneres repetidament sense confirmació.

## Safety

- No puges models, WAV, PNG, MP4 ni credencials a Git.
- No escrigues tokens a `config.env`, prompts o logs.
- No faces `git push` ni operacions destructives sense confirmació explícita.
- No canvies diàlegs ni workflows sense una petició clara.

## Script and reference images

- El guió pot ser una història, una poesia, una narració o un diàleg; no assumesques personatges, època ni nombre d'escenes.
- Abans d'editar, compta i informa de blocs/escenes, veus, personatges explícits i imatges necessàries.
- Busca totes les imatges disponibles dins de `referencies/`; no cal passar un nom de fitxer concret. Documenta què aporta cada referència i usa-les només per a continuïtat d'estil, composició, personatges o paleta; no les tractes com escenes automàtiques.
- Si l'usuari proporciona una imatge dins del xat, demana que es guarde dins del projecte, preferentment a `referencies/`, abans d'executar ComfyUI.
- Per a poesies o narracions d'una sola veu, proposa `gina` per a valencià/català o la veu Piper configurada per a castellà, i confirma-la abans de generar TTS.

## Existing project agents

La configuració de VS Code/Copilot viu a `.github/agents/`. Per a OpenCode, usa els agents equivalents de `.opencode/agents/`.
