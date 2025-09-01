#!/usr/bin/env bash
set -e

# -----------------------------------------------------------------------------
# Template 1 launcher for Automatic1111
# - Works with or without a mounted /workspace volume
# - Optional cache envs supported (PIP_CACHE_DIR, HF_HOME, TORCH_HOME)
# - Health shim on :3000 so RunPod "Ready" flips at the right time
# - Port fallback: 7860 -> 7861 if busy
# - Logs to /opt/webui/webui.log
# -----------------------------------------------------------------------------

# If /workspace isn't writable (no persistent volume), fall back to /tmp
if ! mkdir -p /workspace 2>/dev/null; then
  echo "[init] /workspace not writable, using /tmp"
  export DATA_DIR="/tmp/a1111-data"
fi

# Ensure core layout exists inside DATA_DIR
mkdir -p "${DATA_DIR}"/{models/Stable-diffusion,models/ControlNet,extensions,outputs}

# Optional caches (only if you defined these envs in your RunPod template)
for v in PIP_CACHE_DIR HF_HOME TORCH_HOME; do
  val="${!v}"
  if [[ -n "$val" ]]; then
    mkdir -p "$val"
    echo "[init] ${v} -> $val"
  fi
done

# Health shim on :3000 (503 until A1111 answers on :7860, then 200)
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

# Pick port: default 7860, fallback to 7861 if already in use
PORT_DEFAULT=7860
PORT=${PORT:-$PORT_DEFAULT}
if ss -lnt | grep -q ":${PORT_DEFAULT} "; then
  echo "[init] Port ${PORT_DEFAULT} busy, switching to 7861"
  PORT=7861
fi

# Launch A1111 (log to /opt/webui/webui.log)
cd /opt/webui
exec python3 launch.py \
  --data-dir "${DATA_DIR}" \
  --enable-insecure-extension-access \
  ${WEBUI_ARGS:-} \
  --port ${PORT} \
  2>&1 | tee -a /opt/webui/webui.log
