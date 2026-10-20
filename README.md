[![CI/CD Pipeline](https://github.com/mikmorley/terraform-aws-ec2-backup/actions/workflows/terraform-lint.yml/badge.svg)](https://github.com/mikmorley/terraform-aws-ec2-backup/actions/workflows/terraform-lint.yml)

# terraform-aws-ec2-backup

A Terraform module that creates scheduled AMI backups of tagged EC2 instances and deletes them after a retention period. A Lambda function (Node.js 20.x, AWS SDK v3) runs on a CloudWatch Events schedule, creates an AMI and its snapshots for each tagged instance, and removes backups older than `backup_retention` days.

## Features

- Least-privilege IAM policies scoped to the current account and region
- CloudWatch alarms, 8 custom metrics, and optional SNS email alerts
- Dead Letter Queue and X-Ray tracing for failed or slow runs
- A failed backup for one instance does not stop the others
- Cost center, project, and owner tags
- The Lambda package is built during `terraform apply`, so no artifacts are committed

## Quick Start

### Basic Usage
```terraform
module "ec2_backup" {
  source  = "mikmorley/ec2-backup/aws"
  version = "~> 2.0"

  # Required variables
  name                = "my-backup-system"
  environment         = "production"
  region              = "us-east-1"
  schedule_expression = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC

  # Optional customization
  backup_tag          = "AutoBackup"
  backup_retention    = 7

  # Monitoring (optional)
  enable_monitoring    = true
  create_sns_topic     = true
  notification_email   = "alerts@company.com"

  # Tagging
  cost_center         = "Infrastructure"
  project_name        = "Production-Backups"
  owner               = "DevOps-Team"
}
```

### With Existing SNS Topic
```terraform
module "ec2_backup" {
  source  = "mikmorley/ec2-backup/aws"
  version = "~> 2.0"

  name                = "prod-backup"
  environment         = "production"
  region              = "us-east-1"
  schedule_expression = "cron(0 2 * * ? *)"

  # Use existing SNS topic
  sns_topic_arn       = "arn:aws:sns:us-east-1:123456789012:existing-alerts"
}
```

### Tag Your EC2 Instances

Add the backup tag to each instance you want to back up:

```bash
# AWS CLI example
aws ec2 create-tags \
  --resources i-1234567890abcdef0 \
  --tags Key=AutoBackup,Value=yes

# Terraform example
resource "aws_instance" "web" {
  # ... other configuration ...

  tags = {
    Name       = "web-server"
    AutoBackup = "yes"  # This instance will be backed up
  }
}
```

The tag value must be exactly `"yes"`.

## Examples

Runnable configurations live in [`examples/`](examples):

- [`basic`](examples/basic): required variables only
- [`complete`](examples/complete): custom tag, retention, monitoring, SNS email, and cost tags

## Outputs

| Output | Description |
|--------|-------------|
| `lambda_function_arn` | ARN of the backup Lambda function |
| `lambda_function_name` | Name of the backup Lambda function |
| `iam_role_arn` | ARN of the Lambda IAM role |
| `iam_role_name` | Name of the Lambda IAM role |
| `cloudwatch_event_rule_arn` | ARN of the schedule rule |
| `cloudwatch_log_group_name` | Lambda log group name |
| `sns_topic_arn` | SNS topic ARN (created or supplied), empty string if none |
| `dead_letter_queue_arn` | DLQ ARN, `null` when monitoring is disabled |
| `dead_letter_queue_url` | DLQ URL, `null` when monitoring is disabled |

## Monitoring and Metrics

The Lambda function publishes these metrics to the `AWS/Lambda/AMIBackup` namespace:

| Metric Name | Description | Unit |
|-------------|-------------|------|
| `ExecutionDuration` | Function execution time | Milliseconds |
| `BackupsAttempted` | Number of instances processed | Count |
| `BackupsSuccessful` | Successful backup operations | Count |
| `BackupsFailed` | Failed backup operations | Count |
| `AMIsCreated` | New AMIs created | Count |
| `AMIsDeleted` | Old AMIs cleaned up | Count |
| `SnapshotsDeleted` | Snapshots removed | Count |
| `ExecutionSuccess` | Overall execution status | Count |

### CloudWatch Alarms

With `enable_monitoring = true`, the module creates alarms for:
- **Lambda Errors**: any function error
- **Lambda Duration**: execution time above 80% of the timeout
- **Lambda Throttles**: any throttled invocation

## Prerequisites

- **Terraform**: 1.0 or later
- **AWS Provider**: 4.0 or later
- **AWS Credentials**: configured through the AWS CLI, environment variables, or an IAM role
- **IAM Permissions**: the deploying user or role must be able to create:
  - Lambda functions and IAM roles
  - CloudWatch Events/EventBridge rules
  - CloudWatch alarms and log groups
  - SNS topics (if creating notifications)
  - SQS queues (for the Dead Letter Queue)

## Configuration Variables

### Required Variables

| Variable | Description | Type | Example |
|----------|-------------|------|---------|
| `name` | Resource naming prefix | `string` | `"prod-backup"` |
| `environment` | Environment tag | `string` | `"production"` |
| `region` | AWS region | `string` | `"us-east-1"` |
| `schedule_expression` | Backup schedule | `string` | `"cron(0 2 * * ? *)"` |

### Optional Configuration Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `timeout` | Lambda timeout (15-900 seconds) | `number` | `60` |
| `backup_tag` | EC2 instance tag for backup selection | `string` | `"Backup"` |
| `backup_retention` | Days to keep backups (1-365) | `number` | `30` |

### Monitoring Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `enable_monitoring` | Enable CloudWatch alarms | `bool` | `true` |
| `create_sns_topic` | Create SNS topic for notifications | `bool` | `false` |
| `sns_topic_arn` | Existing SNS topic ARN | `string` | `""` |
| `notification_email` | Email for backup alerts | `string` | `""` |

### Tagging Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `cost_center` | Cost center for billing | `string` | `""` |
| `project_name` | Project identification | `string` | `""` |
| `owner` | Resource owner | `string` | `""` |
| `default_tags` | Additional custom tags | `map(string)` | `{}` |

### Input Validation

Variables are validated at plan time:
- **Email addresses**: valid email format
- **Environment**: one of `dev`, `test`, `staging`, `prod`, `production`
- **Region**: valid AWS region format (e.g., `us-east-1`)
- **Timeout**: 15-900 seconds
- **Retention**: 1-365 days

## Schedule Expressions

`schedule_expression` accepts cron and rate expressions.

### Cron Examples
- **Daily at 2 AM UTC**: `cron(0 2 * * ? *)`
- **Every Sunday at 3 AM UTC**: `cron(0 3 ? * SUN *)`
- **Weekdays at 10 PM UTC**: `cron(0 22 ? * MON-FRI *)`
- **First day of month at midnight**: `cron(0 0 1 * ? *)`

### Rate Examples
- **Every 6 hours**: `rate(6 hours)`
- **Every 30 minutes**: `rate(30 minutes)`
- **Every 2 days**: `rate(2 days)`

### Scheduling Tips
- **Production**: run during off-peak hours (2-4 AM in your region)
- **Development**: back up daily or weekly
- **Critical systems**: back up every 6-12 hours
- **Cost**: avoid overlapping with high-traffic periods

## Security

### IAM
- Permissions are limited to the current AWS account and region
- Resource ARNs are specific, with no `"*"` resources
- Each operation has its own action-level permissions
- The function can only delete resources it created

### Resource Protection
- Only resources with a `BackupDate` tag can be deleted
- Operations stay inside the deployment region
- The function cannot touch resources in other AWS accounts

## Troubleshooting

**No backups are being created:**
1. Verify EC2 instances have the correct tag (`backup_tag` = `"yes"`)
2. Check the Lambda function logs in CloudWatch
3. Confirm the IAM permissions were applied
4. Verify the schedule expression is valid

**Backups failing:**
1. Check CloudWatch alarms for the error type
2. Read the Lambda function logs for error messages
3. Verify the IAM role can perform EC2 operations
4. Check the Dead Letter Queue for failed executions

**Missing notifications:**
1. Confirm the SNS topic configuration and subscriptions
2. Confirm the email subscription (if using email notifications)
3. Verify CloudWatch alarms exist and are enabled

### Where to Look
- **CloudWatch Logs**: `/aws/lambda/{function-name}`
- **Custom Metrics**: `AWS/Lambda/AMIBackup` namespace
- **Dead Letter Queue**: `{name}-{region}-dlq`
- **X-Ray Traces**: Lambda service map and execution traces

## Version History

### v2.0.0 (Current)
- Node.js 20.x runtime
- Least-privilege IAM with scoped permissions
- 8 custom metrics and CloudWatch alarms
- Dead Letter Queue and X-Ray tracing
- Lambda memory raised from 128MB to 512MB
- Lambda package built at deploy time, no committed artifacts

### v1.x (Legacy)
- Basic backup functionality on Node.js 12.x
- Limited monitoring and broad IAM permissions
- Pre-built Lambda packages committed to the repository

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature-name`)
3. Test your changes
4. Update documentation as needed
5. Open a pull request

### Development Setup
```bash
# Clone your fork
git clone https://github.com/mikmorley/terraform-aws-ec2-backup.git

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes and test
terraform plan
terraform apply

# Commit and push
git commit -m "Describe your change"
git push origin feature/your-feature-name
```

## License

MIT License. See the [LICENSE](LICENSE) file.

---

Questions or problems? Open an [issue](https://github.com/mikmorley/terraform-aws-ec2-backup/issues).
