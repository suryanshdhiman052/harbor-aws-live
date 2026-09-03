data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  # Budget trade-off: no NAT gateway. Private workloads use interface/gateway
  # endpoints only — there is no general internet egress from app/db subnets.
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = var.name }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.name}-public-${local.azs[count.index]}" }
}

resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10 + count.index)
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.name}-app-${local.azs[count.index]}" }
}

resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20 + count.index)
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.name}-db-${local.azs[count.index]}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public" }
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# App + DB share isolated route tables with NO 0.0.0.0/0 route.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { Name = "${var.name}-s3" }
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name}-vpce"
  description = "Interface VPC endpoints — HTTPS from ECS tasks only"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-vpce" }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(["ecr.api", "ecr.dkr", "logs", "secretsmanager"])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.app[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${var.name}-${each.key}" }
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Internet-facing ALB"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-alb" }
}

resource "aws_security_group" "ecs" {
  name        = "${var.name}-ecs"
  description = "Fargate tasks — no public IP"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-ecs" }
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds"
  description = "Postgres — private, ECS only"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-rds" }
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP redirect to HTTPS"
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS"
}

# Explicit peer rules — no reliance on default allow-all egress for data plane.
resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "egress"
  security_group_id        = aws_security_group.alb.id
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  description              = "ALB to tasks"
}

resource "aws_security_group_rule" "ecs_from_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.ecs.id
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Tasks from ALB"
}

resource "aws_security_group_rule" "ecs_to_rds" {
  type                     = "egress"
  security_group_id        = aws_security_group.ecs.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  description              = "Tasks to Postgres"
}

resource "aws_security_group_rule" "rds_from_ecs" {
  type                     = "ingress"
  security_group_id        = aws_security_group.rds.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  description              = "Postgres from tasks"
}

resource "aws_security_group_rule" "ecs_to_endpoints" {
  type                     = "egress"
  security_group_id        = aws_security_group.ecs.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.endpoints.id
  description              = "Tasks to VPC interface endpoints"
}

resource "aws_security_group_rule" "endpoints_from_ecs" {
  type                     = "ingress"
  security_group_id        = aws_security_group.endpoints.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  description              = "Endpoints from tasks"
}

resource "aws_security_group_rule" "ecs_dns" {
  for_each          = toset(["tcp", "udp"])
  type              = "egress"
  security_group_id = aws_security_group.ecs.id
  from_port         = 53
  to_port           = 53
  protocol          = each.key
  cidr_blocks       = [var.vpc_cidr]
  description       = "VPC DNS"
}

# S3 gateway endpoint is prefix-list based; allow HTTPS to the managed prefix list.
data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${data.aws_region.current.name}.s3"
}

resource "aws_security_group_rule" "ecs_to_s3" {
  type              = "egress"
  security_group_id = aws_security_group.ecs.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_prefix_list.s3.id]
  description       = "ECR layers / assets via S3 gateway endpoint"
}
