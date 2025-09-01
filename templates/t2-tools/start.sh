#!/usr/bin/env bash
set -euo pipefail

echo "------------------------------------------------------------------"
echo "# Template 2 launcher: A1111  + (optional) File Browser + Jupyter"
echo "------------------------------------------------------------------"

# -------- helper: check if a TCP port is listening
port_listening() {
  local p="${1:?port}"
  if command -v ss >/dev/null 2>&1; then
    ss -lntp 2>/dev/null | grep -q ":${p} "
  else
    netstat -tulpen 2>/dev/null | grep -q ":${p} "
  fi
}

# -------- env / defaults
DATA_DIR="${DATA_DIR:-/workspace/a1111-data}"
WEBUI_ARGS="${WEBUI_ARGS:---listen --port 7860 --api}"

# Optional caches (quiet warnings + speed if /workspace is persisted)
for v in PIP_CACHE_DIR HF_HOME TORCH_HOME; do
  val="${!v:-}"
  if [[ -n "${val}" ]]; then
    mkdir -p "$val" || true
  fi
done

# Core layout for A1111
mkdir -p "${DATA_DIR}"/{models/Stable-diffusion,models/ControlNet,extensions,outputs}

# Put the venv on PATH if present
export PATH="/opt/venv/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

# -------- Start File Browser (optional)  : default port 8080
if [[ "${ENABLE_FILEBROWSER:-false}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
  FB_BIN="$(command -v filebrowser || true)"
  FB_PORT="${FILEBROWSER_PORT:-8080}"
  FB_NOAUTH="${FILEBROWSER_NOAUTH:-true}"

  if [[ -x "$FB_BIN" ]]; then
    echo "[start] File Browser on :${FB_PORT}"
    nohup "$FB_BIN" \
      --address 0.0.0.0 \
      --port "$FB_PORT" \
      --root / \
      $( [[ "$FB_NOAUTH" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]] && echo --noauth ) \
      >/workspace/filebrowser.log 2>&1 &
    # wait up to 30s
    for i in {1..30}; do
      port_listening "$FB_PORT" && echo "[ok] File Browser listening on :${FB_PORT}" && break
      sleep 1
      [[ $i -eq 30 ]] && echo "[warn] File Browser not listening after 30s" && break
    done
  else
    echo "[warn] filebrowser binary not found on PATH; skipping."
  fi
else
  echo "[skip] File Browser disabled (ENABLE_FILEBROWSER=${ENABLE_FILEBROWSER:-unset})"
fi

# -------- Start JupyterLab (optional)    : default port 8888
if [[ "${ENABLE_JUPYTER:-false}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
  J_BIN="$(command -v jupyter || true)"
  J_PORT="${JUPYTER_PORT:-8888}"
  J_DIR="${JUPYTER_DIR:-/workspace}"
  J_TOKEN="${JUPYTER_TOKEN:-}"
  J_RUN="/workspace/.jupyter_runtime"; mkdir -p "$J_RUN" || true

  if [[ -x "$J_BIN" ]]; then
    echo "[start] JupyterLab on :${J_PORT}  root=${J_DIR} token='${J_TOKEN:+***set***}'"
    nohup "$J_BIN" lab \
      --ServerApp.ip=0.0.0.0 \
      --ServerApp.port="$J_PORT" \
      --ServerApp.port_retries=0 \
      --ServerApp.root_dir="$J_DIR" \
      --ServerApp.runtime_dir="$J_RUN" \
      --ServerApp.token="$J_TOKEN" \
      --ServerApp.allow_origin="*" \
      --ServerApp.allow_remote_access=True \
      --no-browser \
      --allow-root \
      >/workspace/jupyter.log 2>&1 &
    # wait up to 30s
    for i in {1..30}; do
      port_listening "$J_PORT" && echo "[ok] JupyterLab listening on :${J_PORT}" && break
      sleep 1
      [[ $i -eq 30 ]] && echo "[warn] JupyterLab not listening after 30s" && break
    done
  else
    echo "[warn] jupyter binary not found on PATH; skipping."
  fi
else
  echo "[skip] JupyterLab disabled (ENABLE_JUPYTER=${ENABLE_JUPYTER:-unset})"
fi

# -------- Health shim on :3000 (HTTP 503 until A1111 is ready → 200)
python3 - <<'PY' &
import http.server, socketserver, os, time, urllib.request
PORT=3000
def ready():
    try:
        with urllib.request.urlopen("http://127.0.0.1:7860", timeout=0.3) as r: return True
    except Exception: return False
class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        c=200 if ready() else 503
        self.send_response(c); self.end_headers(); self.wfile.write(f"{c}\n".encode())
with socketserver.TCPServer(("0.0.0.0", PORT), H) as httpd: httpd.serve_forever()
PY

# -------- Start A1111 (non-blocking)
echo "[start] A1111 on :7860 (data dir: ${DATA_DIR})"
nohup /opt/webui/webui.sh --data-dir "${DATA_DIR}" \
  --enable-insecure-extension-access ${WEBUI_ARGS} \
  >/opt/webui/webui.log 2>&1 &

# Keep container alive and show tail
echo "[tail] /opt/webui/webui.log"
tail -n +1 -f /opt/webui/webui.log
