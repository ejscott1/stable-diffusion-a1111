#!/usr/bin/env bash
set -e

# -----------------------------------------------------------------------------
# Template 2 launcher: A1111 + File Browser + JupyterLab
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

# Helper: port check (ss or netstat)
port_in_use() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -lnt | grep -q ":${p} "
  else
    netstat -tuln 2>/dev/null | grep -q ":${p} "
  fi
}

# -------------------------
# Start File Browser (optional)
# -------------------------
if [[ "${ENABLE_FILEBROWSER,,}" == "true" ]]; then
  FB_PORT="${FILEBROWSER_PORT:-8080}"
  FB_ARGS=(--port "${FB_PORT}" --root / --address 0.0.0.0)
  [[ "${FILEBROWSER_NOAUTH,,}" == "true" ]] && FB_ARGS+=("--noauth")

  echo "[start] File Browser ${FB_ARGS[*]}"
  /usr/local/bin/filebrowser "${FB_ARGS[@]}" >/workspace/filebrowser.log 2>&1 &
  FB_PID=$!
  sleep 2
  if ! kill -0 "$FB_PID" 2>/dev/null; then
    echo "[error] File Browser exited. Last log lines:"
    tail -n 50 /workspace/filebrowser.log || true
  else
    echo "[ok] File Browser pid=$FB_PID"
  fi
fi

# -------------------------
# Start JupyterLab (optional)
# -------------------------
if [[ "${ENABLE_JUPYTER,,}" == "true" ]]; then
  JDIR="${JUPYTER_DIR:-/workspace}"
  JPORT="${JUPYTER_PORT:-8888}"
  JTOK="${JUPYTER_TOKEN:-}"
  JOPTS=(--ServerApp.ip=0.0.0.0 --ServerApp.port="${JPORT}" --ServerApp.root_dir="${JDIR}" --ServerApp.allow_origin="*")
  [[ -z "$JTOK" ]] && JOPTS+=(--ServerApp.token='') || JOPTS+=(--ServerApp.token="${JTOK}")

  echo "[start] JupyterLab on :${JPORT} root=${JDIR} token=${JTOK:+***set***}"
  jupyter lab "${JOPTS[@]}" >/workspace/jupyter.log 2>&1 &
  JUP_PID=$!
  sleep 3
  if ! kill -0 "$JUP_PID" 2>/dev/null; then
    echo "[error] Jupyter exited. Last log lines:"
    tail -n 50 /workspace/jupyter.log || true
  else
    echo "[ok] Jupyter pid=$JUP_PID"
  fi
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
if port_in_use "${PORT_DEFAULT}"; then
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
