# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-01-29

### 🚀 Major Changes
- **BREAKING**: Renamed module from `terraform-aws-scheduled-ec2-ami-backup-automation` to `terraform-aws-ec2-backup`
- **BREAKING**: Updated module source path to `mikmorley/ec2-backup/aws` for Terraform Registry
- **BREAKING**: Increased minimum Terraform version requirement to 1.0+

### ✨ Added
- **Enhanced Security**: Implemented least-privilege IAM policies with scoped permissions
- **Advanced Monitoring**: Added 8 custom CloudWatch metrics for comprehensive observability
- **Reliability Features**: Added Dead Letter Queue (DLQ) and X-Ray tracing support
- **SNS Notifications**: Optional email alerts for backup failures and issues
- **CloudWatch Alarms**: Automated monitoring for Lambda errors, duration, and throttling
- **Input Validation**: Comprehensive variable validation with meaningful error messages
- **Enhanced Tagging**: Support for cost center, project, and owner tags
- **CI/CD Pipeline**: Complete GitHub Actions workflow with testing and security scanning

### 🔧 Changed
- **Runtime Upgrade**: Updated Lambda from Node.js 12.x (deprecated) to Node.js 20.x LTS
- **AWS SDK Migration**: Migrated from AWS SDK v2 to v3 for 75% smaller bundle size
- **Performance**: Increased Lambda memory from 128MB to 512MB (4x improvement)
- **Build Process**: Implemented runtime Lambda package building (no committed artifacts)
- **Module Structure**: Cleaner organization with enhanced documentation

### 🛡️ Security
- **IAM Hardening**: Replaced broad `"*"` permissions with resource-specific ARNs
- **Conditional Access**: Added IAM conditions for backup-tagged resources only
- **Region Scoping**: Limited operations to current AWS account and region
- **Deletion Protection**: Can only delete resources created by this backup system

### 📚 Documentation
- **Complete Rewrite**: Modernized README.md with comprehensive examples
- **Usage Guide**: Added quick start and advanced configuration examples
- **Troubleshooting**: Added common issues and resolution steps
- **Security Guide**: Documented security features and best practices

### 🔧 Infrastructure
- **Testing**: Added automated testing with Lambda function validation
- **Security Scanning**: Integrated tfsec and Checkov security scanning
- **Code Quality**: Added ESLint configuration for Lambda function
- **Terraform Validation**: Automated format checking and plan validation

## [1.x] - Legacy

### Features
- Basic AMI backup functionality
- CloudWatch Events scheduling
- Simple IAM permissions
- Node.js 12.x runtime
- AWS SDK v2

---

## Migration Guide from v1.x to v2.0

### Required Changes

1. **Update Module Source**:
   ```hcl
   # Old
   source = "git::https://github.com/mikmorley/terraform-aws-scheduled-ec2-ami-backup-automation.git?ref=v1.1.0"
   
   # New  
   source = "mikmorley/ec2-backup/aws"
   version = "~> 2.0"
   ```

2. **Update Module Name**:
   ```hcl
   # Old
   module "ami_scheduled_backup" {
   
   # New
   module "ec2_backup" {
   ```

3. **Review Variable Changes**:
   - Environment values now validated (must be: dev, test, staging, prod, production)
   - Region format validated (must match AWS region pattern)
   - Timeout range enforced (15-900 seconds)
   - Backup retention range enforced (1-365 days)

### Optional Enhancements

4. **Enable Enhanced Monitoring** (Recommended):
   ```hcl
   enable_monitoring   = true
   create_sns_topic    = true
   notification_email  = "alerts@company.com"
   ```

5. **Add Enhanced Tagging**:
   ```hcl
   cost_center    = "Infrastructure"
   project_name   = "Production-Backups" 
   owner          = "DevOps-Team"
   ```

### Breaking Changes
- Module name and source path changed
- Some variable validation added (may reject previously accepted values)
- IAM permissions more restrictive (may need policy updates if using custom roles)