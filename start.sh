#!/usr/bin/env bash
# Minimal launcher: A1111 + Jupyter. No bundled models/extensions.
set -eE -o pipefail

DATA_DIR="${DATA_DIR:-/workspace/a1111-data}"
WEBUI_ARGS="${WEBUI_ARGS:---listen --api}"
PORT="${PORT:-7860}"

mkdir -p "${DATA_DIR}"
export PATH="/opt/venv/bin:${PATH}"

# ----------------- Jupyter -----------------
J_DIR="${JUPYTER_DIR:-/workspace}"
J_PORT="${JUPYTER_PORT:-8888}"
J_TOK="${JUPYTER_TOKEN:-}"
J_VENV="/workspace/jupyter-venv"

if [[ ! -x "${J_VENV}/bin/jupyter" ]]; then
  echo "[jupyter] creating venv at ${J_VENV} ..."
  python3 -m venv "${J_VENV}"
  "${J_VENV}/bin/pip" install --upgrade pip wheel setuptools
  "${J_VENV}/bin/pip" install jupyterlab==4.2.5 notebook==7.2.2
fi

echo "[start] JupyterLab :${J_PORT} root=${J_DIR}"
nohup "${J_VENV}/bin/jupyter" lab \
  --ServerApp.ip=0.0.0.0 \
  --ServerApp.port="${J_PORT}" \
  --ServerApp.port_retries=0 \
  --ServerApp.root_dir="${J_DIR}" \
  --ServerApp.token="${J_TOK}" \
  --ServerApp.allow_origin="*" \
  --ServerApp.allow_remote_access=True \
  --no-browser --allow-root \
  >"${DATA_DIR}/jupyter.log" 2>&1 &

# ----------------- A1111 -------------------
echo "[start] A1111 WebUI :${PORT}"
nohup python3 /opt/webui/launch.py \
  --data-dir "${DATA_DIR}" \
  --enable-insecure-extension-access \
  ${WEBUI_ARGS} \
  --port "${PORT}" \
  >"${DATA_DIR}/webui.log" 2>&1 &

echo "[tail] ${DATA_DIR}/webui.log"
tail -n +1 -f "${DATA_DIR}/webui.log"
