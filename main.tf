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
}

resource "aws_iam_policy_attachment" "default" {
  name       = "permissions-for-${var.name}-${var.region}"
  roles      = [aws_iam_role.default.name]
  policy_arn = aws_iam_policy.default.arn
}

data "aws_iam_policy_document" "default" {
  statement {
    actions = [
      "cloudtrail:LookupEvents"
    ]
    resources = [
      "*"
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "ec2:CreateSnapshot",
      "ec2:CreateSnapshots",
      "ec2:CreateImage",
      "ec2:CreateTags",
      "ec2:Describe*",
      "ec2:DeleteSnapshot",
      "ec2:DeregisterImage",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "*"
    ]
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

  tags = {
    Name        = var.name
    Environment = var.environment
  }
}

resource "aws_lambda_function" "default" {
  function_name    = "${var.name}-${var.region}"
  description      = "EC2 AMI Backup Automation"
  role             = aws_iam_role.default.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  timeout          = var.timeout
  memory_size      = 128
  filename         = "${path.module}/zip/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/zip/lambda_function.zip")

  environment {
    variables = {
      backup_tag       = var.backup_tag
      backup_retention = var.backup_retention
    }
  }

  tags = {
    Name        = var.name
    Type        = "Lambda Function"
    Environment = var.environment
  }
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
}

resource "aws_cloudwatch_event_target" "default" {
  rule = aws_cloudwatch_event_rule.default.name
  arn  = aws_lambda_function.default.arn
}
