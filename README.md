# Harbor — budget-capped AWS environment

Public repository: https://github.com/suryanshdhiman052/harbor-aws-live

Terraform modules: `networking`, `compute`, `database`.

- No NAT (VPC endpoints for ECR, Logs, Secrets Manager, S3)
- AWS Cloud Map for Postgres DNS
- Python API running as UID 1000
- S3 assets with IAM limited to `uploads/*`
- Ephemeral `/tmp` volume with `readonlyRootFilesystem`

Clone and follow **[RUNBOOK.md](./RUNBOOK.md)**.
