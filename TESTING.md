# Testing Guide

This document describes the CI pipeline and local testing for the `terraform-aws-ec2-backup` module.

## CI/CD Pipeline Overview

The GitHub Actions workflow (`terraform-lint.yml`) runs on:
- Pushes to `main` or `develop`
- Pull requests targeting `main` or `develop`

## Test Stages

### 1. Terraform Validation
Checks Terraform syntax and formatting.

- **Format check**: `terraform fmt`
- **Initialization**: module initializes without errors
- **Validation**: configuration syntax and logic
- **PR comments**: validation results post to the pull request

### 2. Lambda Function Testing
Checks the Lambda code.

- **Dependencies**: installs NPM packages
- **ESLint**: style and quality checks with the repo configuration
- **Syntax check**: `node -c`
- **Unit tests**: mock-based tests with AWS SDK v3 mocks
- **Security audit**: `npm audit`

### 3. Security Scanning
Finds security and compliance issues.

- **tfsec**: Terraform security scanning
- **Checkov**: Infrastructure as Code security analysis
- **Soft fail**: findings are reported but do not block the build

### 4. Terraform Plan Test
Checks that the module plans cleanly.

- **Test configuration**: builds a realistic module usage example
- **Plan generation**: runs `terraform plan` without AWS credentials
- **PR comments**: posts the plan output for review
- **Resource validation**: confirms all resources can be planned

### 5. Documentation Validation
Checks the docs.

- **Required sections**: usage documentation is present
- **Link validation**: basic check of external links
- **Changelog**: checks for version tracking

### 6. Final Status Check
Combines all results into one pass or fail.

- Fails if Terraform validation or Lambda testing fails
- Warns on security or documentation issues
- Passes when all critical checks succeed

## Local Testing

### Prerequisites
```bash
# Required tools
terraform --version  # >= 1.0
node --version       # >= 20
npm --version        # >= 9

# Optional security tools
brew install tfsec   # macOS
# or
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

### Run Tests Locally

#### Terraform Tests
```bash
# Format check
terraform fmt -check -recursive

# Initialize and validate
terraform init -backend=false
terraform validate

# Security scan
tfsec .
```

#### Lambda Tests
```bash
cd lambda/

# Install dependencies
npm ci

# Run linter
npm install eslint --save-dev
npx eslint . --ext .js

# Syntax check
node -c index.js

# Security audit
npm audit --audit-level high
```

#### Integration Test
```bash
# Create test configuration
cat > test-config.tf << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
}

module "test_ec2_backup" {
  source = "./"

  name                = "test-backup"
  environment         = "test"
  region              = "us-east-1"
  schedule_expression = "cron(0 2 * * ? *)"
}
EOF

# Test plan
terraform init
terraform plan
```

## Test Results

### Pull Request Comments
The pipeline posts comments on pull requests with:

- **Terraform validation results**: format, init, and validation status
- **Terraform plan output**: the full resource plan
- **Test summary**: overall pipeline status and any issues

### Status Badges
The README includes a badge for the pipeline status:
```markdown
[![CI/CD Pipeline](https://github.com/mikmorley/terraform-aws-ec2-backup/actions/workflows/terraform-lint.yml/badge.svg)](https://github.com/mikmorley/terraform-aws-ec2-backup/actions/workflows/terraform-lint.yml)
```

## Troubleshooting

**Terraform format failures**:
```bash
# Fix formatting
terraform fmt -recursive
git add .
git commit -m "Fix Terraform formatting"
```

**Lambda ESLint errors**:
```bash
cd lambda/
npx eslint . --ext .js --fix
git add .
git commit -m "Fix ESLint issues"
```

**Security scan failures**:
- Read the tfsec and Checkov output
- Change the configuration to address the finding
- For false positives, add an ignore comment

**Terraform plan failures**:
- Check the variable validation rules
- Confirm the test configuration sets all required variables
- Check resource compatibility

## Future Work

- Integration tests against real AWS resources in a test account
- Performance tests for the Lambda function
- Generated documentation
- Release automation with semantic versioning
