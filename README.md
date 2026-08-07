# Plantilla reutilitzable per a vídeos amb IA

Esta carpeta automatitza una cadena de treball pensada per a crear vídeos narrats a partir d'un text:

**text → locució → escenes → imatges → muntatge → vídeo final ≤ 15 MB**

La idea és reutilitzar-la per a rondalles, vídeos educatius, històries, divulgació, campanyes, etc. Per a un projecte nou, normalment només cal canviar el guió i l'estil visual.

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

## 7. Muntar el vídeo mestre

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

## 8. Comprimir automàticament a menys de 15 MB

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

Si el fitxer encara supera `TARGET_MB` per overhead del contenidor, el script fa un segon intent reduint lleugerament el bitrate.

## 9. Fer-ho tot seguit

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

## 10. Música de fons

En `config.env`:

```bash
USE_MUSIC=1
MUSIC_FILE="/ruta/a/musica.mp3"
MUSIC_VOLUME=0.16
```

El muntatge farà loop de la música i la mesclarà per davall de la veu.

## 11. Variables principals de `config.env`

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

## 12. Recomanació de treball

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

## 13. Ordre ràpida

```bash
nano guio/guio.txt
nano config.env
./genera-video-complet.sh
```

I el resultat final serà:

```text
video/final-15mb.mp4
```
