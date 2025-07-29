variable "name" {
  type        = string
  description = "The name of the function and group of resources"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,62}$", var.name))
    error_message = "The name must start with a letter, contain only alphanumeric characters and hyphens, and be 2-63 characters long."
  }
}

variable "environment" {
  type        = string
  description = "For tagging of created resources, e.g. dev, staging, production"
  
  validation {
    condition     = contains(["dev", "test", "staging", "prod", "production"], lower(var.environment))
    error_message = "Environment must be one of: dev, test, staging, prod, production."
  }
}

variable "region" {
  type        = string
  description = "AWS region for resource deployment"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1, eu-west-1)."
  }
}

variable "timeout" {
  type        = number
  default     = 60
  description = "The timeout period for the lambda execution in seconds"
  
  validation {
    condition     = var.timeout >= 15 && var.timeout <= 900
    error_message = "Timeout must be between 15 and 900 seconds (15 minutes)."
  }
}

variable "backup_tag" {
  type        = string
  default     = "Backup"
  description = "The EC2 Instance Tag that will be checked for the 'yes' value, to backup."
  
  validation {
    condition     = length(var.backup_tag) > 0 && length(var.backup_tag) <= 128
    error_message = "Backup tag must be between 1 and 128 characters."
  }
}

variable "backup_retention" {
  type        = number
  default     = 30
  description = "The number of days a backup will be kept."
  
  validation {
    condition     = var.backup_retention >= 1 && var.backup_retention <= 365
    error_message = "Backup retention must be between 1 and 365 days."
  }
}

variable "schedule_expression" {
  description = "Scheduling expression for triggering the Lambda Function using CloudWatch events. For example, cron(0 20 * * ? *) or rate(5 minutes)."
}

variable "default_tags" {
  description = "Optional default tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_monitoring" {
  description = "Enable CloudWatch alarms and monitoring"
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "Optional SNS topic ARN for backup failure notifications"
  type        = string
  default     = ""
}

variable "create_sns_topic" {
  description = "Create an SNS topic for notifications if sns_topic_arn is not provided"
  type        = bool
  default     = false
}

variable "notification_email" {
  description = "Email address for backup notifications (only used if create_sns_topic is true)"
  type        = string
  default     = ""
  
  validation {
    condition = var.notification_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "The notification_email must be a valid email address."
  }
}

variable "cost_center" {
  description = "Cost center for resource allocation and billing"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Name of the project for resource organization"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner of the resources for accountability"
  type        = string
  default     = ""
}
