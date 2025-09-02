# Minimal Stable Diffusion WebUI + Jupyter Template

[![Build & Push (latest)](https://github.com/ejscott1/stable-diffusion-a1111/actions/workflows/build.yml/badge.svg)](https://github.com/ejscott1/stable-diffusion-a1111/actions/workflows/build.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/freeradical16/stable-diffusion-a1111.svg)](https://hub.docker.com/r/freeradical16/stable-diffusion-a1111)
[![Docker Image Version (latest)](https://img.shields.io/docker/v/freeradical16/stable-diffusion-a1111/latest)](https://hub.docker.com/r/freeradical16/stable-diffusion-a1111)

This template builds a lightweight Docker image with only:

- Automatic1111 WebUI  
- JupyterLab  

No models, extensions, or extras are bundled — you install them into the
persistent volume so they survive pod restarts.

---

## Image

docker.io/freeradical16/stable-diffusion-a1111:latest

---

## RunPod Setup

### Ports
- 7860 → WebUI  
- 8888 → Jupyter  

### Environment Variables
DATA_DIR=/workspace/a1111-data  
WEBUI_ARGS=--listen --api  
ENABLE_JUPYTER=true  
JUPYTER_PORT=8888  
JUPYTER_DIR=/workspace  
JUPYTER_TOKEN=  

### Volume
Attach a persistent volume at `/workspace`.

Inside the container, WebUI uses:  
- ${DATA_DIR}/models/Stable-diffusion  
- ${DATA_DIR}/models/Lora  
- ${DATA_DIR}/models/VAE  
- ${DATA_DIR}/extensions  
- ${DATA_DIR}/outputs  

---

## Usage Notes
- First boot will create ${DATA_DIR} and a Jupyter venv if missing.  
- You can install models, LoRAs, and extensions (like WAN) by placing them under
  ${DATA_DIR}. They’ll persist across restarts.  
- Keep this image minimal and stable; extend functionality via your volume.
