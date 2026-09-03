# Harbor live — engineer runbook

Stack: VPC (public + private app + private db), **no NAT**, ECS Fargate API, single-AZ RDS Postgres, HTTPS ALB, S3 assets (`uploads/*` only). Private DB DNS via **AWS Cloud Map**.

## Budget trade-offs ($150/mo cap)

1. **No NAT gateway** (~$32–36/mo saved). App subnets have **no** `0.0.0.0/0` route. ECR, CloudWatch Logs, Secrets Manager, and S3 use VPC endpoints. Consequence: tasks cannot reach the public internet (no arbitrary egress, no public image pulls from inside the VPC).
2. **Single-AZ `db.t4g.micro`**. Consequence: AZ loss = full outage until restore (see §5). Quiet month target ~$70–110.

## 0. Configure first

| Need | Why |
|---|---|
| AWS credentials in the environment | No secrets in tfvars |
| Route53 **public** zone + hostname | ACM DNS validation + ALB alias |
| `domain_name` must live in that zone | Wrong zone → ACM validation hangs |
| Ops email | SNS confirm is manual |
| Docker (to push `app/`) | No NAT → cannot pull public images from tasks |
| Terraform ≥ 1.6 | |

## 1. Clone → remote state → apply environment

```bash
git clone <this-repo>
cd <repo-root>
aws sts get-caller-identity

terraform -chdir=bootstrap init
terraform -chdir=bootstrap apply
terraform -chdir=bootstrap output -raw backend_hcl > backend.hcl

cp terraform.tfvars.example terraform.tfvars
# set domain_name, hosted_zone_id, alert_email

terraform init -backend-config=backend.hcl
terraform plan -out=live.tfplan
terraform apply live.tfplan
```

Bootstrap is **configure first** (local state). A backend cannot create itself. After `backend.hcl` exists, the environment is **one** `terraform apply`.

Default `desired_count = 0` so apply succeeds before an image exists.

## 2. Push the API image (laptop has internet)

```bash
chmod +x scripts/*.sh
./scripts/push-api.sh
```

Then in `terraform.tfvars`:

```hcl
container_image = "<ecr_url>:<tag>"
desired_count   = 2
```

`terraform apply` again. Tasks pull **only** from this ECR via PrivateLink.

## 3. Destroy

```bash
terraform destroy
terraform -chdir=bootstrap destroy   # only if retiring the state bucket
```

## 4. Request path (internet → RDS)

Internet → ALB (public subnets) → SG peer ALB↔ECS → Fargate in **app** subnets → SG peer ECS↔RDS → Postgres in **db** subnets. The TCP session from the task uses the **app** route table (VPC-local destinations); no internet egress. `DB_HOST` is Cloud Map: `postgres.<project>-<env>.local`.

## 5. RDS AZ failure

| | |
|---|---|
| RTO | **~25–45 min** (restore 20–40 + Cloud Map repoint + ECS force-new-deployment + ALB drain) |
| RPO (snapshot) | **up to ~24h** since last automated backup |
| RPO (PITR) | **~5 min** if WAL still available |

**Do not** set `snapshot_identifier` on the live `aws_db_instance` during the outage (ForceNew).

```bash
./scripts/restore-rds.sh
SERVICE_ID=$(terraform output -raw discovery_service_id) \
  NEW_HOST=<restored-endpoint> ./scripts/repoint-db.sh
```

Unprotected mode: writes after the last snapshot are lost on snapshot-only restore. This stack does **not** provide Multi-AZ ~60s failover.

## 6. Hardening summary

- Container UID `1000` (root validation + Dockerfile `USER app`)
- `readonlyRootFilesystem = true` + ephemeral volume mounted at `/tmp`
- Capability drop ALL; task role limited to `s3:.../uploads/*`
- SNS publish scoped with `aws:SourceAccount`; RDS failure event subscription
