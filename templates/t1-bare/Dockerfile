# -----------------------------------------------------------------------------
# Template 1: Bare Automatic1111 (A1111)
# - Minimal base image with CUDA 12.1 runtime
# - Installs A1111 + Torch stack + xFormers
# - Exposes A1111 (7860) + health shim (3000)
# - Works with or without a mounted /workspace volume
# -----------------------------------------------------------------------------

FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TZ=UTC \
    TINI_SUBREAPER=1

# System dependencies (minimal)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates tini \
    python3 python3-venv python3-pip \
    libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Clone Automatic1111
# -----------------------------------------------------------------------------
WORKDIR /opt/webui
ARG A1111_REPO=https://github.com/AUTOMATIC1111/stable-diffusion-webui
RUN git clone --depth=1 ${A1111_REPO} .

# -----------------------------------------------------------------------------
# Python venv + Torch + xFormers stack
# -----------------------------------------------------------------------------
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
RUN pip install --upgrade pip wheel setuptools && \
    pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cu121 \
        torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 && \
    pip install --no-cache-dir xformers==0.0.27.post2 && \
    pip install --no-cache-dir safetensors opencv-python-headless==4.10.0.84 \
               accelerate transformers timm einops requests psutil Pillow==9.5.0 && \
    pip cache purge

# -----------------------------------------------------------------------------
# Startup script
# -----------------------------------------------------------------------------
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh   # <--- ensures script is executable

# -----------------------------------------------------------------------------
# Expose A1111 + health shim
# -----------------------------------------------------------------------------
EXPOSE 7860 3000

# -----------------------------------------------------------------------------
# Defaults (works with or without mounted /workspace volume)
# -----------------------------------------------------------------------------
ENV DATA_DIR="/workspace/a1111-data" \
    WEBUI_ARGS="--listen --port 7860 --api" \
    PYTHONWARNINGS=""

# Optional caches (commented out; define in RunPod env if desired)
# ENV PIP_CACHE_DIR=/workspace/.cache/pip
# ENV HF_HOME=/workspace/.cache/huggingface
# ENV TORCH_HOME=/workspace/.cache/torch

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini","-s","--"]
CMD ["/usr/local/bin/start.sh"]
