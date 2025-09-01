#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Template 2 launcher: A1111 + File Browser + JupyterLab
# -----------------------------------------------------------------------------

# -------- helper: check if a TCP port is listening
port_listening() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -lntp | grep -q ":${p} "
  else
    netstat -tulpen 2>/dev/null | grep -q ":${p} "
  fi
}

# -------- workspace / data dir
DATA_DIR="${DATA_DIR:-/workspace/a1111-data}"
if ! mkdir -p /workspace 2>/dev/null; then
  echo "[init] /workspace not writable; switching to /tmp"
  DATA_DIR="/tmp/a1111-data"
  mkdir -p /tmp
fi

# Core layout for A1111
mkdir -p "${DATA_DIR}"/{models/Stable-diffusion,models/ControlNet,extensions,outputs}

# Optional caches (quiet warnings + speed if /workspace is persisted)
for v in PIP_CACHE_DIR HF_HOME TORCH_HOME; do
  val="${!v-}"
  if [[ -n "${val}" ]]; then
    mkdir -p "${val}"
    echo "[init] ${v}=${val}"
  fi
done

# -----------------------------------------------------------------------------
# Start File Browser (optional)  — default port 8080
# -----------------------------------------------------------------------------
if [[ "${ENABLE_FILEBROWSER:-true}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
  FB_PORT="${FILEBROWSER_PORT:-8080}"
  echo "[start] File Browser on :${FB_PORT}"
  # --noauth if requested
  FB_NOAUTH_FLAG=""
  [[ "${FILEBROWSER_NOAUTH:-true}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]] && FB_NOAUTH_FLAG="--noauth"

  /usr/local/bin/filebrowser \
      --port "${FB_PORT}" \
      --root / \
      --address 0.0.0.0 \
      ${FB_NOAUTH_FLAG} \
      >/workspace/filebrowser.log 2>&1 &

  # wait up to 15s for listen
  for i in {1..15}; do
    if port_listening "${FB_PORT}"; then
      echo "[ok] File Browser listening on :${FB_PORT}"
      break
    fi
    sleep 1
  done
  if ! port_listening "${FB_PORT}"; then
    echo "[error] File Browser failed to start. Last log lines:"
    tail -n 100 /workspace/filebrowser.log || true
  fi
fi

# -----------------------------------------------------------------------------
# Start JupyterLab (optional) — default port 8888
# -----------------------------------------------------------------------------
if [[ "${ENABLE_JUPYTER:-true}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
  JDIR="${JUPYTER_DIR:-/workspace}"
  JPORT="${JUPYTER_PORT:-8888}"
  JTOK="${JUPYTER_TOKEN:-}"
  JRUN="${JDIR}/.jupyter_runtime"
  mkdir -p "${JRUN}"

  echo "[start] JupyterLab on :${JPORT} root=${JDIR} token=${JTOK:+***set***}"

  jupyter lab \
    --ServerApp.ip=0.0.0.0 \
    --ServerApp.port="${JPORT}" \
    --ServerApp.port_retries=0 \
    --ServerApp.token="${JTOK}" \
    --ServerApp.root_dir="${JDIR}" \
    --ServerApp.runtime_dir="${JRUN}" \
    --ServerApp.allow_origin="*" \
    --ServerApp.allow_remote_access=True \
    --no-browser \
    --allow-root \
    >/workspace/jupyter.log 2>&1 &

  # wait up to 30s for listen
  for i in {1..30}; do
    if port_listening "${JPORT}"; then
      echo "[ok] JupyterLab listening on :${JPORT}"
      break
    fi
    sleep 1
  done
  if ! port_listening "${JPORT}"; then
    echo "[error] JupyterLab failed to start. Last log lines:"
    tail -n 120 /workspace/jupyter.log || true
  fi
fi

# -----------------------------------------------------------------------------
# Health shim (HTTP 503 until A1111 responds on 7860/7861, then 200) on :3000
# -----------------------------------------------------------------------------
python3 - <<'PY' >/workspace/health.log 2>&1 &
import http.server, socketserver, threading, time, urllib.request
ready=False
def poll():
    global ready
    while True:
        try:
            for port in (7860,7861):
                try:
                    urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=1)
                    ready=True; break
                except Exception:
                    pass
            time.sleep(2 if ready else 1)
        except Exception:
            ready=False; time.sleep(1)
class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200 if ready else 503); self.end_headers()
        self.wfile.write(b"ok" if ready else b"starting")
socketserver.TCPServer.allow_reuse_address=True
threading.Thread(target=poll, daemon=True).start()
with socketserver.TCPServer(("0.0.0.0",3000), H) as httpd:
    httpd.serve_forever()
PY

# -----------------------------------------------------------------------------
# Pick A1111 port (fallback to 7861 if 7860 is busy)
# -----------------------------------------------------------------------------
PORT="${PORT:-7860}"
if port_listening "7860"; then
  echo "[init] Port 7860 is already in use; using 7861"
  PORT=7861
fi

# -----------------------------------------------------------------------------
# Launch A1111 (tee logs)
# -----------------------------------------------------------------------------
cd /opt/webui

# Allow extra args from WEBUI_ARGS, but enforce our data dir & chosen port
echo "[start] A1111 on :${PORT} (data dir: ${DATA_DIR})"
exec python3 launch.py \
  --data-dir "${DATA_DIR}" \
  --enable-insecure-extension-access \
  ${WEBUI_ARGS:-} \
  --port "${PORT}" \
  2>&1 | tee -a /opt/webui/webui.log
