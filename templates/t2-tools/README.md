# Template 2 — A1111 + File Browser + JupyterLab

Runs **Automatic1111 WebUI** (A1111) plus:
- **File Browser** on port **8080**  
- **JupyterLab** on port **8888**

---

## Features
- A1111 on **7860** (auto-fallback to **7861** if busy)
- Health shim on **3000** (returns 503 until A1111 is ready, then 200)
- File Browser on **8080**
- JupyterLab on **8888**

---

## Ports to expose (RunPod)
- `7860` → A1111  
- `3000` → Health endpoint  
- `8080` → File Browser  
- `8888` → JupyterLab  

---

## Environment Variables

```env
DATA_DIR=/workspace/a1111-data
WEBUI_ARGS=--listen --port 7860 --api

PIP_CACHE_DIR=/workspace/.cache/pip
HF_HOME=/workspace/.cache/huggingface
TORCH_HOME=/workspace/.cache/torch
PYTHONWARNINGS=ignore::FutureWarning,ignore::UserWarning

ENABLE_FILEBROWSER=true
FILEBROWSER_PORT=8080
FILEBROWSER_NOAUTH=true

ENABLE_JUPYTER=true
JUPYTER_PORT=8888
JUPYTER_DIR=/workspace
JUPYTER_TOKEN=
