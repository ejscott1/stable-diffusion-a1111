# Template 2 — A1111 + File Browser + JupyterLab

Runs **Automatic1111 WebUI** (A1111) plus:
- **File Browser** on port **8080** (no auth by default; toggle via env)
- **JupyterLab** on port **8888** (no token by default; set via env)

Works **with or without** a persistent volume.

---

## Features
- A1111 on **7860** (auto-fallback to **7861** if busy)
- Health shim on **3000** (returns 503 until A1111 is truly ready)
- File Browser on **8080**
- JupyterLab on **8888**
- Logs: `/opt/webui/webui.log`, `/workspace/filebrowser.log`, `/workspace/jupyter.log`

---

## Ports to expose (RunPod)
- `7860` → A1111  
- `3000` → Health endpoint (HTTP)  
- `8080` → File Browser  
- `8888` → JupyterLab

> In RunPod, set the readiness/health probe to **HTTP on port 3000** (path `/`).  

---

## Environment Variables (RunPod → Template → Env)

```env
# --- Required ---
DATA_DIR=/workspace/a1111-data
WEBUI_ARGS=--listen --port 7860 --api

# --- Optional (A1111 caches & warnings) ---
PIP_CACHE_DIR=/workspace/.cache/pip
HF_HOME=/workspace/.cache/huggingface
TORCH_HOME=/workspace/.cache/torch
PYTHONWARNINGS=ignore::FutureWarning,ignore::UserWarning

# --- Optional (File Browser) ---
ENABLE_FILEBROWSER=true         # set false to disable
FILEBROWSER_PORT=8080
FILEBROWSER_NOAUTH=true         # set false to enforce login (you can create users via filebrowser db)

# --- Optional (JupyterLab) ---
ENABLE_JUPYTER=true             # set false to disable
JUPYTER_PORT=8888
JUPYTER_DIR=/workspace
JUPYTER_TOKEN=                  # empty = no token; set a value to require it
