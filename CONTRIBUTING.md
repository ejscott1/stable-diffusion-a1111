# Contributing Guide

Thanks for helping improve **Stable Diffusion A1111 on RunPod**!  
This document explains how to add/modify templates, test locally, and ship images via GitHub Actions.

---

## Prerequisites
- Docker (with Buildx)
- Docker Hub account (for publishing images)
- Git + GitHub repo access
- (Optional) NVIDIA GPU for local tests

---

## Repository Layout
.
├─ templates/
│  ├─ t1-bare/        # Minimal A1111
│  │  ├─ Dockerfile
│  │  ├─ start.sh
│  │  └─ README.md
│  └─ t2-tools/       # A1111 + File Browser + Jupyter
│     ├─ Dockerfile
│     ├─ start.sh
│     └─ README.md
├─ .github/workflows/
│  ├─ build-t1.yml
│  ├─ build-t2.yml
│  └─ README.md
├─ .dockerignore
└─ README.md

---

## Adding a New Template (example: `t3-extras`)
1) Create the folder  
   mkdir -p templates/t3-extras

2) Add files  
   templates/t3-extras/Dockerfile  
   templates/t3-extras/start.sh  
   templates/t3-extras/README.md

3) Create a workflow  
   Copy an existing workflow to `.github/workflows/build-t3.yml` and update:
   - context: templates/t3-extras
   - file: templates/t3-extras/Dockerfile
   - tag: t3-extras

4) Commit & push → open PR to `main`

---

## Dockerfile Checklist (per template)
- Base (CUDA runtime):  
  nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04
- Essentials:
  apt-get install -y --no-install-recommends \
    git curl ca-certificates tini \
    python3 python3-venv python3-pip \
    libgl1 libglib2.0-0 iproute2 unzip
- Python venv and PATH:  
  python3 -m venv /opt/venv  
  ENV PATH="/opt/venv/bin:${PATH}"
- Torch/xFormers (CUDA 12.1 pins):  
  pip install --index-url https://download.pytorch.org/whl/cu121 \
    torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0  
  pip install xformers==0.0.27.post2
- Clone A1111 into /opt/webui (don’t run webui.sh at build time)
- Copy launcher:  
  COPY start.sh /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh
- Expose ports used by the template
- Minimal defaults:
  ENV DATA_DIR="/workspace/a1111-data" \
      WEBUI_ARGS="--listen --api" \
      PYTHONWARNINGS=""
- Entry:  
  ENTRYPOINT ["/usr/bin/tini","-s","--"]  
  CMD ["/usr/local/bin/start.sh"]

---

## `start.sh` Contract
- Launch A1111 via `launch.py` (not `webui.sh`):
  python3 /opt/webui/launch.py --data-dir "${DATA_DIR}" ${WEBUI_ARGS} --port "${PORT}"
- Create required dirs under `${DATA_DIR}`:
  - models/Stable-diffusion
  - models/ControlNet
  - extensions
  - outputs
- Port logic:
  - Default `PORT=7860`, fallback to `7861` if busy (use `ss` to detect)
- Health shim:
  - Tiny HTTP server on `:3000`
  - Returns 503 until `http://127.0.0.1:${PORT}` responds, then 200
- Logs:
  - Write logs under `${DATA_DIR}` (always writable)
- Optional caches: if envs exist, create them
  - PIP_CACHE_DIR, HF_HOME, TORCH_HOME

---

## Ports & Environment Variables
- Typical ports:
  - 7860 → A1111
  - 3000 → health shim
  - 8080 → File Browser (if included)
  - 8888 → JupyterLab (if included)

- Required env (common):
  DATA_DIR=/workspace/a1111-data  
  WEBUI_ARGS=--listen --api

- Optional caches:
  PIP_CACHE_DIR=/workspace/.cache/pip  
  HF_HOME=/workspace/.cache/huggingface  
  TORCH_HOME=/workspace/.cache/torch  
  PYTHONWARNINGS=ignore::FutureWarning,ignore::UserWarning

- Tools (if included):
  ENABLE_FILEBROWSER=true  
  FILEBROWSER_PORT=8080  
  FILEBROWSER_NOAUTH=true  

  ENABLE_JUPYTER=true  
  JUPYTER_PORT=8888  
  JUPYTER_DIR=/workspace  
  JUPYTER_TOKEN=

> Do **not** bake `--port` into `WEBUI_ARGS`; the launcher sets `--port ${PORT}`.

---

## Local Build & Smoke Test
docker build -t local-t1:dev templates/t1-bare
docker run --rm -it --gpus all \
  -p 7860:7860 -p 3000:3000 \
  -e DATA_DIR=/data \
  -v "$(pwd)/_data":/data \
  local-t1:dev

# In another shell (readiness flips 503 → 200)
curl -I http://127.0.0.1:3000

---

## CI/CD (GitHub Actions)
Each template has a workflow that:
- builds from `templates/<name>`
- pushes a **single rolling tag** to Docker Hub (no SHA tags)
- sets `platforms: linux/amd64`
- uses Buildx cache; disables provenance/SBOM (avoids Hub 400s)

### Workflow skeleton
name: Build & Push (<TEMPLATE_TAG>)
on:
  push:
    branches: [ main ]
    paths:
      - 'templates/<folder>/**'
      - '.github/workflows/build-<template>.yml'
  workflow_dispatch:
concurrency:
  group: <template>-${{ github.ref }}
  cancel-in-progress: true
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: docker.io
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          context: templates/<folder>
          file: templates/<folder>/Dockerfile
          push: true
          tags: docker.io/${{ secrets.DOCKERHUB_USERNAME }}/stable-diffusion-a1111:<TEMPLATE_TAG>
          platforms: linux/amd64
          provenance: false
          sbom: false
          cache-from: type=gha
          cache-to: type=gha,mode=max

### Secrets required
DOCKERHUB_USERNAME  
DOCKERHUB_TOKEN  (Docker Hub access token with push permissions)

---

## Troubleshooting
- WebUI “squished” layout → don’t install Jupyter into `/opt/venv`; isolate it to `/workspace/jupyter-venv`.
- “Bad Gateway” on a port → confirm port exposed + service started; check `${DATA_DIR}/*.log` and `ss -lntp`.
- Pod never becomes “Ready” → health shim must probe the **actual** A1111 port (7860 or fallback).
- `webui.sh` aborts → always use `launch.py`.
- Env values must be plain (no inline `# comments`).

---

## Style Tips
- Keep images lean; pin CUDA/Torch/xFormers versions.
- Log to `${DATA_DIR}`; it’s always writable.
- Use `tini` as PID 1.
- Prefer `set -euo pipefail` in bash (mind pipelines).
- Document ports/envs in each template README (single-block format for easy copy).

---

## Releasing
- Merge to `main` → workflow auto-builds and pushes the tag.
- To force a build without code changes → run the workflow manually (workflow_dispatch).
````0
