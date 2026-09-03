variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for the state bucket and lock table."
  default     = "harbor-tfstate"
}
