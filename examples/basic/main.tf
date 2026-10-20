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

# Backs up every instance tagged Backup=yes once a day and keeps AMIs for 30 days.
module "ec2_backup" {
  source = "../.."

  name                = "basic-backup"
  environment         = "dev"
  region              = "us-east-1"
  schedule_expression = "cron(0 2 * * ? *)"
}

output "lambda_function_name" {
  value = module.ec2_backup.lambda_function_name
}
