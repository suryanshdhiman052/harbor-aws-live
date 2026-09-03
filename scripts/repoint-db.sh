#!/usr/bin/env bash
# After restoring RDS to a NEW identifier, repoint Cloud Map to the new endpoint.
# Does not rewrite the ECS task definition (DB_HOST stays postgres.<ns>.local).
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
SERVICE_ID="${SERVICE_ID:?set SERVICE_ID from: terraform output -raw discovery_service_id}"
NEW_HOST="${NEW_HOST:?set NEW_HOST to restored instance Endpoint.Address}"
CLUSTER="${CLUSTER:-harbor-live}"
SERVICE="${SERVICE:-harbor-live-api}"

aws servicediscovery register-instance \
  --region "$REGION" \
  --service-id "$SERVICE_ID" \
  --instance-id primary \
  --attributes "AWS_INSTANCE_CNAME=${NEW_HOST},AWS_INSTANCE_WEIGHT=1"

# Process DNS caches still need new tasks.
aws ecs update-service \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --force-new-deployment

echo "Cloud Map CNAME -> ${NEW_HOST}; forced new ECS deployment."
