output "api_url" {
  value = "https://${var.domain_name}"
}

output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "ecr_repository_url" {
  value = module.compute.ecr_repository_url
}

output "assets_bucket" {
  value = module.compute.assets_bucket
}

output "db_dns_name" {
  value       = module.compute.db_dns_name
  description = "Cloud Map name used as DB_HOST inside tasks."
}

output "rds_secret_arn" {
  value     = module.database.master_user_secret_arn
  sensitive = true
}

output "ecs_cluster" {
  value = module.compute.cluster_name
}

output "discovery_service_id" {
  value = module.compute.discovery_service_id
}
