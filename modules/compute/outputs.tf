output "alb_dns_name" {
  value = aws_lb.api.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "assets_bucket" {
  value = aws_s3_bucket.assets.bucket
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "service_name" {
  value = aws_ecs_service.api.name
}

output "db_dns_name" {
  value       = "postgres.${aws_service_discovery_private_dns_namespace.internal.name}"
  description = "Cloud Map DNS name injected as DB_HOST."
}

output "discovery_service_id" {
  value = aws_service_discovery_service.postgres.id
}
