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

## Ús amb OpenCode

La branca `opencode-adaptation` afegeix les instruccions que OpenCode necessita:

- `AGENTS.md` conté les regles generals del repositori i les gates de qualitat.
- `.opencode/agents/video-supervisor.md` és l'agent principal.
- `.opencode/agents/` conté els agents especialitzats de revisió, prompts, imatges i pipeline.

No cal executar `/init` cada vegada. Només cal obrir el repositori amb OpenCode; `/init` és una ordre opcional per generar un `AGENTS.md` inicial en un repositori que encara no en tinga. En aquesta branca ja està preparat.

Després d'obrir el repositori, usa el supervisor i confirma que vols treballar amb `guio/guio.txt`. No s'han d'afegir tokens ni credencials a la configuració del projecte.

El checkpoint de ComfyUI es selecciona amb `CHECKPOINT_NAME` en `config.env`. Quan s'instal·le un checkpoint d'il·lustració compatible dins de `ComfyUI/models/checkpoints/`, canvia aquest valor i regenera només les imatges.

## Flux ràpid per a una història o poesia nova

1. Guarda el text a `guio/guio.txt` o indica a l'agent quin text ha de preparar.
2. Guarda les imatges de referència a `referencies/`; no cal indicar noms de fitxer. L'agent les llistarà i indicarà quin paper té cadascuna: estil, paleta, personatge, lloc o composició.
3. Demana al supervisor que compte veus, escenes, personatges i imatges, prepare `VEU:`, `IMATGE:` i `IMATGE_EN:`, i revise el manifest.
4. Demana que genere el primer vídeo complet i faça una revisió ràpida.
5. Revisa tu `video/final-15mb.mp4`; les observacions visuals no bloquejants es poden corregir en una segona iteració.

Prompt recomanat:

```text
Prepara el text actual com un vídeo revisable. Compta veus, escenes, personatges i imatges necessàries. Conserva exactament el text original, crea les directives visuals i usa totes les imatges de la carpeta referencies/ només per a continuïtat. Per a una poesia d'una sola veu, proposa primer gina com a veu femenina expressiva i confirma-la. Genera el primer vídeo complet, valida'l tècnicament i fes una revisió visual ràpida. No bloqueges per imperfeccions estètiques menors: lliura el vídeo i enumera les coses que he de revisar.
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
