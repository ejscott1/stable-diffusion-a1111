# Minimal A1111 + Jupyter image (no extras). You install models/extensions on the volume.

FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TZ=UTC

# Base deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates \
    python3 python3-venv python3-pip \
    libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

# A1111 in /opt/webui
WORKDIR /opt
RUN git clone --depth=1 https://github.com/AUTOMATIC1111/stable-diffusion-webui.git webui

# Python venv for A1111
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Torch/cuDNN (CUDA 12.1) + minimal deps. Keep it slim; you’ll add extras later in the volume.
RUN pip install --upgrade pip wheel setuptools && \
    pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cu121 \
        torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 && \
    pip install --no-cache-dir xformers==0.0.27.post2 && \
    pip install --no-cache-dir safetensors Pillow==9.5.0 requests

# Startup script
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Nicety for docs / port mapping (RunPod maps anyway)
EXPOSE 7860 8888

# Volume workdir
WORKDIR /workspace

CMD ["/usr/local/bin/start.sh"]
