resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-pg"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.name}-pg" }
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg16"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

# $150 cap trade-off #1: single-AZ db.t4g.micro (no Multi-AZ standby).
# Restore must use a NEW identifier — never snapshot_identifier on this
# resource (ForceNew) while the AZ is dead.
resource "aws_db_instance" "this" {
  identifier     = "${var.name}-pg"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  db_name  = var.db_name
  username = var.username

  manage_master_user_password = true

  allocated_storage     = 20
  max_allocated_storage = 40
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false
  multi_az               = false
  parameter_group_name   = aws_db_parameter_group.this.name
  port                   = 5432

  backup_retention_period   = 7
  backup_window             = "06:00-07:00"
  maintenance_window        = "sun:07:00-sun:08:00"
  delete_automated_backups  = false
  deletion_protection       = false
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name}-pg-final"
  copy_tags_to_snapshot     = true

  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = { Name = "${var.name}-pg" }
}
