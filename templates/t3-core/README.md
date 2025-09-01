# Template 3 — A1111 + File Browser + JupyterLab + Core Extensions (+recommended assets)

Template 2 plus core extensions and first-run download of recommended files:

- Extensions:
  - ADetailer
  - ControlNet
  - Ultimate SD Upscale
  - Images Browser
- Upscalers (to models/ESRGAN):
  - 4x-UltraSharp.pth (Hugging Face)
  - RealESRGAN_x4plus.pth (official release)
  - RealESRGAN_x4plus_anime_6B.pth (official release)
- ADetailer YOLO (to models/ADetailer):
  - face_yolov9c.pt
  - hand_yolov8n.pt
  - person_yolov8n-seg.pt
- ControlNet SD 1.5 basics (to models/ControlNet):
  - control_v11p_sd15_canny.pth
  - control_v11f1p_sd15_depth.pth
  - control_v11p_sd15_openpose.pth

First boot downloads the files above into ${DATA_DIR} and reuses them on subsequent runs.

-------------------------------------------------------------------------------

## Docker Hub Image

docker.io/freeradical16/stable-diffusion-a1111:t3-core

-------------------------------------------------------------------------------

## Features

- A1111 on 7860 (fallback to 7861 if busy)
- File Browser on 8080
- JupyterLab on 8888
- Health shim on 3000
- Logs in ${DATA_DIR}/*.log

-------------------------------------------------------------------------------

## RunPod Setup

### Ports

7860
3000
8080
8888

### Environment Variables

Required:
DATA_DIR=/workspace/a1111-data
WEBUI_ARGS=--listen --api

Recommended caches:
PIP_CACHE_DIR=/workspace/.cache/pip
HF_HOME=/workspace/.cache/huggingface
TORCH_HOME=/workspace/.cache/torch
PYTHONWARNINGS=ignore::FutureWarning,ignore::UserWarning

Tools:
ENABLE_FILEBROWSER=true
FILEBROWSER_PORT=8080
FILEBROWSER_NOAUTH=true
ENABLE_JUPYTER=true
JUPYTER_PORT=8888
JUPYTER_DIR=/workspace
JUPYTER_TOKEN=

### Volumes

- Leave blank → ephemeral (wiped on Terminate).
- Attach a named volume at /workspace → persistence.

At runtime, A1111 uses folders under ${DATA_DIR} inside the container:
- ${DATA_DIR}/models/Stable-diffusion
- ${DATA_DIR}/models/ControlNet
- ${DATA_DIR}/models/ESRGAN
- ${DATA_DIR}/models/ADetailer
- ${DATA_DIR}/extensions
- ${DATA_DIR}/outputs

-------------------------------------------------------------------------------

## Notes

- Default SD 1.5 checkpoint will auto-download if none present.
- ControlNet SD 1.5 (canny, depth, openpose) is included by default and stored in ${DATA_DIR}/models/ControlNet.
- You can add additional ControlNet (e.g., SDXL) models by dropping them into ${DATA_DIR}/models/ControlNet.
- Upscalers & ADetailer YOLO are downloaded once on first start and reused thereafter.
