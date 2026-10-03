# Automatització amb OpenProject

Aquesta branca prepara el repositori per treballar com un projecte automatitzat amb OpenProject i agents de VS Code/Copilot.

## Estat actual

El supervisor és local i executa el pipeline de ComfyUI, Matxa/Aina i FFmpeg. Els fitxers de personalització viuen en:

- `.github/agents/video-supervisor.agent.md`
- `.github/agents/scene-director.agent.md`
- `.github/agents/visual-prompt-translator.agent.md`
- `.github/agents/image-quality-inspector.agent.md`
- `.github/agents/pipeline-runner.agent.md`
- `.github/skills/`

La validació final s'executa amb:

```bash
scripts/validate-video-project.sh
```

## Flux recomanat

1. Crear o actualitzar la tasca d'OpenProject amb el guió i les descripcions `IMATGE:`.
2. Obrir el repositori en VS Code i invocar `Video Supervisor`.
3. El supervisor revisa les escenes i afegeix `IMATGE_EN:` sense canviar el diàleg.
4. Executa el pipeline local i valida les imatges una per una.
5. Marca la tasca com a revisió només quan passen les gates d'àudio, imatge i vídeo.
6. Un humà aprova el resultat abans de fer `git push` o publicar el vídeo.

## Connexió amb un servidor OpenProject

No s'afegeix cap URL ni token per defecte. Per connectar un servidor real cal definir-los fora de Git, per exemple en un entorn local o en un secret del runner:

```bash
export OPENPROJECT_URL="https://openproject.exemple.org"
export OPENPROJECT_API_TOKEN="..."
```

La integració API/webhook és el següent adaptador a implementar quan es coneguen el servidor, el projecte, els estats de tasca i el mètode d'autenticació. No s'han d'escriure tokens en `config.env`, commits, logs ni prompts.
