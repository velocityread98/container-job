#!/bin/bash

# Azure Container Apps Deployment Script
# This script builds, tags, and deploys a FastAPI backend to Azure Container Apps

set -e  # Exit on any error

echo "🚀 Starting Azure Container Apps deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="vrdevjob"
IMAGE_TAG="0.1"
ACR_NAME="vrdevregistry"
ACR_REPO="vrdevjobimg"
ACR_IMAGE="${ACR_NAME}.azurecr.io/${ACR_REPO}:${IMAGE_TAG}"
RESOURCE_GROUP="vrdevrg"
ENVIRONMENT="vrdevrgenv"
JOB_NAME="dolphin-pdf-processing-job"

INPUT_PATH_ARG="ninad/test/file.pdf"  # Optional: Set input path for the job, or leave empty

echo -e "${YELLOW}📋 Configuration:${NC}"
echo "  Image Name: $IMAGE_NAME"
echo "  Image Tag: $IMAGE_TAG"
echo "  ACR Name: $ACR_NAME"
echo "  ACR Repository: $ACR_REPO"
echo "  ACR Image: $ACR_IMAGE"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Environment: $ENVIRONMENT"
echo "  Job Name: $JOB_NAME"
if [ -n "$INPUT_PATH_ARG" ]; then
	echo "  Input Path: $INPUT_PATH_ARG"
fi
echo ""

# Step 1: Login to Azure
echo -e "${YELLOW}🔐 Logging into Azure...${NC}"
az login

# Step 2: Login to Azure Container Registry
echo -e "${YELLOW}🔐 Logging into Azure Container Registry...${NC}"
az acr login --name $ACR_NAME

# Step 3: Clean up existing images (optional)
echo -e "${YELLOW}🧹 Cleaning up existing images...${NC}"
echo "  Removing local Docker images..."
docker rmi $IMAGE_NAME 2>/dev/null || echo "  Local image $IMAGE_NAME not found (OK)"
docker rmi $ACR_IMAGE 2>/dev/null || echo "  Local ACR image not found (OK)"

echo "  Removing image from Azure Container Registry..."
az acr repository delete --name $ACR_NAME --image ${ACR_REPO}:${IMAGE_TAG} --yes 2>/dev/null || echo "  ACR image not found (OK)"

# Step 4: Build new image (Dockerfile and app are in container_app_job/app)
echo -e "${YELLOW}🏗️  Building Docker image...${NC}"
docker build --platform linux/amd64 -t $IMAGE_NAME .

# Step 5: Tag image for ACR
echo -e "${YELLOW}🏷️  Tagging image for ACR...${NC}"
docker tag $IMAGE_NAME $ACR_IMAGE

# Step 6: Push image to ACR
echo -e "${YELLOW}📤 Pushing image to Azure Container Registry...${NC}"
docker push $ACR_IMAGE

# Step 7: Delete existing Container Apps Job (optional)
echo -e "${YELLOW}🗑️  Deleting existing Container Apps Job...${NC}"
if az containerapp job show --name $JOB_NAME --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
		echo "  Job $JOB_NAME exists, deleting..."
		az containerapp job delete \
			--name $JOB_NAME \
			--resource-group $RESOURCE_GROUP \
			--yes
		echo "  Job $JOB_NAME deleted successfully"
else
		echo "  Job $JOB_NAME not found (OK)"
fi

# Step 8: Create Azure Container Apps Job
echo -e "${YELLOW}🚀 Creating Container Apps Job...${NC}"
az containerapp job create \
	--name $JOB_NAME \
	--resource-group $RESOURCE_GROUP \
	--environment $ENVIRONMENT \
	--image $ACR_IMAGE \
	--registry-server ${ACR_NAME}.azurecr.io \
	--cpu 0.5 \
	--memory 1.0Gi \
	--trigger-type Manual \
	--replica-timeout 1800 \
	--replica-retry-limit 3 \
	--replica-completion-count 1 \
	--parallelism 1 \

# If an input path is provided, set it as an env var for this job definition
if [ -n "$INPUT_PATH_ARG" ]; then
  echo -e "${YELLOW}⚙️  Setting INPUT_PATH on job...${NC}"
  az containerapp job update \
    --name $JOB_NAME \
    --resource-group $RESOURCE_GROUP \
    --set-env-vars INPUT_PATH="$INPUT_PATH_ARG"
fi

# # Optional: Configure secrets and reference them as env vars (recommended)
# # az containerapp job secret set \
# #   --name $JOB_NAME \
# #   --resource-group $RESOURCE_GROUP \
# #   --secrets BETTERSTACK_TOKEN=REPLACE_ME BETTERSTACK_INGEST_URL=REPLACE_ME
# # az containerapp job update \
# #   --name $JOB_NAME \
# #   --resource-group $RESOURCE_GROUP \
# #   --set-env-vars BETTERSTACK_TOKEN=secretref:BETTERSTACK_TOKEN BETTERSTACK_INGEST_URL=secretref:BETTERSTACK_INGEST_URL

# Step 9: Start a one-off execution (manual trigger)
echo -e "${YELLOW}▶️  Starting job execution...${NC}"
az containerapp job start \
	--name $JOB_NAME \
	--resource-group $RESOURCE_GROUP


echo -e "${GREEN}🎉 Done!"
