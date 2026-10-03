#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
_COMFYUI_REPO="${COMFYUI_REPO-}"
_COMFYUI_DIR="${COMFYUI_DIR-}"
_COMFYUI_VENV="${COMFYUI_VENV-}"
_PYTORCH_INDEX_URL="${PYTORCH_INDEX_URL-}"
_TTS_IMAGE="${TTS_IMAGE-}"
_TTS_CONTAINER="${TTS_CONTAINER-}"
_TTS_PORT="${TTS_PORT-}"
_MODEL_DIR="${COMFYUI_MODEL_DIR-}"

if [[ -f "$ROOT/config.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/config.env"
fi

[[ -n "$_COMFYUI_REPO" ]] && COMFYUI_REPO="$_COMFYUI_REPO"
[[ -n "$_COMFYUI_DIR" ]] && COMFYUI_DIR="$_COMFYUI_DIR"
[[ -n "$_COMFYUI_VENV" ]] && COMFYUI_VENV="$_COMFYUI_VENV"
[[ -n "$_PYTORCH_INDEX_URL" ]] && PYTORCH_INDEX_URL="$_PYTORCH_INDEX_URL"
[[ -n "$_TTS_IMAGE" ]] && TTS_IMAGE="$_TTS_IMAGE"
[[ -n "$_TTS_CONTAINER" ]] && TTS_CONTAINER="$_TTS_CONTAINER"
[[ -n "$_TTS_PORT" ]] && TTS_PORT="$_TTS_PORT"
[[ -n "$_MODEL_DIR" ]] && COMFYUI_MODEL_DIR="$_MODEL_DIR"

: "${COMFYUI_REPO:=https://github.com/comfyanonymous/ComfyUI.git}"
: "${COMFYUI_DIR:=$HOME/Projectes/ComfyUI}"
: "${COMFYUI_VENV:=.venv}"
: "${PYTORCH_INDEX_URL:=https://download.pytorch.org/whl/cu128}"
: "${TTS_IMAGE:=projecteaina/tts-api:latest}"
: "${TTS_CONTAINER:=crearvideo-aina-tts}"
: "${TTS_PORT:=8000}"
: "${COMFYUI_MODEL_DIR:=$COMFYUI_DIR/models/checkpoints}"
MODEL_DIR="$COMFYUI_MODEL_DIR"

CHECK_ONLY=0
case "${1:-}" in
  --check) CHECK_ONLY=1 ;;
  -h|--help)
    cat <<EOF
Ús: $0 [--check]
Sense arguments instal·la dependències i prepara ComfyUI i l'API TTS.
--check comprova el sistema i els fitxers sense instal·lar ni descarregar res.
Configurables: COMFYUI_DIR, COMFYUI_REPO, PYTORCH_INDEX_URL, TTS_IMAGE,
TTS_CONTAINER, TTS_PORT i COMFYUI_MODEL_DIR.
EOF
    exit 0
    ;;
  "") ;;
  *) echo "ERROR: argument desconegut: $1 (usa --help)." >&2; exit 2 ;;
esac

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

check_platform() {
  [[ -r /etc/os-release ]] || die "no trobe /etc/os-release; cal Pop!_OS o Ubuntu amb NVIDIA."
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "pop" && "${ID_LIKE:-}" != *ubuntu* ]]; then
    die "sistema no compatible (${PRETTY_NAME:-desconegut}); usa Pop!_OS o Ubuntu."
  fi
  command -v nvidia-smi >/dev/null 2>&1 || die "falta nvidia-smi; instal·la el controlador NVIDIA i reinicia."
  nvidia-smi >/dev/null 2>&1 || die "nvidia-smi no detecta cap GPU; comprova el controlador NVIDIA, Secure Boot i reinicia."
  info "GPU NVIDIA detectada: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)"
}

