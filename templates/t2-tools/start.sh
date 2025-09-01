#!/usr/bin/env bash
set -e

# -----------------------------------------------------------------------------
# Template 2 launcher: A1111 + File Browser + JupyterLab
# - Works with or without mounted /workspace
# - Health shim on :3000 (follows A1111 readiness)
# - File Browser on :8080 (optional, no auth by default)
# - JupyterLab on :8888 (optional, token empty by default)
# -----------------------------------------------------------------------------

# Fallback to /tmp if /workspace not writable
if ! mkdir -p /workspace 2>/dev/null; then
  echo "[init] /workspace not writable, using /tmp"
  export DATA_DIR="/tmp/a1111-data"
fi

# Ensure core layout exists
mkdir -p "${DATA_DIR}"/{models/Stable-diffusion,models/ControlNet,extensions,outputs}

# Optional caches
for v in PIP_CACHE_DIR HF_HOME TORCH_HOME; do
  val="${!v}"
  if [[ -n "$val" ]]; then
    mkdir -p "$val"
    echo "[init] ${v} -> $val"
  fi
done

# -------------------------
# Start File Browser (optional)
# -------------------------
if [[ "${ENABLE_FILEBROWSER,,}" == "true" ]]; then
  FB_ARGS="--port ${FILEBROWSER_PORT:-8080} --root / --address 0.0.0.0"
  if [[ "${FILEBROWSER_NOAUTH,,}" == "true" ]]; then
    FB_ARGS="${FB_ARGS} --noauth"
  fi
  echo "[start] File Browser ${FB_ARGS}"
  /usr/local/bin/filebrowser ${FB_ARGS} >/workspace/filebrowser.log 2>&1 &
fi

# -------------------------
# Start JupyterLab (optional)
# -------------------------
if [[ "${ENABLE_JUPYTER,,}" == "true" ]]; then
  JDIR="${JUPYTER_DIR:-/workspace}"
  JPORT="${JUPYTER_PORT:-8888}"
  JTOK="${JUPYTER_TOKEN:-}"
  JOPTS=(--ServerApp.ip=0.0.0.0 --ServerApp.port="${JPORT}" --ServerApp.root_dir="${JDIR}" --ServerApp.allow_origin="*")
  if [[ -z "$JTOK" ]]; then
    JOPTS+=(--ServerApp.token='')
  else
    JOPTS+=(--ServerApp.token="${JTOK}")
  fi
  echo "[start] JupyterLab on :${JPORT} root=${JDIR} token=${JTOK:+***set***}"
  jupyter lab "${JOPTS[@]}" >/workspace/jupyter.log 2>&1 &
fi

# -------------------------
# Health shim on :3000 (503 until A1111 answers :7860, then 200)
# -------------------------
python3 - <<'PY' >/workspace/health.log 2>&1 &
import http.server, socketserver, threading, time, urllib.request
ready = False
def poll():
    global ready
    while True:
        try:
            urllib.request.urlopen("http://127.0.0.1:7860/", timeout=1)
            ready = True
            time.sleep(2)
        except Exception:
            ready = False
            time.sleep(1)
class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        code = 200 if ready else 503
        self.send_response(code); self.end_headers()
        self.wfile.write(b"ok" if ready else b"starting")
threading.Thread(target=poll, daemon=True).start()
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("0.0.0.0", 3000), H) as httpd:
    httpd.serve_forever()
PY

# -------------------------
# Pick A1111 port (fallback 7861 if busy)
# -------------------------
PORT_DEFAULT=7860
PORT=${PORT:-$PORT_DEFAULT}
if ss -lnt | grep -q ":${PORT_DEFAULT} "; then
  echo "[init] Port ${PORT_DEFAULT} busy, switching to 7861"
  PORT=7861
fi

# -------------------------
# Launch A1111 (tee to log)
# -------------------------
cd /opt/webui
exec python3 launch.py \
  --data-dir "${DATA_DIR}" \
  --enable-insecure-extension-access \
  ${WEBUI_ARGS:-} \
  --port ${PORT} \
  2>&1 | tee -a /opt/webui/webui.log
