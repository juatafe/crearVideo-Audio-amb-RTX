# Plantilla reutilitzable per a vídeos amb IA

Esta carpeta automatitza una cadena de treball pensada per a crear vídeos narrats a partir d'un text:

**text → locució → escenes → imatges → muntatge → vídeo final ≤ 15 MB**

La idea és reutilitzar-la per a rondalles, vídeos educatius, històries, divulgació, campanyes, etc. Per a un projecte nou, normalment només cal canviar el guió i l'estil visual.

## 0. Idea general i ordre recomanat

El projecte separa quatre coses:

1. **Contingut:** el text de `guio/guio.txt`, les escenes i la veu.
2. **Imatge:** els prompts, l'estil i el workflow de ComfyUI.
3. **Muntatge:** la duració de cada imatge, l'orientació i els moviments de càmera.
4. **Distribució:** la compressió final i la mida màxima del fitxer.

Per a crear un vídeo nou, segueix sempre este ordre:

1. Edita el guió i les descripcions visuals.
2. Revisa les escenes amb `02-prepara-escenes.py` i `manifest.json`.
3. Revisa els prompts amb els agents abans de gastar temps de GPU.
4. Genera veu i imatges.
5. Revisa les imatges i corregeix només les escenes problemàtiques.
6. Munta, comprimeix i valida el vídeo.
7. Conserva el resultat en `videos-generats/`.

Les carpetes `imatges/`, `locucio/`, `video/` i `tmp/` són espai de treball. Les carpetes dins de `videos-generats/` són l'arxiu de resultats i no es netegen quan canvies de projecte.

### La manera fàcil: dona-li un text a l'agent

No cal que escrigues `VEU:`, `IMATGE:` ni `IMATGE_EN:` manualment. Pots donar a `Video Supervisor` un text com este:

```text
Vull un vídeo breu sobre una xiqueta que planta un arbre al poble del seu avi.
Ha de començar amb el poble sec, mostrar com planten l'arbre i acabar amb el poble verd.
Vull un estil de conte il·lustrat, càlid i esperançador, en format vertical.
```

L'agent `Scene Director` farà el treball intermedi:

1. separarà el text en escenes;
2. conservarà el text narratiu que s'ha de locutar;
3. proposarà una veu;
4. crearà la descripció visual en valencià; `Visual Prompt Translator` la convertirà en el prompt anglès per a ComfyUI;
5. indicarà personatges, accions i continuïtat;
6. et mostrarà el resum abans d'escriure `guio/guio.txt`.

Quan confirmes el resum, `Video Supervisor` escriu el guió tècnic i continua amb el pipeline. Així no cal conéixer el format intern: només has d'aportar el text, el tema, l'estil desitjat i, si és important, el format vertical o horitzontal.

Exemple de petició a l'agent:

```text
Usa este text per preparar un vídeo. No canvies les paraules de la narració;
només crea les escenes i les imatges necessàries. Proposa primer el guió i espera
la meua confirmació abans de generar veu o imatges:

[enganxa ací la història, poesia o narració]
```

## 1. Estructura

```text
plantilla-video-ia/
├── config.env
├── guio/
│   └── guio.txt
├── locucio/
│   └── fragments/
├── imatges/
├── video/
├── workflows/
│   └── comfyui_api_workflow.json.example
├── 01-genera-locucio.py
├── 02-prepara-escenes.py
├── 03-genera-imatges.py
├── 04-munta-video.sh
├── 05-comprimeix-15mb.sh
└── genera-video-complet.sh
```

## 2. Dependències generals

En Ubuntu / Pop!_OS:

```bash
sudo apt update
sudo apt install -y ffmpeg python3 python3-venv python3-pip jq
```

Els scripts de la plantilla utilitzen la llibreria estàndard de Python. Pots crear un entorn virtual si el teu motor TTS necessita dependències pròpies.

La generació de veu depén del motor TTS que utilitzes. El script `01-genera-locucio.py` està preparat perquè pugues connectar Matxa TTS / projecte Aina mitjançant un comandament extern configurable. Açò evita lligar tota la plantilla a una versió concreta del model.

## 3. Preparar un projecte nou

Copia la plantilla:

```bash
cp -a plantilla-video-ia projecte-nou
cd projecte-nou
```

Edita:

```bash
nano guio/guio.txt
nano config.env
```

Si uses l'agent, aquest pas consisteix simplement a donar-li el text i confirmar el guió que propose. L'agent escriurà `guio/guio.txt` amb el format que entenen els scripts.

