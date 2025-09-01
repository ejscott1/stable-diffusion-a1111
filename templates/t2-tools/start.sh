#!/usr/bin/env bash
set -euo pipefail

echo "------------------------------------------------------------------"
echo "# Template 2: A1111 + File Browser + (isolated) Jupyter on volume"
echo "------------------------------------------------------------------"

port_listening() {
  local p="${1:?port}"
  if command -v ss >/dev/null 2>&1; then
    ss -lntp 2>/dev/null | grep -q ":${p} "
  else
    netstat -tulpen 2>/dev/null | grep -q ":${p} "
  fi
}

DATA_DIR="${DATA_DIR:-/workspace/a1111-data}"
WEBUI_ARGS="${WEBUI_ARGS:---listen --api}"
mkdir -p "${DATA_DIR}"/{models/Stable-diffusion,models/ControlNet,extensions,outputs}

# Optional caches
for v in PIP_CACHE_DIR HF_HOME TORCH_HOME; do
  val="${!v:-}"; [[ -n "$val" ]] && mkdir -p "$val" || true
done

export PATH="/opt/venv/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

# -------- File Browser (8080)
if [[ "${ENABLE_FILEBROWSER:-true}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
  FB_PORT="${FILEBROWSER_PORT:-8080}"
  echo "[start] File Browser on :${FB_PORT}"
  nohup filebrowser --address 0.0.0.0 --port "$FB_PORT" --root / \
      $( [[ "${FILEBROWSER_NOAUTH:-true}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]] && echo --noauth ) \
      >"${DATA_DIR}/filebrowser.log" 2>&1 &
  for i in {1..30}; do port_listening "$FB_PORT" && echo "[ok] filebrowser :$FB_PORT" && break; sleep 1; done
fi

# -------- JupyterLab (isolated venv on /workspace)
if [[ "${ENABLE_JUPYTER:-true}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
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
  echo "[start] JupyterLab on :${J_PORT} root=${J_DIR} token=${J_TOK:+***set***}"
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

# -------- Health shim on :3000 (503 until A1111 ready)
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

# -------- A1111 (via launch.py)
PORT=${PORT:-7860}
echo "[start] A1111 :${PORT}  data=${DATA_DIR}"
nohup python3 /opt/webui/launch.py \
  --data-dir "${DATA_DIR}" \
  --enable-insecure-extension-access \
  ${WEBUI_ARGS} \
  --port "${PORT}" \
  >"${DATA_DIR}/webui.log" 2>&1 &

echo "[tail] ${DATA_DIR}/webui.log"
tail -n +1 -f "${DATA_DIR}/webui.log"
