#!/usr/bin/env bash
# Build/push the Python API to the stack ECR repo (from a laptop with internet).
# Tasks pull via PrivateLink — there is no NAT in this VPC.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_REGION:-us-east-1}"
REPO_URL="$(terraform -chdir="$ROOT" output -raw ecr_repository_url)"
TAG="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M)"
IMAGE="${REPO_URL}:${TAG}"

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${REPO_URL%%/*}"

docker build -t "$IMAGE" "$ROOT/app"
docker push "$IMAGE"

echo "Pushed $IMAGE"
echo "Set in terraform.tfvars:"
echo "  container_image = \"$IMAGE\""
echo "  desired_count   = 2"
echo "Then: terraform apply"