La variable més habitual de canviar és:

```bash
VISUAL_STYLE="..."
```

Exemples:

```text
cinematic medieval Valencian legend, dramatic natural light, realistic textures
```

```text
educational 3D illustration, clean composition, bright neutral background
```

```text
1930s documentary photography in Valencia, black and white, historical realism
```

## 4. Divisió del guió en escenes

Si poses `---` en una línia independent, cada bloc serà una escena:

```text
Conta la llegenda que una nit de tempesta...

---

Els habitants van mirar cap a la muntanya...

---

De sobte, un tro va fer tremolar tota la vall.
```

Executa:

```bash
python3 02-prepara-escenes.py
```

Es crearà `manifest.json`.

També pots editar manualment el camp `image_prompt` de cada escena abans de generar les imatges.

## 5. Generar la locució

### Opció recomanada: Matxa TTS / Aina

El script no inventa una ordre concreta de Matxa perquè pot variar segons la instal·lació. Configura una plantilla de comandament amb la variable d'entorn `TTS_COMMAND`.

Ha d'acceptar estos marcadors:

- `{text_file}`: fitxer TXT del fragment.
- `{output_wav}`: WAV que ha de generar.

Exemple conceptual:

```bash
export TTS_COMMAND='python /ruta/al/teu/matxa_tts.py --text-file "{text_file}" --output "{output_wav}"'
python3 01-genera-locucio.py
```

El script crearà un WAV per escena dins de:

```text
locucio/fragments/
```

I després els concatenarà en:

```text
locucio/locucio.wav
```

Si ja tens una locució completa feta amb un altre sistema, simplement copia-la a:

```text
locucio/locucio.wav
```

I pots començar des del pas 2 o 3.

## 6. Generar imatges amb ComfyUI

ComfyUI ha d'estar funcionant, normalment en:

```text
http://127.0.0.1:8188
```

Per automatitzar-lo necessites exportar un workflow en **API format** i guardar-lo com:

```text
workflows/comfyui_api_workflow.json
```

La plantilla inclou:

```text
workflows/comfyui_api_workflow.json.example
```

En el JSON has de marcar els nodes que corresponen al prompt positiu, prompt negatiu i prefix del fitxer. El script intenta detectar automàticament nodes típics `CLIPTextEncode` i `SaveImage`.

Executa:

```bash
python3 03-genera-imatges.py
```

Les imatges acabaran dins de `imatges/` amb noms:

```text
001.png
002.png
003.png
...
```

Si preferixes generar-les manualment, només has de posar-les tu mateix en eixa carpeta amb eixos noms.

### Com millorar l'aspecte de les imatges

La font principal és `guio/guio.txt`: escriu una descripció concreta en `IMATGE_EN:` indicant enquadrament, lloc, acció, nombre exacte de persones, vestuari i elements que no han d'aparéixer. El parser conserva el diàleg i construeix el prompt amb:

- `VISUAL_STYLE`, `CHARACTER_BIBLE` i `NEGATIVE_PROMPT` de `config.env`;
- el checkpoint indicat en `CHECKPOINT_NAME`;
- els passos, CFG, sampler i resolució de `workflows/comfyui_api_workflow.json`.

Els agents `Visual Prompt Translator` i `Image Quality Inspector` són els encarregats de revisar prompts i imatges. `Video Supervisor` els coordina, però no s'executen automàticament amb l'script de terminal. Després de generar, convé revisar les imatges abans del muntatge i regenerar només les escenes amb errors objectius.

## 7. Del prompt al vídeo: procediment complet

### 1. Escriure el guió i el prompt visual

Edita `guio/guio.txt`. Cada bloc separat per una línia amb `---` és una escena. La directiva `VEU:` indica la veu i el text que queda fora de les directives és el diàleg que es locutarà.

No canvies el diàleg per millorar la imatge. Afig les instruccions visuals amb `IMATGE:` i, preferentment, la versió concreta per a SDXL amb `IMATGE_EN:`:

```text
VEU: gina
IMATGE: Pla mitjà del poeta davant d'una plaça buida, una única persona visible,
amb abric fosc i una estrela física al fons, sense text ni objectes moderns.
IMATGE_EN: Medium shot of the same poet standing in an empty square, exactly one
visible person, dark coat, a physical star in the background, no text, no modern objects.

He arribat a la plaça i encara no la veig.
```

Un prompt visual útil especifica, en este ordre aproximat:

