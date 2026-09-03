data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "ops" {
  name = "${var.project}-${var.environment}-ops"
}

resource "aws_sns_topic_subscription" "ops_email" {
  topic_arn = aws_sns_topic.ops.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_policy" "ops" {
  arn = aws_sns_topic.ops.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAwsServicesPublish"
        Effect = "Allow"
        Principal = {
          Service = [
            "events.amazonaws.com",
            "cloudwatch.amazonaws.com",
            "rds.amazonaws.com",
          ]
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.ops.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Init failures when endpoints/ECR/secrets path breaks (no NAT to fall back on).
resource "aws_cloudwatch_event_rule" "ecs_init_fail" {
  name = "${var.project}-${var.environment}-ecs-init-fail"
  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn = [module.compute.cluster_arn]
      lastStatus = ["STOPPED"]
      stoppedReason = [
        { prefix = "CannotPullContainerError" },
        { prefix = "ResourceInitializationError" },
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecs_init_fail_sns" {
  rule       = aws_cloudwatch_event_rule.ecs_init_fail.name
  arn        = aws_sns_topic.ops.arn
  depends_on = [aws_sns_topic_policy.ops]
}

resource "aws_db_event_subscription" "rds_failure" {
  name             = "${var.project}-${var.environment}-rds-failure"
  sns_topic        = aws_sns_topic.ops.arn
  source_type      = "db-instance"
  source_ids       = [module.database.identifier]
  event_categories = ["failure"]
  enabled          = true
  depends_on       = [aws_sns_topic_policy.ops]
}
