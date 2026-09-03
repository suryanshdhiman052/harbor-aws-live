# Requirements check (harbor fresh stack)

| # | Requirement | How this stack meets it |
|---|---|---|
| 1 | ≥3 modules: networking, compute, database | `modules/networking`, `modules/compute`, `modules/database` |
| 2 | ECS non-root + least privilege | UID `1000` validated + Dockerfile `USER app`; exec role scoped; task role `uploads/*` only |
| 3 | RDS private | `publicly_accessible = false`, db subnets, SG ingress from ECS only |
| 4 | Remote state S3 + DynamoDB lock | `bootstrap/` + root `backend "s3" {}` |
| 5 | ≤$150 trade-off + real consequence | **No NAT** + single-AZ `db.t4g.micro`; RTO 25–45 min / snapshot RPO ≤24h in RUNBOOK |
| 6 | GitHub link | Push this directory to a **new** public repo (do not reuse prior answer text) |
| 7 | Runbook | `RUNBOOK.md` |

## Deliberate differences vs prior attempts

- No NAT / no Spot capacity strategy
- Cloud Map instead of private Route53 zone
- Python app instead of Node
- S3 inside compute with prefix IAM
- `/tmp` ephemeral volume with readonly rootfs
- Project/CIDR/env naming (`harbor` / `10.64.0.0/16` / `live`)