- enquadrament i orientació: `wide shot`, `medium shot`, `close-up`, `vertical composition`;
- lloc i moment: plaça, taller, camí, interior, nit o dia;
- acció principal i postura visible;
- nombre exacte de personatges i continuïtat: `exactly one person`, `same two companions`;
- vestuari i elements que han de continuar;
- exclusions: persones extra, xiquets, animals, objectes moderns i text escrit.

Evita prompts abstractes com “una escena bonica” o amb diverses accions alhora. Una escena ha de tindre una acció visual fàcil de llegir. Usa `IMATGE_EN:` per a donar a ComfyUI una descripció anglesa clara; el diàleg continua en valencià/català.

### 2. Revisar i preparar les escenes

Després de modificar el guió o els prompts, executa:

```bash
python3 02-prepara-escenes.py
```

Revisa `manifest.json`. Cada entrada ha de tindre com a mínim `id`, `text`, `image`, `image_prompt`, `negative_prompt` i, si té locució, `audio`. Comprova especialment que el camp `text` conserva exactament el diàleg i que cada escena té el nombre correcte de personatges.

Si vols inspeccionar el prompt final abans de generar, obri `manifest.json` i busca `image_prompt`. El parser combina la descripció de `IMATGE_EN:` amb `VISUAL_STYLE`, `CHARACTER_BIBLE` i `NEGATIVE_PROMPT` de `config.env`.

### 3. Revisar amb els agents

Per a una revisió assistida des de VS Code/Copilot, usa `Video Supervisor` i indica que ha d'utilitzar `guio/guio.txt`. El flux recomanat és:

1. `Scene Director`: comprova blocs, veus, diàleg i continuïtat.
2. `Visual Prompt Translator`: converteix `IMATGE:` en `IMATGE_EN:` sense tocar el diàleg ni canviar l'acció.
3. `Image Quality Inspector`: revisa resolució, enquadrament, persones extra, text espuri i coherència visual.
4. `Pipeline Runner`: executa les fases i diagnostica errors de TTS, ComfyUI o FFmpeg.

Els agents proposen canvis, però la generació real usa els scripts del projecte. Si una imatge és estèticament millorable però representa correctament l'escena, marca-la com a `REVIEW`; reserva `BLOCKED` per a fitxers corruptes, escenes equivocades o errors objectius.

### 4. Generar el vídeo complet

Quan ComfyUI, Docker/TTS, Python i FFmpeg estiguen disponibles, executa:

```bash
./genera-video-complet.sh
```

El procediment fa, en ordre:

1. prepara `manifest.json`;
2. genera els fragments de veu i `locucio/locucio.wav`;
3. genera les imatges en `imatges/` mitjançant ComfyUI;
4. munta `video/master.mp4`;
5. crea `video/final-15mb.mp4`;
6. executa `scripts/validate-video-project.sh`;
7. arxiva el resultat en `videos-generats/PROJECT_NAME-data-hora/`.

La validació tècnica ha de passar abans que el vídeo es considere acabat. Després fes també la revisió visual de l'agent `Image Quality Inspector` o revisa manualment les imatges.

### 5. Regenerar només una part

Si el guió no ha canviat i ja tens la veu, pots evitar el TTS:

```bash
SKIP_TTS=1 ./genera-video-complet.sh
```

Si les imatges ja són correctes, evita ComfyUI:

```bash
SKIP_IMAGES=1 ./genera-video-complet.sh
```

Per regenerar una escena concreta, modifica el seu `IMATGE_EN:` o `image_prompt`, executa `02-prepara-escenes.py` i torna a executar `03-genera-imatges.py`. Les escenes amb el mateix prompt i workflow es reutilitzen; les que han canviat es regeneren.

### 6. Solucionar errors habituals

`falta manifest.json`: executa `python3 02-prepara-escenes.py`.

`ComfyUI no respon`: inicia ComfyUI o revisa `COMFYUI_URL`, `COMFYUI_DIR` i `COMFYUI_VENV` en `config.env`.

`falta la locució`: comprova TTS, `TTS_COMMAND` i que existisca `locucio/locucio.wav` o els fragments individuals.

`resolució incorrecta`: comprova que `EmptyLatentImage` del workflow i `IMAGE_WIDTH`/`IMAGE_HEIGHT` siguen coherents.

`persones extra o estil inconsistent`: millora `IMATGE_EN:`, reforça `CHARACTER_BIBLE` i `NEGATIVE_PROMPT`, i regenera només les escenes afectades.

## 8. Què passa quan canvies el projecte?

