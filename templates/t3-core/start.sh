#!/usr/bin/env bash
set -euo pipefail

echo "---------------------------------------------------------------"
echo "# Template 3: A1111 + File Browser + Jupyter + Core Extensions"
echo "---------------------------------------------------------------"

port_listening() {
  local p="${1:?port}"
  if command -v ss >/dev/null 2>&1; then
    ss -lntp 2>/dev/null | grep -q ":${p} "
  else
    netstat -tulpen 2>/dev/null | grep -q ":${p} "
  fi
}

norm_true() {
  [[ "$(echo "${1:-}" | sed 's/#.*$//' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')" =~ ^(true|1|yes)$ ]]
}

DATA_DIR="${DATA_DIR:-/workspace/a1111-data}"
WEBUI_ARGS="${WEBUI_ARGS:---listen --api}"

# Ensure dirs
mkdir -p "${DATA_DIR}"/{models/Stable-diffusion,models/ControlNet,extensions,outputs}

# Optional caches
for v in PIP_CACHE_DIR HF_HOME TORCH_HOME; do
  val="${!v:-}"; [[ -n "$val" ]] && mkdir -p "$val" || true
done

export PATH="/opt/venv/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

# ----- File Browser
if norm_true "${ENABLE_FILEBROWSER:-true}"; then
  FB_PORT="${FILEBROWSER_PORT:-8080}"
  echo "[start] File Browser :${FB_PORT}"
  nohup filebrowser --address 0.0.0.0 --port "$FB_PORT" --root / \
     $( norm_true "${FILEBROWSER_NOAUTH:-true}" && echo --noauth ) \
     >"${DATA_DIR}/filebrowser.log" 2>&1 &
  for i in {1..30}; do port_listening "$FB_PORT" && echo "[ok] filebrowser :$FB_PORT" && break; sleep 1; done
fi

# ----- JupyterLab (isolated venv under /workspace)
if norm_true "${ENABLE_JUPYTER:-true}"; then
  J_DIR="${JUPYTER_DIR:-/workspace}"
  J_PORT="${JUPYTER_PORT:-8888}"
  J_TOK="${JUPYTER_TOKEN:-}"
  J_RUN="${J_DIR}/.jupyter_runtime"
  J_VENV="/workspace/jupyter-venv"

  if [[ ! -x "${J_VENV}/bin/jupyter" ]]; then
    echo "[jup] creating venv at ${J_VENV} ..."
    python3 -m venv "${J_VENV}"
    "${J_VENV}/bin/pip" install --upgrade pip wheel setuptools
    "${J_VENV}/bin/pip" install jupyterlab==4.2.5 notebook==7.2.2
  fi

  mkdir -p "${J_RUN}"
  echo "[start] JupyterLab :${J_PORT} root=${J_DIR} token=${J_TOK:+***set***}"
  nohup "${J_VENV}/bin/jupyter" lab \
    --ServerApp.ip=0.0.0.0 \
    --ServerApp.port="${J_PORT}" \
    --ServerApp.port_retries=0 \
    --ServerApp.root_dir="${J_DIR}" \
    --ServerApp.runtime_dir="${J_RUN}" \
    --ServerApp.token="${J_TOK}" \
    --ServerApp.allow_origin="*" \
    --ServerApp.allow_remote_access=True \
    --no-browser \
    --allow-root \
    >"${DATA_DIR}/jupyter.log" 2>&1 &
  for i in {1..30}; do port_listening "$J_PORT" && echo "[ok] jupyter :${J_PORT}" && break; sleep 1; done
fi

# ----- Core extensions (persist in ${DATA_DIR}/extensions, symlink into /opt/webui)
install_ext() {
  local name="$1" repo="$2" dest="${DATA_DIR}/extensions/${name}"
  if [[ ! -d "$dest/.git" ]]; then
    echo "[ext] installing $name -> $dest"
    git clone --depth=1 "$repo" "$dest" || { echo "[ext] failed: $name"; return 1; }
  else
    echo "[ext] exists: $name"
  fi
}

if norm_true "${ENABLE_EXTENSIONS_CORE:-true}"; then
  norm_true "${ENABLE_EXT_ADETAILER:-true}"       && install_ext "adetailer" "https://github.com/Bing-su/adetailer"
  norm_true "${ENABLE_EXT_CONTROLNET:-true}"      && install_ext "sd-webui-controlnet" "https://github.com/Mikubill/sd-webui-controlnet"
  norm_true "${ENABLE_EXT_ULTUPSCALE:-true}"      && install_ext "ultimate-upscale-for-automatic1111" "https://github.com/Coyote-A/ultimate-upscale-for-automatic1111"
  norm_true "${ENABLE_EXT_IMAGES_BROWSER:-true}"  && install_ext "images-browser" "https://github.com/AlUlkesh/sd-webui-images-browser"

  # Symlink persisted extensions into A1111
  mkdir -p /opt/webui/extensions
  for d in "${DATA_DIR}"/extensions/*; do
    [[ -d "$d" ]] || continue
    ln -sf "$d" "/opt/webui/extensions/$(basename "$d")"
  done
fi

# ----- Health shim on :3000 (503 until A1111 ready)
python3 - <<'PY' &
import http.server, socketserver, urllib.request, os
APP_PORT = int(os.environ.get("PORT","7860"))
def ready():
    try: urllib.request.urlopen(f"http://127.0.0.1:{APP_PORT}", timeout=0.3); return True
    except: return False
class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self): self.send_response(200 if ready() else 503); self.end_headers()
with socketserver.TCPServer(("0.0.0.0",3000), H) as httpd: httpd.serve_forever()
PY

# ----- A1111 (via launch.py) with port fallback
PORT=${PORT:-7860}
if port_listening "$PORT"; then
  echo "[init] port ${PORT} busy, trying 7861"
  PORT=7861
fi
export PORT
echo "[start] A1111 :${PORT} data=${DATA_DIR}"
nohup python3 /opt/webui/launch.py \
  --data-dir "${DATA_DIR}" \
  --enable-insecure-extension-access \
  ${WEBUI_ARGS} \
  --port "${PORT}" \
  >"${DATA_DIR}/webui.log" 2>&1 &

echo "[tail] ${DATA_DIR}/webui.log"
tail -n +1 -f "${DATA_DIR}/webui.log"
