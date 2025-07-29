resource "aws_iam_role" "default" {
  name = "${var.name}-${var.region}"
  path = "/service-role/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Action": [
        "sts:AssumeRole"
      ]
    }
  ]
}
  EOF

  tags = merge(local.common_tags, {
    ResourceType = "IAM Role"
  })
}

resource "aws_iam_policy_attachment" "default" {
  name       = "permissions-for-${var.name}-${var.region}"
  roles      = [aws_iam_role.default.name]
  policy_arn = aws_iam_policy.default.arn
}

# Get current AWS region and account ID for scoped permissions
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "default" {
  # CloudTrail permissions for backup auditing (minimal scope)
  statement {
    sid = "CloudTrailAccess"
    actions = [
      "cloudtrail:LookupEvents"
    ]
    resources = ["*"]
    effect = "Allow"
    
    # Limit to specific event types related to EC2
    condition {
      test     = "StringEquals"
      variable = "cloudtrail:EventName"
      values = [
        "CreateImage",
        "CreateSnapshot",
        "DeregisterImage",
        "DeleteSnapshot"
      ]
    }
  }

  # EC2 instance discovery permissions (scoped to current region)
  statement {
    sid = "EC2InstanceDiscovery"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeImages",
      "ec2:DescribeSnapshots"
    ]
    resources = ["*"]
    effect = "Allow"
    
    # Limit to current region
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [data.aws_region.current.name]
    }
  }

  # AMI and Snapshot creation permissions (scoped to current account)
  statement {
    sid = "AMISnapshotCreation"
    actions = [
      "ec2:CreateImage",
      "ec2:CreateSnapshot",
      "ec2:CreateSnapshots"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:image/*",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:snapshot/*",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:volume/*"
    ]
    effect = "Allow"
  }

  # Tagging permissions for created resources
  statement {
    sid = "ResourceTagging"
    actions = [
      "ec2:CreateTags"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:image/*",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:snapshot/*"
    ]
    effect = "Allow"
    
    # Only allow tagging during resource creation
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "CreateImage",
        "CreateSnapshot"
      ]
    }
  }

  # AMI and Snapshot deletion permissions (scoped to current account and backup-created resources)
  statement {
    sid = "AMISnapshotDeletion"
    actions = [
      "ec2:DeregisterImage",
      "ec2:DeleteSnapshot"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:image/*",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:snapshot/*"
    ]
    effect = "Allow"
    
    # Only allow deletion of resources created by this backup system
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/BackupDate"
      values   = ["*"]
    }
  }

  # CloudWatch Logs permissions (scoped to this function's log group)
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name}-${var.region}*"
    ]
    effect = "Allow"
  }

  # CloudWatch Custom Metrics permissions
  statement {
    sid = "CloudWatchMetrics"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
    effect = "Allow"
    
    # Limit to custom namespace for this application
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["AWS/Lambda/AMIBackup"]
    }
  }

  # SQS Dead Letter Queue permissions
  statement {
    sid = "SQSDeadLetterQueue"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.name}-${var.region}-dlq"
    ]
    effect = "Allow"
  }

  # X-Ray tracing permissions
  statement {
    sid = "XRayTracing"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]
    resources = ["*"]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "default" {
  name        = "${var.name}-${var.region}"
  path        = "/service/"
  description = "Enables a Lambda function read and manage EC2 AMIs"

  policy = data.aws_iam_policy_document.default.json
}

resource "aws_cloudwatch_log_group" "default" {
  name              = "/aws/lambda/${aws_lambda_function.default.function_name}"
  retention_in_days = 14

  tags = merge(local.common_tags, {
    ResourceType = "CloudWatch Log Group"
  })
}

# Build Lambda deployment package at runtime
resource "terraform_data" "lambda_package" {
  triggers_replace = [
    filebase64sha256("${path.module}/lambda/index.js"),
    filebase64sha256("${path.module}/lambda/package.json"),
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Building Lambda deployment package..."
      
      # Create build directory
      BUILD_DIR="${path.module}/.terraform/lambda-build"
      ZIP_DIR="${path.module}/zip"
      mkdir -p "$BUILD_DIR" "$ZIP_DIR"
      
      # Clean up previous builds
      rm -rf "${path.module}/lambda/node_modules"
      rm -f "$ZIP_DIR/lambda_function.zip"
      rm -rf "$BUILD_DIR"/*
      
      # Copy source files to build directory
      cp -r "${path.module}/lambda"/* "$BUILD_DIR/"
      
      # Install production dependencies in build directory
      cd "$BUILD_DIR" && npm ci --omit=dev
      
      # Create deployment package from build directory
      if command -v zip >/dev/null 2>&1; then
        cd "$BUILD_DIR" && zip -r "$ZIP_DIR/lambda_function.zip" . -x "*.git*" "*.DS_Store*" "node_modules/.cache/*" "*.test.js" "test.js" "**/test/**" "**/tests/**"
      else
        # For Python zipfile, manually exclude test files
        cd "$BUILD_DIR" && find . -name "*.test.js" -delete && find . -name "test.js" -delete
        cd "$BUILD_DIR" && python3 -m zipfile -c "$ZIP_DIR/lambda_function.zip" .
      fi
      
      # Clean up build directory
      rm -rf "$BUILD_DIR"
      
      echo "Lambda package built successfully: $(ls -lh $ZIP_DIR/lambda_function.zip)"
    EOT
  }
}

# Dead Letter Queue for failed Lambda executions
resource "aws_sqs_queue" "lambda_dlq" {
  count = var.enable_monitoring ? 1 : 0
  
  name                       = "${var.name}-${var.region}-dlq"
  message_retention_seconds  = 1209600  # 14 days
  visibility_timeout_seconds = var.timeout * 6  # 6x Lambda timeout
  
  tags = merge({
    Name        = "${var.name}-${var.region}-dlq"
    Environment = var.environment
    Purpose     = "Lambda Dead Letter Queue"
  }, var.default_tags)
}

resource "aws_lambda_function" "default" {
  depends_on = [terraform_data.lambda_package]
  
  function_name = "${var.name}-${var.region}"
  description   = "EC2 AMI Backup Automation with enhanced monitoring"
  role          = aws_iam_role.default.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = var.timeout
  memory_size   = 512  # Increased from 128MB for better performance
  filename      = "${path.module}/zip/lambda_function.zip"
  source_code_hash = terraform_data.lambda_package.id
  
  # Dead letter queue configuration
  dynamic "dead_letter_config" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      target_arn = aws_sqs_queue.lambda_dlq[0].arn
    }
  }
  
  # Enable X-Ray tracing for debugging
  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      backup_tag       = var.backup_tag
      backup_retention = var.backup_retention
    }
  }

  tags = merge(local.common_tags, {
    ResourceType = "Lambda Function"
  })
}

resource "aws_lambda_permission" "default" {
  statement_id  = "ScaleUpExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.default.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.default.arn
}

resource "aws_cloudwatch_event_rule" "default" {
  name                = "${var.name}-${var.region}-trigger"
  description         = "Triggers AMI Backup of EC2 Instances"
  schedule_expression = var.schedule_expression

  tags = merge({
    Name        = "${var.name}-${var.region}-trigger"
    Environment = var.environment
  }, var.default_tags)
}

resource "aws_cloudwatch_event_target" "default" {
  rule = aws_cloudwatch_event_rule.default.name
  arn  = aws_lambda_function.default.arn
}

# SNS Topic for notifications (optional)
resource "aws_sns_topic" "backup_notifications" {
  count = var.create_sns_topic ? 1 : 0
  
  name         = "${var.name}-${var.region}-notifications"
  display_name = "AMI Backup Notifications"

  tags = merge({
    Name        = "${var.name}-${var.region}-notifications"
    Environment = var.environment
    Purpose     = "Backup Notifications"
  }, var.default_tags)
}

resource "aws_sns_topic_subscription" "email_notification" {
  count = var.create_sns_topic && var.notification_email != "" ? 1 : 0
  
  topic_arn = aws_sns_topic.backup_notifications[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Local values for consistent resource configuration
locals {
  sns_topic_arn = var.sns_topic_arn != "" ? var.sns_topic_arn : (
    var.create_sns_topic ? aws_sns_topic.backup_notifications[0].arn : ""
  )
  
  # Comprehensive default tags applied to all resources
  common_tags = merge({
    Name           = var.name
    Environment    = var.environment
    Region         = var.region
    ManagedBy      = "Terraform"
    Module         = "ami-backup-automation"
    BackupTag      = var.backup_tag
    RetentionDays  = tostring(var.backup_retention)
  }, 
  var.cost_center != "" ? { CostCenter = var.cost_center } : {},
  var.project_name != "" ? { Project = var.project_name } : {},
  var.owner != "" ? { Owner = var.owner } : {},
  var.default_tags)
}

# CloudWatch Alarms (if monitoring is enabled)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name        = "${var.name}-${var.region}-lambda-errors"
  alarm_description = "Lambda function errors for AMI backup"
  
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  
  dimensions = {
    FunctionName = aws_lambda_function.default.function_name
  }
  
  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  
  tags = merge({
    Name        = "${var.name}-${var.region}-lambda-errors"
    Environment = var.environment
    Purpose     = "Lambda Error Monitoring"
  }, var.default_tags)
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name        = "${var.name}-${var.region}-lambda-duration"
  alarm_description = "Lambda function duration approaching timeout"
  
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.timeout * 1000 * 0.8  # 80% of timeout (convert to milliseconds)
  comparison_operator = "GreaterThanThreshold"
  
  dimensions = {
    FunctionName = aws_lambda_function.default.function_name
  }
  
  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  
  tags = merge({
    Name        = "${var.name}-${var.region}-lambda-duration"
    Environment = var.environment
    Purpose     = "Lambda Performance Monitoring"
  }, var.default_tags)
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name        = "${var.name}-${var.region}-lambda-throttles"
  alarm_description = "Lambda function throttling detected"
  
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  
  dimensions = {
    FunctionName = aws_lambda_function.default.function_name
  }
  
  alarm_actions = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  ok_actions    = local.sns_topic_arn != "" ? [local.sns_topic_arn] : []
  
  tags = merge({
    Name        = "${var.name}-${var.region}-lambda-throttles"
    Environment = var.environment
    Purpose     = "Lambda Throttling Monitoring"
  }, var.default_tags)
}
