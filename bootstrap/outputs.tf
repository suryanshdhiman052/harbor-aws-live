output "backend_hcl" {
  description = "Paste into backend.hcl for the workload root."
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.state.bucket}"
    key            = "harbor/live/terraform.tfstate"
    region         = "${var.aws_region}"
    dynamodb_table = "${aws_dynamodb_table.lock.name}"
    encrypt        = true
  EOT
}
