variable "name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "RDS subnet group needs at least two subnets."
  }
}

variable "rds_sg_id" {
  type = string
}

variable "db_name" {
  type = string
}

variable "username" {
  type = string
}
