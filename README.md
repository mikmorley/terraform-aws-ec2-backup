[![CI/CD Pipeline](https://github.com/mikmorley/terraform-aws-ec2-backup/actions/workflows/terraform-lint.yml/badge.svg)](https://github.com/mikmorley/terraform-aws-ec2-backup/actions/workflows/terraform-lint.yml)

# terraform-aws-ec2-backup

A **production-ready** Terraform module for automated EC2 backup management with enterprise-grade security, monitoring, and reliability features. This module automates the creation of Amazon Machine Images (AMIs) and associated snapshots at scheduled intervals, with comprehensive error handling, least-privilege IAM permissions, and advanced monitoring capabilities.

## ✨ Key Features

- 🔒 **Enhanced Security**: Least-privilege IAM policies with scoped permissions and conditional access
- 📊 **Comprehensive Monitoring**: CloudWatch alarms, custom metrics, and SNS notifications
- 🛡️ **Reliability**: Dead Letter Queue (DLQ), X-Ray tracing, and graceful error handling
- ⚡ **Modern Architecture**: Node.js 20.x runtime, AWS SDK v3, and optimized performance
- 🏷️ **Advanced Tagging**: Cost center tracking, project organization, and compliance support
- 🔄 **Dynamic Building**: Runtime Lambda package creation with no committed artifacts

## 🚀 What's New

This module has been completely modernized with enterprise-grade features:

### Security Enhancements
- **Least-privilege IAM**: Scoped to current account/region with conditional access
- **Resource-specific permissions**: No more broad `"*"` permissions
- **Backup-tagged resources only**: Can only delete resources created by this system

### Monitoring & Observability  
- **8 custom CloudWatch metrics**: Success rates, performance, resource counts
- **Intelligent alerting**: Lambda errors, duration, and throttling alarms
- **SNS notifications**: Email alerts for backup failures (optional)
- **X-Ray tracing**: Detailed execution analysis and debugging

### Reliability & Performance
- **Dead Letter Queue**: Captures failed executions for analysis
- **Enhanced error handling**: Individual failures don't stop entire process
- **512MB memory**: 4x performance improvement over previous versions
- **Graceful degradation**: Continues processing if individual backups fail

### Modern Architecture
- **Node.js 20.x LTS**: Latest supported runtime (upgraded from deprecated 12.x)
- **AWS SDK v3**: 75% smaller bundle size with modular imports
- **Runtime building**: No pre-built packages committed to repository
- **Comprehensive logging**: Detailed execution summaries and metrics

## 📋 Quick Start

### Basic Usage
```terraform
module "ec2_backup" {
  source = "mikmorley/ec2-backup/aws"
  version = "~> 2.0"

  # Required variables
  name                = "my-backup-system"
  environment         = "production"
  region              = "us-east-1"
  schedule_expression = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC

  # Optional customization
  backup_tag          = "AutoBackup"
  backup_retention    = 7
  
  # Enhanced monitoring (optional)
  enable_monitoring    = true
  create_sns_topic     = true
  notification_email   = "alerts@company.com"
  
  # Advanced tagging
  cost_center         = "Infrastructure"
  project_name        = "Production-Backups"
  owner               = "DevOps-Team"
}
```

### With Existing SNS Topic
```terraform
module "ec2_backup" {
  source = "mikmorley/ec2-backup/aws"
  version = "~> 2.0"

  name                = "prod-backup"
  environment         = "production"
  region              = "us-east-1"
  schedule_expression = "cron(0 2 * * ? *)"
  
  # Use existing SNS topic
  sns_topic_arn       = "arn:aws:sns:us-east-1:123456789012:existing-alerts"
}
```

### 🏷️ Tag Your EC2 Instances

Add the backup tag to EC2 instances you want to backup:

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

**Important**: The tag value must be exactly `"yes"` for the instance to be included in backups.

## 📊 Monitoring & Metrics

The module publishes comprehensive metrics to CloudWatch under the `AWS/Lambda/AMIBackup` namespace:

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

When `enable_monitoring = true`, the module automatically creates alarms for:
- **Lambda Errors**: Triggers on any Lambda function errors
- **Lambda Duration**: Alerts when execution time approaches timeout (80% threshold)
- **Lambda Throttles**: Detects function throttling issues

## 🔧 Prerequisites

- **Terraform**: Version 1.0 or later
- **AWS Provider**: Version 4.0 or later  
- **AWS Credentials**: Configured via AWS CLI, environment variables, or IAM roles
- **IAM Permissions**: The deploying user/role needs permissions to create:
  - Lambda functions and IAM roles
  - CloudWatch Events/EventBridge rules
  - CloudWatch alarms and log groups
  - SNS topics (if creating notifications)
  - SQS queues (for Dead Letter Queue)

## 📝 Configuration Variables

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

All variables include comprehensive validation:
- **Email addresses**: Must be valid email format
- **Environment**: Must be one of: `dev`, `test`, `staging`, `prod`, `production`
- **Region**: Must be valid AWS region format (e.g., `us-east-1`)
- **Timeouts**: Must be between 15-900 seconds
- **Retention**: Must be between 1-365 days

## ⏰ Schedule Expressions

The `schedule_expression` variable supports both cron and rate expressions:

### Cron Examples
- **Daily at 2 AM UTC**: `cron(0 2 * * ? *)`
- **Every Sunday at 3 AM UTC**: `cron(0 3 ? * SUN *)`
- **Weekdays at 10 PM UTC**: `cron(0 22 ? * MON-FRI *)`
- **First day of month at midnight**: `cron(0 0 1 * ? *)`

### Rate Examples  
- **Every 6 hours**: `rate(6 hours)`
- **Every 30 minutes**: `rate(30 minutes)`
- **Every 2 days**: `rate(2 days)`

### Best Practices
- **Production environments**: Consider off-peak hours (2-4 AM in your region)
- **Development environments**: Less frequent backups (daily or weekly)
- **Critical systems**: More frequent backups (every 6-12 hours)
- **Cost optimization**: Avoid overlapping with high-traffic periods

## 🔒 Security Features

### Least-Privilege IAM
The module implements comprehensive security controls:

- **Scoped permissions**: Limited to current AWS account and region
- **Resource-specific ARNs**: No broad `"*"` resource permissions
- **Conditional access**: Can only operate on backup-tagged resources
- **Action-specific**: Precise permissions for each operation type
- **Backup verification**: Can only delete resources created by this system

### Resource Protection
- **Deletion protection**: Only resources with `BackupDate` tag can be deleted
- **Region isolation**: Operations limited to deployment region
- **Account isolation**: Cannot access resources in other AWS accounts

## 🚨 Troubleshooting

### Common Issues

**No backups are being created:**
1. Verify EC2 instances have the correct tag (`backup_tag` = `"yes"`)
2. Check Lambda function logs in CloudWatch
3. Ensure IAM permissions are correctly applied
4. Verify the schedule expression is valid

**Backups failing:**
1. Check CloudWatch alarms for specific error types
2. Review Lambda function logs for detailed error messages
3. Verify sufficient IAM permissions for EC2 operations
4. Check Dead Letter Queue for failed executions

**Missing notifications:**
1. Confirm SNS topic configuration and subscriptions
2. Check email subscription confirmation (if using email notifications)
3. Verify CloudWatch alarms are configured and enabled

### Monitoring Resources
- **CloudWatch Logs**: `/aws/lambda/{function-name}`
- **Custom Metrics**: `AWS/Lambda/AMIBackup` namespace
- **Dead Letter Queue**: `{name}-{region}-dlq`
- **X-Ray Traces**: Lambda service map and execution traces

## 🔄 Version History

### v2.0.0 (Current)
- ✅ **Modern Runtime**: Upgraded to Node.js 20.x LTS
- ✅ **Enhanced Security**: Least-privilege IAM with scoped permissions  
- ✅ **Advanced Monitoring**: 8 custom metrics + CloudWatch alarms
- ✅ **Reliability**: Dead Letter Queue + X-Ray tracing
- ✅ **Performance**: 4x memory increase (128MB → 512MB)
- ✅ **Clean Architecture**: Runtime package building, no committed artifacts

### v1.x (Legacy)
- Basic backup functionality with Node.js 12.x
- Limited monitoring and broad IAM permissions
- Pre-built Lambda packages committed to repository

## 🤝 Contributing

Contributions are welcome! Please:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Test** your changes thoroughly
4. **Update** documentation as needed
5. **Submit** a pull request

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
git commit -m "Add amazing feature"
git push origin feature/your-feature-name
```

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## ⭐ If this module helped you, please consider giving it a star on GitHub!

**Questions or Issues?** Please open an [issue](https://github.com/mikmorley/terraform-aws-ec2-backup/issues) on GitHub.