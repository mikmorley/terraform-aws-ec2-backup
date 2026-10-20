output "lambda_function_arn" {
  description = "ARN of the backup Lambda function"
  value       = aws_lambda_function.default.arn
}

output "lambda_function_name" {
  description = "Name of the backup Lambda function"
  value       = aws_lambda_function.default.function_name
}

output "iam_role_arn" {
  description = "ARN of the IAM role used by the Lambda function"
  value       = aws_iam_role.default.arn
}

output "iam_role_name" {
  description = "Name of the IAM role used by the Lambda function"
  value       = aws_iam_role.default.name
}

output "cloudwatch_event_rule_arn" {
  description = "ARN of the CloudWatch Events rule that triggers the backup"
  value       = aws_cloudwatch_event_rule.default.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for the Lambda function"
  value       = aws_cloudwatch_log_group.default.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic used for notifications (created or supplied), or an empty string if none"
  value       = local.sns_topic_arn
}

output "dead_letter_queue_arn" {
  description = "ARN of the Dead Letter Queue, or null when monitoring is disabled"
  value       = one(aws_sqs_queue.lambda_dlq[*].arn)
}

output "dead_letter_queue_url" {
  description = "URL of the Dead Letter Queue, or null when monitoring is disabled"
  value       = one(aws_sqs_queue.lambda_dlq[*].url)
}
