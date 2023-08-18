[![terraform-lint](https://github.com/mikmorley/aws-terraform-scheduled-ec2-ami-backup-automation/actions/workflows/terraform-lint.yml/badge.svg)](https://github.com/mikmorley/aws-terraform-scheduled-ec2-ami-backup-automation/actions/workflows/terraform-lint.yml)

# aws-terraform-scheduled-ec2-ami-backup-automation

The **aws-terraform-scheduled-ec2-ami-backup-automation** module is a customizable Terraform solution designed to automate scheduled backups of Amazon EC2 instances, providing a seamless way to safeguard your data and system configurations. This module simplifies the process of creating and managing automated backup workflows for your EC2 resources, ensuring data resilience and streamlined disaster recovery.

## Purpose

Managing regular backups of your Amazon EC2 instances is a critical aspect of maintaining data integrity and system availability. However, setting up and managing these backups can be complex and time-consuming. The **aws-terraform-scheduled-ec2-ami-backup-automation** module streamlines this process by offering a versatile and configurable solution that allows you to:

- Automate the creation of Amazon Machine Images (AMIs) and associated snapshots at scheduled intervals.
- Specify backup retention policies to control the number of days AMIs and snapshots are retained.
- Define custom scheduling expressions using CloudWatch Events, enabling you to choose when backups occur.
- Apply default tags to all resources created by the module, ensuring proper organization and resource tracking.
- Enable selective backup of EC2 instances using user-defined tags, ensuring only tagged instances are backed up.

With its user-friendly configuration and seamless integration into your existing infrastructure, this module empowers you to focus on more critical tasks while maintaining robust backup practices. By implementing this solution, you can enhance your disaster recovery capabilities and ensure your EC2 instances are well-protected against unforeseen incidents.

## Module Usage

To incorporate the **aws-terraform-scheduled-ec2-ami-backup-automation** module into your Terraform infrastructure, follow these steps:

- **Module Configuration:** Specify the module configuration by utilizing the module block.
```terraform
module "ami_scheduled_backup" {
  source = "git::https://github.com/mikmorley/aws-terraform-scheduled-ec2-ami-backup-automation.git?ref=v1.1.0"

  name                = var.name
  environment         = var.environment
  region              = var.region
  backup_tag          = var.backup_tag
  backup_retention    = var.backup_retention
  schedule_expression = var.cron_expressions
  default_tags        = var.default_tags
}
```
- **Customize the Configuration:** Adjust the module configuration to match your desired backup settings and scheduling expressions. Modify variables such as `backup_tag`, `backup_retention`, and `schedule_expression` to meet your specific needs.
- **Tag Instances for Backup:** For instances that you want to include in the backup process, add a tag with the specified `backup_tag` and a value of `yes`.

Once deployed, add the value specified as `backup_tag` to the EC2 resources to be backed up using this process. **For Example:** If the `backup_tag` is _Backup-AZ-A_, add a new Tag to the EC2 Instances with the _key_:_value_ of _Backup-AZ-A_:_yes_ (**Note:** The Tag value **must** be set to **yes** in order for the backup to be created).
- **Verify Backups:** Once the module is operational, verify that the scheduled backups are occurring as intended in your AWS environment.

By following these steps, you can easily integrate the module into your Terraform workflow and automate the creation of scheduled EC2 AMI backups. This solution enhances your data protection strategy and simplifies the management of backup processes, ultimately contributing to the reliability and resilience of your infrastructure.

## Dependencies and Prerequisites

Before you begin using the **aws-terraform-scheduled-ec2-ami-backup-automation** module, ensure that you have the following dependencies and prerequisites in place:

1. **Terraform Installed:** Ensure you have Terraform installed on your local machine or the environment where you intend to use this module. You can download and install Terraform from the official [Terraform website](https://www.terraform.io/downloads.html).
2. **AWS Credentials:** To deploy resources using this module, you need valid AWS credentials configured on your system. Ensure you have AWS access key and secret key information set up either through environment variables, the AWS CLI configuration, or an AWS credentials file.
3. **IAM Permissions:** Make sure that the AWS IAM user or role associated with your credentials has the necessary permissions to create and manage EC2 instances, Lambda functions, CloudWatch Events, and related resources.

## Example Module Usage

To illustrate how the **aws-terraform-scheduled-ec2-ami-backup-automation** module can be used, consider the following example:

Suppose you want to create a scheduled backup solution for your production EC2 instances in the `us-east-1` region. You want to back up instances with the `Backup-AZ-A` tag and retain the backups for `7 days`. The backups should be scheduled to occur at `8:00pm UTC daily`.

```terraform
module "ami_scheduled_backup" {
  source = "git::https://github.com/mikmorley/aws-terraform-scheduled-ec2-ami-backup-automation.git?ref=v1.1.0"

  name                = "ami-backups-az-a"
  environment         = "Production"
  region              = "us-east-1"
  backup_tag          = "Backup-AZ-A"
  backup_retention    = 7 # Keep seven days of backs (AMIs & Snapshots)
  schedule_expression = "cron(0 20 * * ? *)" # Backup at 8:00pm UTC Daily

  default_tags = {
    Owner = "Cloud Engineering"
  }
}
```

In this example, the module is configured to create automated backups for instances tagged with `Backup-AZ-A`. The backup process retains AMIs and snapshots for `7 days` and is scheduled to run at `8:00pm UTC daily`. The instance backups will be labeled with the environment tag `Production`, and additional default tags will be applied to resources to ensure proper tracking.

Adapt this example to fit your environment, tagging strategy, and backup retention requirements. With the provided flexibility, you can easily tailor the module's configuration to meet the backup needs of your infrastructure.

## Expected Variables

To effectively configure and utilize the **aws-terraform-scheduled-ec2-ami-backup-automation** module, you need to provide values for the following variables:

|Variable|Description|
|---|---|
|`name`|_Required_, The name of the function and group of resources, e.g. _ec2-scheduled-backup_|
|`environment`|_Required_, For tagging of created resources, e.g. dev, staging, production etc|
|`region`|_Required_, Appended to resource names, to allow for multi-region deployment|
|`timeout`|_Optional_, The timeout period for the lambda execution (defaults to 60 seconds)|
|`backup_tag`|_Optional_, Specify the tag that will be assigned to EC2 instances that are to be backed up (defaults to _Backup_). **Note:** The Tag value **must** be set to **yes** in order for the backup to be created.|
|`backup_retention`|_Optional_, Specify the number of days to keep the AMI and Snapshots (Defaults to 30).|
|`schedule_expression`|_Required_, Scheduling expression for triggering the Lambda Function using CloudWatch events. For example, cron(0 20 * * ? *) or rate(5 minutes).|
|`default_tags`|_Optional_, default tags to be applied to all resources.|

## Tagging Guidelines

Tagging plays a crucial role in the operation of the **aws-terraform-scheduled-ec2-ami-backup-automation** module. To ensure successful backup automation, follow these guidelines when applying tags to your EC2 instances:

- **Backup Tag:** Specify the tag that will be assigned to EC2 instances you want to include in the backup process. The `backup_tag` variable is used to filter instances for backup. **By default, the tag value is set to "Backup"**. However, you can customize this value to match your tagging strategy.
- **Tag Value:** For instances that are to be backed up, set the value of the specified `backup_tag` to `yes`. This tag value acts as a signal to the module that the instance should be included in the backup automation process. Instances without this tag value will not be backed up.

For instance, if your `backup_tag` is set to "*Backup-AZ-A*", add a new tag to the EC2 instances with the `key:value` pair of "`Backup-AZ-A:yes`". Ensure that the tag value is exactly "`yes`" to trigger the backup process for that instance.

Example:

```
Key         Value
----------- -----
Backup-AZ-A yes
```

By adhering to these tagging guidelines, you can effectively select and manage the instances that require automated backups, ensuring your critical data is protected and easily recoverable.

## Examples for Schedule Expressions

The `schedule_expression` variable allows you to define when the backup process should be triggered using CloudWatch Events. Here are a few examples of schedule expressions you can use:

- Backup Daily at 8:00 PM UTC: `cron(0 20 * * ? *)`
- Backup Every 6 Hours: `rate(6 hours)`
- Backup Every Weekday at 10:00 AM UTC: `cron(0 10 ? * MON-FRI *)`
- Backup Every 30 Minutes: `rate(30 minutes)`

Adapt these expressions to your preferred backup schedule. The `schedule_expression` format follows the AWS CloudWatch Events cron or rate syntax.

## Contributing Guidelines

Contributions to the **aws-terraform-scheduled-ec2-ami-backup-automation** module are welcome and encouraged! If you'd like to contribute, please follow these guidelines:

1. Fork the repository to your GitHub account.
2. Create a new branch for your changes.
3. Make your enhancements, bug fixes, or other improvements.
4. Ensure that your changes are well-documented, including any necessary updates to the README.
5. Commit your changes and push them to your fork.
6. Open a pull request against the `main` branch of the original repository.

Please ensure that your contributions align with the module's scope and purpose. By contributing to this project, you help make it more valuable to the community.

## License Information

The **aws-terraform-scheduled-ec2-ami-backup-automation** module is distributed under the MIT License. Feel free to use and modify this module according to your needs. You can find the complete license text in the LICENSE file.

By using this module, you agree to the terms and conditions outlined in the MIT License.