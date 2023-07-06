variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "timeout" {
  type    = number
  default = 60
}

variable "backup_tag" {
  type        = string
  default     = "Backup"
  description = "The EC2 Instance Tag that will be checked for the 'yes' value, to backup."
}

variable "backup_retention" {
  type        = number
  default     = 30
  description = "The number of days a backup will be kept."
}

variable "schedule_expression" {
  description = "Scheduling expression for triggering the Lambda Function using CloudWatch events. For example, cron(0 20 * * ? *) or rate(5 minutes)."
}