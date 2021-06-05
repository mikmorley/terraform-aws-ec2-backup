# aws-terraform-scheduled-ec2-ami-backup-automation
Custom terraform module to deploy scheduled EC2 AMI backup automation.

### Usage

```
module "ami_scheduled_backup" {
  source = "git::https://github.com/mikmorley/aws-terraform-scheduled-ec2-ami-backup-automation.git"

  name                = var.name
  environment         = var.environment
  region              = var.region
  backup_tag          = var.backup_tag
  backup_retention    = var.backup_retention
  schedule_expression = var.cron_expressions
}
```

### Expected Variables

|Variable|Description|
|---|---|
|`name`|_Required_, The name of the function and group of resources, e.g. _ec2-scheduled-backup_|
|`environment`|_Required_, For tagging of created resources, e.g. dev, staging, production etc|
|`region`|_Required_, Appended to resource names, to allow for multi-region deployment|
|`timeout`|_Optional_, The timeout period for the lambda execution (defaults to 60 seconds)|
|`backup_tag`|_Optional_, Specify the tag that will be assigned to EC2 instances that are to be backed up (defaults to _Backup_). **Note:** The Tag value **must** be set to **yes** in order for the backup to be created.|
|`backup_retention`|_Optional_, Specify the number of days to keep the AMI and Snapshots (Defaults to 30).|
|`schedule_expression`|_Required_, Scheduling expression for triggering the Lambda Function using CloudWatch events. For example, cron(0 20 ** ** ? **) or rate(5 minutes).|

- **name**: _Required_, The name of the function and group of resources, e.g. _ec2-scheduled-backup_
- **environment**: _Required_, For tagging of created resources, e.g. dev, staging, production etc
- **region**: _Required_, Appended to resource names, to allow for multi-region deployment
- **timeout**: _Optional_, The timeout period for the lambda execution (defaults to 60 seconds)
- **backup_tag**: _Optional_, Specify the tag that will be assigned to EC2 instances that are to be backed up (defaults to _Backup_). **Note:** The Tag value **must** be set to **yes** in order for the backup to be created.
- **backup_retention**: _Optional_, Specify the number of days to keep the AMI and Snapshots (Defaults to 30).
- **schedule_expression**: _Required_, Scheduling expression for triggering the Lambda Function using CloudWatch events. For example, cron(0 20 ** ** ? **) or rate(5 minutes).