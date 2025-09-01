# Template 3 — A1111 + File Browser + JupyterLab + Core Extensions

Template 2 plus **core extensions** (enabled by default):
- **ADetailer**
- **ControlNet**
- **Ultimate SD Upscale**
- **Images Browser**

Extensions are installed at runtime into `${DATA_DIR}/extensions` (persistent volume),
and symlinked into `/opt/webui/extensions` so A1111 can see them.

---

## Docker Hub Image
docker.io/freeradical16/stable-diffusion-a1111:t3-core

---

## Features
- A1111 on **7860** (fallback to **7861** if busy)
- File Browser on **8080**
- JupyterLab on **8888**
- Health shim on **3000**
- Logs in `${DATA_DIR}/*.log`

---

## RunPod Setup

### Ports
7860  
3000  
8080  
8888  

### Environment Variables

Required:
DATA_DIR=/workspace/a1111-data  
WEBUI_ARGS=--listen --api  

(Recommended caches:)
PIP_CACHE_DIR=/workspace/.cache/pip  
HF_HOME=/workspace/.cache/huggingface  
TORCH_HOME=/workspace/.cache/torch  
PYTHONWARNINGS=ignore::FutureWarning,ignore::UserWarning  

Tools:
ENABLE_FILEBROWSER=true  
FILEBROWSER_PORT=8080  
FILEBROWSER_NOAUTH=true  

ENABLE_JUPYTER=true  
JUPYTER_PORT=8888  
JUPYTER_DIR=/workspace  
JUPYTER_TOKEN=  

Core extensions (all default to true):
ENABLE_EXTENSIONS_CORE=true  
ENABLE_EXT_ADETAILER=true  
ENABLE_EXT_CONTROLNET=true  
ENABLE_EXT_ULTUPSCALE=true  
ENABLE_EXT_IMAGES_BROWSER=true  

### Volumes
- Leave blank → ephemeral (wiped on *Terminate*).  
- Attach a **named volume** at `/workspace` → persistence.  

At runtime, A1111 uses folders under `${DATA_DIR}` inside the container:
- `${DATA_DIR}/models/Stable-diffusion`
- `${DATA_DIR}/extensions`
- `${DATA_DIR}/outputs`

---

## Notes
- Default SD 1.5 model (`v1-5-pruned-emaonly`) auto-downloads if none present.  
- Place your own checkpoints in `${DATA_DIR}/models/Stable-diffusion` for faster startup.  
- Disable any extension by setting its `ENABLE_EXT_*` to `false`.
