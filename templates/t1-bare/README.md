# Template 1 — Bare A1111

Runs **Automatic1111 Stable Diffusion WebUI** only.  
Works **with or without** a persistent volume.

---

## Features
- A1111 on **port 7860** (auto-fallback to **7861** if 7860 is busy)
- Health shim on **port 3000** (returns 503 until A1111 is truly ready, then 200)
- Log file: `/opt/webui/webui.log`
- Torch 2.4.0 + xFormers 0.0.27.post2 (CUDA 12.1)

---

## Ports to expose (RunPod)
- `7860` → A1111 WebUI  
- `3000` → Health endpoint (HTTP)

> In RunPod, set the readiness/health probe to **HTTP on port 3000** (path `/`).  
> Alternative: set probe type to **TCP** on port `7860`.

---

## Environment Variables (RunPod → Template → Env)

```env
# --- Required ---
DATA_DIR=/workspace/a1111-data
WEBUI_ARGS=--listen --port 7860 --api

# --- Optional ---
# Recommended if you mount /workspace to persist caches and suppress warnings
PIP_CACHE_DIR=/workspace/.cache/pip
HF_HOME=/workspace/.cache/huggingface
TORCH_HOME=/workspace/.cache/torch
PYTHONWARNINGS=ignore::FutureWarning,ignore::UserWarning
