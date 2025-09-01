# GitHub Actions Workflows

This repo has two workflows that automatically build and push Docker images to Docker Hub.

---

## Workflows

### build-t1.yml
- **Template:** [`templates/t1-bare`](../../templates/t1-bare)  
- **Image tag pushed:** `t1-bare`  
- **Trigger:**  
  - On push to `main` branch if files under `templates/t1-bare/` or `.github/workflows/build-t1.yml` change  
  - Manual trigger via **workflow_dispatch**

### build-t2.yml
- **Template:** [`templates/t2-tools`](../../templates/t2-tools)  
- **Image tag pushed:** `t2-tools`  
- **Trigger:**  
  - On push to `main` branch if files under `templates/t2-tools/` or `.github/workflows/build-t2.yml` change  
  - Manual trigger via **workflow_dispatch**

---

## Tags Published

Both workflows push a **single rolling tag** under your Docker Hub namespace:

- `docker.io/<DOCKERHUB_USERNAME>/stable-diffusion-a1111:t1-bare`
- `docker.io/<DOCKERHUB_USERNAME>/stable-diffusion-a1111:t2-tools`

No SHA digests or version tags are retained (keeps your repo small and clean).

---

## Secrets Required

Both workflows require the following GitHub secrets to be set:

- `DOCKERHUB_USERNAME` → your Docker Hub username  
- `DOCKERHUB_TOKEN` → a Docker Hub **access token** with `write:push` permissions

---

## How to Trigger

1. **Automatic:** Push commits to `main` that touch the relevant template folder.  
2. **Manual:** Go to the **Actions** tab in GitHub → select the workflow → **Run workflow**.

---

## Build Notes

- Builds are limited to `linux/amd64` (works on NVIDIA GPUs on RunPod).  
- Buildx cache is enabled for faster rebuilds.  
- `provenance` and `sbom` uploads are disabled to prevent Docker Hub 400 errors.
