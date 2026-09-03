#!/usr/bin/env bash
# Restore single-AZ Postgres after AZ loss. Never terraform-apply snapshot_identifier
# onto the live resource (ForceNew) during the outage.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
SRC="${SRC:-harbor-live-pg}"
DST="${DST:-harbor-live-pg-restored}"
CLASS="${CLASS:-db.t4g.micro}"

FAILED_AZ=$(aws rds describe-db-instances --region "$REGION" \
  --db-instance-identifier "$SRC" \
  --query 'DBInstances[0].AvailabilityZone' --output text)

mapfile -t AZS < <(aws rds describe-db-subnet-groups --region "$REGION" \
  --db-subnet-group-name "$SRC" \
  --query 'DBSubnetGroups[0].Subnets[].SubnetAvailabilityZone.Name' --output text | tr '\t' '\n')

HEALTHY_AZ=""
for az in "${AZS[@]}"; do
  [[ "$az" != "$FAILED_AZ" ]] && HEALTHY_AZ="$az" && break
done
[[ -n "$HEALTHY_AZ" ]] || { echo "no healthy AZ in subnet group"; exit 1; }

SNAP=$(aws rds describe-db-snapshots --region "$REGION" \
  --db-instance-identifier "$SRC" --snapshot-type automated \
  --query 'sort_by(DBSnapshots[?Status==`available`],&SnapshotCreateTime)[-1].DBSnapshotIdentifier' \
  --output text)

SG=$(aws rds describe-db-instances --region "$REGION" \
  --db-instance-identifier "$SRC" \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)

echo "snap=$SNAP healthy_az=$HEALTHY_AZ dst=$DST"

aws rds restore-db-instance-from-db-snapshot --region "$REGION" \
  --db-instance-identifier "$DST" \
  --db-snapshot-identifier "$SNAP" \
  --db-instance-class "$CLASS" \
  --db-subnet-group-name "$SRC" \
  --availability-zone "$HEALTHY_AZ" \
  --vpc-security-group-ids "$SG" \
  --db-parameter-group-name harbor-live-pg16 \
  --no-multi-az --no-publicly-accessible --port 5432 --storage-type gp3

aws rds wait db-instance-available --region "$REGION" --db-instance-identifier "$DST"
NEW_HOST=$(aws rds describe-db-instances --region "$REGION" \
  --db-instance-identifier "$DST" \
  --query 'DBInstances[0].Endpoint.Address' --output text)

echo "Restored endpoint: $NEW_HOST"
echo "Next: SERVICE_ID=... NEW_HOST=$NEW_HOST ./scripts/repoint-db.sh"
echo "Documented RTO ≈ 25–45 minutes (restore + Cloud Map update + ECS bounce + ALB drain)."
echo "RPO for snapshot path ≈ up to 24h since last automated backup."
