# Template 2 — A1111 + File Browser + JupyterLab

Runs **Automatic1111 Stable Diffusion WebUI** plus extras: File Browser + JupyterLab.  
Designed for easier file management and interactive workflows.

---

## Features
- A1111 on **port 7860**
- File Browser on **port 8080**
- JupyterLab on **port 8888**
- Health shim on **port 3000**
- Log files: `/workspace/filebrowser.log`, `/workspace/jupyter.log`

---

## Docker Hub Image
docker.io/freeradical16/stable-diffusion-a1111:t2-tools

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
WEBUI_ARGS=--listen --port 7860 --api  

Adds for File Browser:
ENABLE_FILEBROWSER=true  
FILEBROWSER_PORT=8080  
FILEBROWSER_NOAUTH=true  

Adds for Jupyter:
ENABLE_JUPYTER=true  
JUPYTER_PORT=8888  
JUPYTER_DIR=/workspace  
JUPYTER_TOKEN=  

### Volumes
- Leave blank → ephemeral (data wiped on *Terminate*).  
- Attach a **named volume** at `/workspace` → persistence for models, extensions, notebooks, outputs.

---

## Notes
- Default SD 1.5 model (`v1-5-pruned-emaonly`) will auto-download if no model is present.  
- Place your own models in `/workspace/a1111-data/models/Stable-diffusion` for persistence.  
- JupyterLab and File Browser are optional and controlled via env vars.