El projecte calcula una empremta de generació amb el guió, l'estil visual, el prompt negatiu, el checkpoint, la resolució d'imatge i la configuració de veu. Quan canvia alguna d'aquestes dades, `02-prepara-escenes.py` detecta una configuració nova i neteja els fitxers de treball dependents. Les còpies que ja estan en `videos-generats/` no es toquen.

| Canvi | Què cal fer | Què es regenera |
|---|---|---|
| Text del guió, blocs `---` o nombre d'escenes | Edita `guio/guio.txt` i executa el pipeline complet | Manifest, veu, imatges i vídeo |
| `IMATGE:` o `IMATGE_EN:` d'una escena | Executa `02-prepara-escenes.py`, revisa `manifest.json` i després `03-genera-imatges.py` | Les imatges amb prompt canviat; després cal remuntar el vídeo |
| `VISUAL_STYLE`, `CHARACTER_BIBLE` o `NEGATIVE_PROMPT` | Executa el pipeline complet | Imatges i, per coherència, veu i vídeo de treball |
| `CHECKPOINT_NAME` o resolució de ComfyUI | Comprova el workflow i executa el pipeline complet | Imatges i vídeo |
| `TTS_VOICE`, `TTS_LANGUAGE` o directiva `VEU:` | Executa el pipeline complet | Locució i vídeo |
| `MASTER_WIDTH` / `MASTER_HEIGHT` | Executa `04-munta-video.sh` i `05-comprimeix-15mb.sh` | Només màster i vídeo comprimit |
| `FINAL_HEIGHT`, `FINAL_FPS`, `TARGET_MB` o bitrate | Executa `05-comprimeix-15mb.sh` | Només vídeo comprimit |
| Música (`USE_MUSIC`, `MUSIC_FILE`, `MUSIC_VOLUME`) | Executa `04-munta-video.sh` i després `05-comprimeix-15mb.sh` | Màster i vídeo comprimit |

### Exemple: passar de vertical a horitzontal

La configuració actual és vertical, adequada per a Reels, TikTok o Stories:

```bash
MASTER_WIDTH=1080
MASTER_HEIGHT=1920
```

Per a YouTube o una presentació horitzontal, canvia només:

```bash
MASTER_WIDTH=1920
MASTER_HEIGHT=1080
```

No cal tornar a generar la veu ni les imatges. Amb les imatges i l'àudio disponibles, executa:

```bash
./04-munta-video.sh
./05-comprimeix-15mb.sh
scripts/validate-video-project.sh
```

Si abans has netejat els fitxers de treball, primer hauràs de tornar a generar la veu i les imatges amb `./genera-video-complet.sh`.

### Exemple: fer un vídeo nou amb un altre guió

1. Guarda una còpia del vídeo anterior: ja estarà en `videos-generats/`.
2. Substitueix el contingut de `guio/guio.txt`.
3. Canvia `PROJECT_NAME` en `config.env` per identificar el nou resultat.
4. Executa `python3 02-prepara-escenes.py` i revisa `manifest.json`.
5. Corregeix els prompts o la veu abans de generar.
6. Executa `./genera-video-complet.sh`.
7. Quan pregunte per la neteja, respon `y`/`s` si vols conservar només l'arxiu final.

El canvi de guió activa automàticament la neteja dels fitxers de treball antics. L'arxiu del vídeo anterior continua intacte.

## 9. Muntar el vídeo mestre

Executa:

```bash
./04-munta-video.sh
```

El muntatge usa FFmpeg i un moviment Ken Burns suau. Si existeixen WAV individuals:

```text
locucio/fragments/001.wav
locucio/fragments/002.wav
...
```

cada imatge dura exactament el mateix que el seu fragment de veu.

Si només existeix `locucio/locucio.wav`, reparteix la duració total entre totes les imatges.

Eixida:

```text
video/master.mp4
```

El màster convé conservar-lo sempre en bona qualitat.

## 10. Comprimir automàticament a menys de 15 MB

Executa:

```bash
./05-comprimeix-15mb.sh
```

El script calcula automàticament el bitrate disponible segons:

- duració real del vídeo;
- `TARGET_MB`;
- bitrate de l'àudio.

Per defecte utilitza:

```bash
TARGET_MB=14.5
```

Això deixa un poc de marge respecte al límit de 15 MB.

Fa codificació H.264 en **dues passades**, molt més adequada que un CRF fix quan el requisit principal és la mida final.

Eixida:

```text
video/final-15mb.mp4
```

## 11. Arxiu i neteja

