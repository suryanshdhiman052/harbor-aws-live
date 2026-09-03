# Stable private DNS name for Postgres. After a snapshot restore, update this
# Cloud Map instance attribute (or recreate the service instance) — the task
# keeps DB_HOST=postgres.<namespace> without a new task-definition revision.
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "${var.name}.local"
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "postgres" {
  name = "postgres"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      ttl  = 15
      type = "CNAME"
    }

    routing_policy = "WEIGHTED"
  }
}

resource "aws_service_discovery_instance" "postgres" {
  instance_id = "primary"
  service_id  = aws_service_discovery_service.postgres.id

  attributes = {
    AWS_INSTANCE_CNAME = var.db_address
    # Weighted routing requires a non-zero weight attribute.
    AWS_INSTANCE_WEIGHT = "1"
  }
}
