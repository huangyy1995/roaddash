#!/bin/bash
# ============================================================
# Deploy Road Dash to GCP Cloud Run
# Prerequisites: gcloud CLI installed and authenticated
# ============================================================

set -euo pipefail

# Configuration — change these to match your GCP setup
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${GCP_REGION:-asia-east1}"
SERVICE_NAME="road-dash"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "============================================"
echo "  Road Dash — GCP Cloud Run Deployment"
echo "============================================"
echo "Project:  ${PROJECT_ID}"
echo "Region:   ${REGION}"
echo "Service:  ${SERVICE_NAME}"
echo "Image:    ${IMAGE_NAME}"
echo "============================================"
echo ""

# Step 1: Build Docker image
echo ">>> Building Docker image..."
docker build -t "${IMAGE_NAME}" .

# Step 2: Push to GCR
echo ">>> Pushing image to Google Container Registry..."
docker push "${IMAGE_NAME}"

# Step 3: Deploy to Cloud Run
echo ">>> Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
  --image "${IMAGE_NAME}" \
  --platform managed \
  --region "${REGION}" \
  --port 8080 \
  --allow-unauthenticated \
  --memory 256Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 3 \
  --timeout 300

echo ""
echo "============================================"
echo "  Deployment complete!"
echo "============================================"
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
  --region "${REGION}" --format 'value(status.url)' 2>/dev/null || echo "")
if [ -n "${SERVICE_URL}" ]; then
  echo "  URL: ${SERVICE_URL}"
  echo ""
  echo "  Open this URL on your phone to play!"
fi
echo "============================================"
