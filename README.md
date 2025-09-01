# Stable Diffusion A1111 on RunPod

This repo provides Docker templates for running **Automatic1111 Stable Diffusion WebUI** on [RunPod](https://www.runpod.io).  
Templates are built via GitHub Actions and pushed to Docker Hub.

---

## Templates

### Template 1 — Bare A1111
- Runs Automatic1111 only
- Minimal image, fastest to build
- Works with or without a persistent volume
- Use when you just need the WebUI

```
docker.io/freeradical16/stable-diffusion-a1111:t1-bare
```

---

### Template 2 — A1111 + File Browser + JupyterLab
- A1111 on port 7860  
- File Browser on port 8080  
- JupyterLab on port 8888  
- Health shim on 3000 (used by RunPod for readiness)

```
docker.io/freeradical16/stable-diffusion-a1111:t2-tools
```

---

## RunPod Setup

### Ports to expose
```
7860
3000
8080
8888
```

### Environment variables

Both templates require:
```
DATA_DIR=/workspace/a1111-data
WEBUI_ARGS=--listen --api
```

Template 2 adds:
```
ENABLE_FILEBROWSER=true
FILEBROWSER_PORT=8080
FILEBROWSER_NOAUTH=true

ENABLE_JUPYTER=true
JUPYTER_PORT=8888
JUPYTER_DIR=/workspace
JUPYTER_TOKEN=
```

### Volumes
- Leave blank → ephemeral (data wiped on *Terminate*).  
- Attach a **named volume** at `/workspace` → persistence.  

At runtime, A1111 will create and use these folders under `${DATA_DIR}` inside the container:
- `${DATA_DIR}/models/Stable-diffusion`
- `${DATA_DIR}/extensions`
- `${DATA_DIR}/outputs`

---

## Build & Push

Each template has its own workflow under `.github/workflows`. On push, GitHub Actions:
1. Builds the Docker image  
2. Tags it (e.g. `t1-bare`, `t2-tools`)  
3. Pushes to Docker Hub  

You can also trigger builds manually with **workflow_dispatch**.

---

## Notes
- Default SD 1.5 model (`v1-5-pruned-emaonly`) will auto-download on first launch if no model is present.  
- For best performance, place your own models in `${DATA_DIR}/models/Stable-diffusion`.  
- Logs are written to:
  - `/opt/webui/webui.log`
  - `${DATA_DIR}/filebrowser.log`
  - `${DATA_DIR}/jupyter.log`
