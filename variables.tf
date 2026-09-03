variable "aws_region" {
  type        = string
  description = "AWS region for the stack and bootstrap backend."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Short name prefix for resources."
  default     = "harbor"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,12}$", var.project))
    error_message = "project must be lowercase alphanumeric/hyphen, 2–13 chars."
  }
}

variable "environment" {
  type        = string
  description = "Environment label."
  default     = "live"

  validation {
    condition     = contains(["live", "stage", "dev"], var.environment)
    error_message = "environment must be live, stage, or dev."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR. App and DB subnets are carved from this block."
  default     = "10.64.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "domain_name" {
  type        = string
  description = "Public API hostname for ACM and the ALB alias (must sit in hosted_zone_id)."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$", var.domain_name))
    error_message = "domain_name must be a DNS hostname."
  }
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 public hosted zone ID for ACM validation and alias."

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.hosted_zone_id))
    error_message = "hosted_zone_id must look like a Route53 zone id (starts with Z)."
  }
}

variable "alert_email" {
  type        = string
  description = "Email for SNS ops alerts (confirm the subscription in your inbox)."

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "alert_email must be a valid email."
  }
}

variable "container_image" {
  type        = string
  description = "ECR image URI. Push with scripts/push-api.sh before expecting healthy tasks (no NAT / no public pulls)."
  default     = ""
}

variable "container_port" {
  type        = number
  description = "Container listen port."
  default     = 8080

  validation {
    condition     = var.container_port >= 1024 && var.container_port <= 65535
    error_message = "container_port must be 1024–65535."
  }
}

variable "container_user" {
  type        = string
  description = "Numeric UID for the container process. Must be 1000 (matches app/Dockerfile)."
  default     = "1000"

  validation {
    condition     = var.container_user == "1000"
    error_message = "container_user must be UID 1000."
  }
}

variable "db_name" {
  type    = string
  default = "harbor"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.db_name))
    error_message = "db_name must be a valid Postgres identifier."
  }
}

variable "db_username" {
  type    = string
  default = "harbor"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.db_username))
    error_message = "db_username must be a valid Postgres identifier."
  }
}

variable "desired_count" {
  type        = number
  description = "ECS desired tasks. Keep at 0 until the first image is pushed to ECR."
  default     = 0

  validation {
    condition     = var.desired_count >= 0 && var.desired_count <= 4
    error_message = "desired_count must be 0–4 under the budget cap."
  }
}
