# Template 1 — Bare A1111

Runs **Automatic1111 Stable Diffusion WebUI** only.  
Works **with or without** a persistent volume.

---

## Features
- A1111 on **port 7860** (auto-fallback to **7861** if 7860 is busy)
- Health shim on **port 3000** (returns 503 until A1111 is ready, then 200)
- Log file: `/opt/webui/webui.log`
- Torch 2.4.0 + xFormers 0.0.27.post2 (CUDA 12.1)

---

## Docker Hub Image
docker.io/freeradical16/stable-diffusion-a1111:t1-bare

---

## RunPod Setup

### Ports
7860  
3000  

### Environment Variables
DATA_DIR=/workspace/a1111-data  
WEBUI_ARGS=--listen --api  

### Volumes
- Leave blank → ephemeral (data wiped on *Terminate*).  
- Attach a **named volume** at `/workspace` → persistence.

---

## Notes
- Default SD 1.5 model (`v1-5-pruned-emaonly`) will auto-download if no model is present.  
- Runtime data lives under `${DATA_DIR}` inside the container:
  - `${DATA_DIR}/models/Stable-diffusion`
  - `${DATA_DIR}/extensions`
  - `${DATA_DIR}/outputs`