`./genera-video-complet.sh` conserva automàticament cada vídeo acabat en una carpeta nova dins de `videos-generats/`, amb el nom `PROJECT_NAME-data-hora`. Guarda el vídeo comprimit i el `manifest.json` de la mateixa execució; estes carpetes no es toquen quan es prepara un guió nou.

Al final pregunta si vols eliminar els fitxers de treball: imatges generades, fragments d'àudio, vídeos intermedis i fitxers temporals. Respon `y` o `s` per netejar-los, o simplement `Enter` per conservar-los.

## 12. Supervisor i agents

La branca `automation/openproject-supervisor` inclou agents i skills de VS Code/Copilot per automatitzar el flux complet:

- `Video Supervisor`: coordina escenes, prompts, TTS, ComfyUI i validació.
- `Scene Director`: transforma text lliure en un guió amb escenes, veus i prompts visuals.
- `Visual Prompt Translator`: crea `IMATGE_EN:` sense modificar el diàleg.
- `Image Quality Inspector`: comprova personatges, composició i resolució.
- `Pipeline Runner`: executa les fases locals i diagnostica errors.

També pots invocar el prompt `.github/prompts/run-video-supervisor.prompt.md`.

En OpenCode, la petició recomanada és dirigir-se al `Video Supervisor` amb el text complet. En VS Code/Copilot, pots invocar `Scene Director` per preparar només el guió o `Video Supervisor` per preparar-lo i continuar amb el vídeo.

La validació final és:

```bash
scripts/validate-video-project.sh
```

La documentació de la futura connexió amb OpenProject és a `docs/OPENPROJECT-AUTOMATION.md`. No es guarden tokens ni credencials en el repositori.

Si el fitxer encara supera `TARGET_MB` per overhead del contenidor, el script fa un segon intent reduint lleugerament el bitrate.

## 13. Fer-ho tot seguit

Una vegada configurat el TTS i ComfyUI:

```bash
./genera-video-complet.sh
```

Executarà:

1. `02-prepara-escenes.py` (crea el manifest)
2. `01-genera-locucio.py`
3. `03-genera-imatges.py`
4. `04-munta-video.sh`
5. `05-comprimeix-15mb.sh`
6. `scripts/validate-video-project.sh`
7. arxiu del vídeo i pregunta de neteja

També pots saltar passos:

```bash
SKIP_TTS=1 ./genera-video-complet.sh
```

```bash
SKIP_IMAGES=1 ./genera-video-complet.sh
```

```bash
SKIP_TTS=1 SKIP_IMAGES=1 ./genera-video-complet.sh
```

Açò és útil quan ja tens la veu o les imatges i no vols que el pobre ordinador torne a pintar trenta castells perquè sí.

## 14. Música de fons

En `config.env`:

```bash
USE_MUSIC=1
MUSIC_FILE="/ruta/a/musica.mp3"
MUSIC_VOLUME=0.16
```

El muntatge farà loop de la música i la mesclarà per davall de la veu.

## 15. Variables principals de `config.env`

| Variable | Funció |
|---|---|
| `VISUAL_STYLE` | Estil general de totes les imatges |
| `MASTER_WIDTH/HEIGHT` | Resolució del màster |
| `TARGET_MB` | Mida objectiu final |
| `FINAL_HEIGHT` | Resolució vertical del vídeo comprimit |
| `FINAL_FPS` | FPS del vídeo final |
| `AUDIO_BITRATE_K` | Bitrate AAC |
| `MUSIC_VOLUME` | Volum de la música de fons |

Per a Instagram/Reels/TikTok, el valor per defecte del màster és vertical `1080x1920`.

Per a vídeo horitzontal, canvia:

```bash
MASTER_WIDTH=1920
MASTER_HEIGHT=1080
```

## 16. Recomanació de treball

Conserva sempre:

```text
video/master.mp4
```

I genera versions derivades segons el destí:

```text
video/final-15mb.mp4
video/instagram.mp4
video/whatsapp.mp4
video/youtube.mp4
```

El màster és la còpia bona. No té massa sentit comprimir a 15 MB i després usar eixa versió per tornar a comprimir; això és com fotocopiar una fotocòpia d'una fotocòpia i esperar que aparega el 4K per intervenció divina.

## 17. Ordre ràpida

```bash
nano guio/guio.txt
nano config.env
./genera-video-complet.sh
```

El resultat temporal serà:

```text
video/final-15mb.mp4
```

La còpia conservada quedarà en una carpeta nova dins de:

```text
videos-generats/
```
