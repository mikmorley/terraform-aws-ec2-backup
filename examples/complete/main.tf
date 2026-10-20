terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Custom backup tag, shorter retention, alarms with email notifications, and cost tags.
module "ec2_backup" {
  source = "../.."

  name                = "prod-backup"
  environment         = "production"
  region              = "us-east-1"
  schedule_expression = "cron(0 2 * * ? *)"

  backup_tag       = "AutoBackup"
  backup_retention = 7
  timeout          = 300

  enable_monitoring  = true
  create_sns_topic   = true
  notification_email = "alerts@example.com"

  cost_center  = "Infrastructure"
  project_name = "Production-Backups"
  owner        = "DevOps-Team"

  default_tags = {
    Team = "platform"
  }
}

output "lambda_function_arn" {
  value = module.ec2_backup.lambda_function_arn
}

output "sns_topic_arn" {
  value = module.ec2_backup.sns_topic_arn
}

output "dead_letter_queue_url" {
  value = module.ec2_backup.dead_letter_queue_url
}
