# -----------------------------------------------------------------------------
# Template 2: A1111 + File Browser + JupyterLab
# - A1111 on 7860 (+ health shim 3000)
# - File Browser on 8080 (no auth by default; can enable with env)
# - JupyterLab on 8888 (no token by default; can set via env)
# - Works with or without a mounted /workspace volume
# -----------------------------------------------------------------------------

FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TZ=UTC \
    TINI_SUBREAPER=1

# Versions (pin what we can)
ARG FILEBROWSER_VERSION=2.28.0

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates tini \
    python3 python3-venv python3-pip \
    libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

# -------------------------
# A1111 code
# -------------------------
WORKDIR /opt/webui
ARG A1111_REPO=https://github.com/AUTOMATIC1111/stable-diffusion-webui
RUN git clone --depth=1 ${A1111_REPO} .

# -------------------------
# Python venv + Torch + xFormers + JupyterLab
# -------------------------
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
RUN pip install --upgrade pip wheel setuptools && \
    pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cu121 \
        torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 && \
    pip install --no-cache-dir xformers==0.0.27.post2 && \
    pip install --no-cache-dir jupyterlab==4.2.5 notebook==7.2.2 && \
    pip install --no-cache-dir safetensors opencv-python-headless==4.10.0.84 \
               accelerate transformers timm einops requests psutil Pillow==9.5.0 && \
    pip cache purge

# -------------------------
# File Browser (single binary)
# -------------------------
RUN curl -L -o /usr/local/bin/filebrowser \
      "https://github.com/filebrowser/filebrowser/releases/download/v${FILEBROWSER_VERSION}/linux-amd64-filebrowser" \
 && chmod +x /usr/local/bin/filebrowser

# Startup
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Ports
EXPOSE 7860 3000 8080 8888

# Defaults & toggles
ENV DATA_DIR="/workspace/a1111-data" \
    WEBUI_ARGS="--listen --port 7860 --api" \
    PYTHONWARNINGS="" \
    ENABLE_FILEBROWSER="true" \
    ENABLE_JUPYTER="true" \
    FILEBROWSER_PORT="8080" \
    FILEBROWSER_NOAUTH="true" \
    JUPYTER_PORT="8888" \
    JUPYTER_TOKEN="" \
    JUPYTER_DIR="/workspace"

# Optional caches (set at runtime in RunPod env if desired)
# ENV PIP_CACHE_DIR=/workspace/.cache/pip
# ENV HF_HOME=/workspace/.cache/huggingface
# ENV TORCH_HOME=/workspace/.cache/torch

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini","-s","--"]
CMD ["/usr/local/bin/start.sh"]
