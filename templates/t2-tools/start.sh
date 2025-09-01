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
    echo "[ok] File Browser pid=$FB_PID
