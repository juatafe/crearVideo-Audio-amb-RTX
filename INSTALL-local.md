# Instal·lació local en Pop!_OS / Ubuntu amb NVIDIA

Este repositori genera un vídeo a partir de `guio/guio.txt`: locució amb Matxa/Aina, imatges amb ComfyUI i muntatge amb FFmpeg.

## Requisits

- Pop!_OS o Ubuntu de 64 bits.
- GPU NVIDIA amb el controlador instal·lat i operatiu. `nvidia-smi` ha de mostrar la GPU abans d’executar l’instal·lador.
- Connexió a Internet, permisos `sudo` i Docker.
- Espai recomanat: 15 GB lliures com a mínim per al codi, entorn Python, imatge Docker i memòria cau; reserva 30 GB o més per a treballar amb checkpoints i la caché de PyTorch. Els models poden ocupar diversos GB i no els baixa l’instal·lador.

## Instal·lar

Des del directori del repositori:

```bash
./instal·la-linux.sh --check
./instal·la-linux.sh
```

L’instal·lador instal·la Python, `venv`, `pip`, FFmpeg, Git, curl, Docker i eines de compilació; clona ComfyUI només si la ruta no existeix, crea el seu venv, instal·la els seus requisits i instal·la PyTorch amb CUDA. La ruta es pot canviar sense editar el script:

```bash
COMFYUI_DIR="$HOME/ComfyUI" ./instal·la-linux.sh
```

Els fitxers i directoris que ja existeixen no se sobreescriuen. Si Docker acaba d’afegir l’usuari al grup `docker`, cal tancar sessió i tornar a entrar.

## ComfyUI i models

Obri ComfyUI, exporta un workflow en **API format** i guarda’l com `workflows/comfyui_api_workflow.json`. L’exemple del repositori és només una guia i no genera imatges.

El workflow ha de referenciar un checkpoint instal·lat a `COMFYUI_DIR/models/checkpoints`. L’instal·lador només comprova si hi ha un fitxer `.safetensors`, `.ckpt` o `.pth`; no baixa ni substitueix models. Descarrega manualment un model compatible amb el workflow des de la seua font oficial, revisa la llicència i copia’l a eixa carpeta. Es pot canviar la carpeta de comprovació amb `COMFYUI_MODEL_DIR`.

El workflow actiu usa `DreamShaperXL_Turbo-Lightning.safetensors`, instal·lat a `COMFYUI_DIR/models/checkpoints/`. És un checkpoint SDXL Turbo; revisa la llicència i la font abans de redistribuir-lo. El checkpoint base `v1-5-pruned-emaonly.safetensors` es conserva per a proves, però no és el model del workflow actual.

## Projecte Aina / Matxa

- [Aina Kit](https://github.com/projecte-aina)
- [API TTS oficial d’Aina](https://github.com/projecte-aina/tts-api)
- [Model Matxa-TTS català multiaccent](https://huggingface.co/projecte-aina/matxa-tts-cat-multiaccent)
- [Demo Matxa + alVoCat](https://huggingface.co/spaces/projecte-aina/matxa-alvocat-tts-ca)

L’API es prepara amb la imatge Docker `projecteaina/tts-api:latest`. El model Matxa pot estar subjecte a accés autenticat i les condicions d’ús de les veus; consulta sempre la documentació oficial. La configuració predeterminada usa la veu `quim` i l’idioma `ca-va`. Per a castellà, el projecte usa Piper i el model `models/tts/piper/es_ES-davefx-medium.onnx`. Es poden canviar `TTS_VOICE`, `TTS_LANGUAGE`, `TTS_API_URL`, `PIPER_BIN` i `PIPER_MODEL` a `config.env`.

Per instal·lar Piper i descarregar la veu castellana:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
mkdir -p models/tts/piper
.venv/bin/python -m piper.download_voices \
	--download-dir models/tts/piper es_ES-davefx-medium
```

## Executar

1. Escriu o enganxa el text a `guio/guio.txt`. Separa escenes amb una línia que continga només `---`.
2. Revisa `config.env`, especialment `COMFYUI_DIR`, `COMFYUI_URL` i `TTS_API_URL`.
3. Executa:

```bash
./genera-video-complet.sh
```

El script arranca ComfyUI i el contenidor TTS si no responen, espera els endpoints i executa les cinc fases. Els serveis es deixen en marxa en acabar. Les eixides són `video/master.mp4` i `video/final-15mb.mp4`.

### Diverses veus

Indica la veu amb `VEU:` al principi de cada escena. El nom ha de ser una veu disponible en l’API Matxa/Aina. Una nova línia `VEU:` també inicia automàticament una escena nova, però és més clar separar els parlants amb `---`:

```text
VEU: quim
Gabinet de família burgesa. Apareix Carlos assegut en un divà. Carlos és ros i àgil. A vegades adopta una actitud d’home cansat.

---

VEU: gina
La veu de la narradora descriu què passa a continuació.
```

Les directives `VEU:` i `IDIOMA:` no es narren ni apareixen en el prompt de la imatge. Sense `IDIOMA:`, s’usa `TTS_LANGUAGE` de `config.env`. Les escenes `ca-*` van a Matxa/Aina i les `es-*` a Piper.

Quan canvies el text, la veu o l’idioma, el programa detecta el canvi i regenera automàticament el fragment WAV. No cal eliminar els àudios manualment.

## Ajustar la qualitat visual

La qualitat final depén sobretot del workflow exportat des de ComfyUI. El workflow inclòs està ajustat per a DreamShaper XL Turbo: resolució vertical `768x1024`, 6 passos, CFG `2`, sampler `dpmpp_sde` i scheduler `karras`. Si canvies de checkpoint, consulta les recomanacions del model i exporta de nou el workflow API.

Quan canvia `VISUAL_STYLE`, `NEGATIVE_PROMPT` o el workflow, el programa detecta el canvi i regenera automàticament les imatges. Els fitxers `.prompt` són només marcadors petits i no contenen cap model.

Per saltar una fase ja completada:

```bash
SKIP_TTS=1 ./genera-video-complet.sh
SKIP_IMAGES=1 ./genera-video-complet.sh
```

## Diagnòstic

```bash
nvidia-smi
docker info
docker ps -a --filter name=crearvideo-aina-tts
docker logs crearvideo-aina-tts
curl -f http://127.0.0.1:8188/system_stats
curl -f http://127.0.0.1:8000/openapi.json
tail -f tmp/comfyui.log
```

Errors habituals:

- `nvidia-smi` falla: instal·la el controlador NVIDIA corresponent a la distribució, comprova Secure Boot i reinicia.
- Docker no té permisos: torna a iniciar sessió després de `sudo usermod -aG docker "$USER"`, o executa temporalment amb un usuari amb accés al socket.
- ComfyUI no arranca: revisa `tmp/comfyui.log`, la ruta `COMFYUI_DIR`, el venv i que `workflows/comfyui_api_workflow.json` use nodes `CLIPTextEncode` i `SaveImage`.
- Falta un checkpoint: copia manualment un model compatible a `COMFYUI_DIR/models/checkpoints`; no és un error que l’instal·lador resolga automàticament.
- TTS no respon: revisa `docker logs crearvideo-aina-tts`, el port `TTS_PORT`, l’accés al model de l’API i els valors de veu/idioma.

Per aturar els serveis manualment:

```bash
docker stop crearvideo-aina-tts
kill "$(cat tmp/comfyui.pid)" 2>/dev/null || true
```
