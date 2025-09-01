# Template 2: A1111 + File Browser (Jupyter installed on volume at runtime)

FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TZ=UTC \
    TINI_SUBREAPER=1

# System deps (+ iproute2 so `ss` exists)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates tini \
    python3 python3-venv python3-pip \
    libgl1 libglib2.0-0 iproute2 \
 && rm -rf /var/lib/apt/lists/*

# A1111
WORKDIR /opt/webui
ARG A1111_REPO=https://github.com/AUTOMATIC1111/stable-diffusion-webui
RUN git clone --depth=1 ${A1111_REPO} .

# Python venv for A1111 (no Jupyter here)
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
RUN pip install --upgrade pip wheel setuptools && \
    pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cu121 \
        torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 && \
    pip install --no-cache-dir xformers==0.0.27.post2 && \
    pip install --no-cache-dir safetensors opencv-python-headless==4.10.0.84 \
               accelerate transformers timm einops requests psutil Pillow==9.5.0 && \
    pip cache purge

# File Browser (official installer picks the right binary)
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# Startup
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 7860 3000 8080 8888

ENV DATA_DIR="/workspace/a1111-data" \
    WEBUI_ARGS="--listen --port 7860 --api" \
    PYTHONWARNINGS="" \
    ENABLE_FILEBROWSER="true" \
    FILEBROWSER_PORT="8080" \
    FILEBROWSER_NOAUTH="true" \
    ENABLE_JUPYTER="true" \
    JUPYTER_PORT="8888" \
    JUPYTER_TOKEN="" \
    JUPYTER_DIR="/workspace"

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini","-s","--"]
CMD ["/usr/local/bin/start.sh"]
