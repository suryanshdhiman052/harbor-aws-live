variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "ALB needs at least two public subnets."
  }
}

variable "app_subnet_ids" {
  type = list(string)

  validation {
    condition     = length(var.app_subnet_ids) >= 2
    error_message = "ECS needs at least two private app subnets."
  }
}

variable "alb_sg_id" {
  type = string
}

variable "ecs_sg_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "hosted_zone_id" {
  type = string
}

variable "container_image" {
  type        = string
  description = "Full image URI. Empty string means use the module ECR repo :latest after push."
}

variable "container_port" {
  type = number
}

variable "container_user" {
  type = string
}

variable "desired_count" {
  type = number
}

variable "db_secret_arn" {
  type = string
}

variable "db_address" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}