check_commands() {
  local missing=()
  for command in git curl python3 ffmpeg ffprobe docker; do
    command -v "$command" >/dev/null 2>&1 || missing+=("$command")
  done
  if (( ${#missing[@]} )); then
    printf 'Falten: %s\n' "${missing[*]}"
    (( CHECK_ONLY )) && return 1
  fi
  docker info >/dev/null 2>&1 || echo "AVÍS: Docker no respon ara; l'instal·lador l'activarà si pot."
}

check_model() {
  if find "$MODEL_DIR" -maxdepth 1 -type f \( -name '*.safetensors' -o -name '*.ckpt' -o -name '*.pth' \) -print -quit 2>/dev/null | grep -q .; then
    info "Hi ha almenys un checkpoint a $MODEL_DIR."
  else
    cat <<EOF
AVÍS: no hi ha cap model de ComfyUI a $MODEL_DIR.
Instal·la manualment un checkpoint compatible amb el workflow a eixa carpeta,
revisa la llicència i no el descarregues automàticament amb este instal·lador.
EOF
  fi
}

check_platform
if (( CHECK_ONLY )); then
  check_commands || true
  [[ -f "$COMFYUI_DIR/main.py" ]] && info "ComfyUI trobat a $COMFYUI_DIR" || echo "AVÍS: ComfyUI encara no està instal·lat a $COMFYUI_DIR."
  check_model
  [[ -f "$ROOT/workflows/comfyui_api_workflow.json" ]] || echo "AVÍS: falta el workflow API del projecte."
  echo "Comprovació finalitzada; no s'ha modificat res."
  exit 0
fi

[[ $EUID -ne 0 ]] || die "executa este script com a usuari normal; usarà sudo quan calga."
command -v sudo >/dev/null 2>&1 || die "falta sudo per instal·lar paquets del sistema."

info "Instal·lant dependències del sistema"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl git ffmpeg python3 python3-venv python3-pip build-essential docker.io
sudo systemctl enable --now docker
if ! docker info >/dev/null 2>&1; then
  echo "AVÍS: Docker està instal·lat però el teu usuari encara no pot accedir al socket."
  sudo usermod -aG docker "$USER"
fi

if [[ -e "$COMFYUI_DIR" ]]; then
  [[ -f "$COMFYUI_DIR/main.py" ]] || die "$COMFYUI_DIR existeix però no sembla ComfyUI; no el sobreescric."
  info "ComfyUI existent: $COMFYUI_DIR"
else
  info "Clonant ComfyUI a $COMFYUI_DIR"
  mkdir -p "$(dirname "$COMFYUI_DIR")"
  git clone "$COMFYUI_REPO" "$COMFYUI_DIR"
fi

if [[ -x "$COMFYUI_DIR/$COMFYUI_VENV/bin/python" ]]; then
  info "Entorn virtual existent: $COMFYUI_DIR/$COMFYUI_VENV"
else
  [[ ! -e "$COMFYUI_DIR/$COMFYUI_VENV" ]] || die "$COMFYUI_DIR/$COMFYUI_VENV existeix però no és un venv; no el sobreescric."
  python3 -m venv "$COMFYUI_DIR/$COMFYUI_VENV"
fi

info "Instal·lant dependències de ComfyUI"
"$COMFYUI_DIR/$COMFYUI_VENV/bin/python" -m pip install --upgrade pip
"$COMFYUI_DIR/$COMFYUI_VENV/bin/pip" install -r "$COMFYUI_DIR/requirements.txt"
info "Instal·lant PyTorch amb CUDA des de $PYTORCH_INDEX_URL"
"$COMFYUI_DIR/$COMFYUI_VENV/bin/pip" install torch torchvision torchaudio --index-url "$PYTORCH_INDEX_URL"

info "Preparant la imatge Docker de Matxa/Aina: $TTS_IMAGE"
if ! docker image inspect "$TTS_IMAGE" >/dev/null 2>&1; then
  docker pull "$TTS_IMAGE"
else
  info "Imatge Docker existent; no la torne a descarregar."
fi

mkdir -p "$MODEL_DIR"
check_model
[[ -f "$ROOT/workflows/comfyui_api_workflow.json" ]] || echo "AVÍS: copia un workflow exportat en API format a workflows/comfyui_api_workflow.json."

cat <<EOF

Instal·lació preparada. Configuració: $ROOT/config.env
ComfyUI: $COMFYUI_DIR (venv: $COMFYUI_VENV)
TTS: Docker $TTS_CONTAINER en 127.0.0.1:$TTS_PORT

Següents passos:
  1. Revisa config.env i posa el workflow API i el model de ComfyUI.
  2. Escriu el guió a $ROOT/guio/guio.txt.
  3. Executa: cd "$ROOT" && ./genera-video-complet.sh
EOF