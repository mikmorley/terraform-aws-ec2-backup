# Testing Guide

This document describes the comprehensive CI/CD pipeline and testing strategy for the `terraform-aws-ec2-backup` module.

## 🚀 CI/CD Pipeline Overview

The GitHub Actions workflow (`terraform-lint.yml`) runs automatically on:
- **Push** to `main` or `develop` branches
- **Pull Requests** targeting `main` or `develop` branches

## 🧪 Test Stages

### 1. Terraform Validation
**Purpose**: Ensures Terraform code quality and syntax correctness

**Checks**:
- ✅ **Format Check**: Validates consistent code formatting (`terraform fmt`)
- ✅ **Initialization**: Tests module initialization without errors
- ✅ **Validation**: Verifies configuration syntax and logic
- ✅ **PR Comments**: Posts validation results directly in pull requests

### 2. Lambda Function Testing  
**Purpose**: Validates Lambda function code quality and functionality

**Checks**:
- ✅ **Dependencies**: Installs and validates NPM packages
- ✅ **ESLint**: Code style and quality checks with custom configuration
- ✅ **Syntax Check**: Node.js syntax validation (`node -c`)
- ✅ **Unit Tests**: Mock-based testing with AWS SDK v3 mocks
- ✅ **Security Audit**: NPM vulnerability scanning (`npm audit`)

### 3. Security Scanning
**Purpose**: Identifies security vulnerabilities and compliance issues

**Tools**:
- ✅ **tfsec**: Terraform security scanning
- ✅ **Checkov**: Infrastructure as Code security analysis
- ✅ **Soft Fail**: Security issues reported but don't block deployment

### 4. Terraform Plan Test
**Purpose**: Validates deployment feasibility and resource planning

**Process**:
- ✅ **Test Configuration**: Creates realistic module usage example
- ✅ **Plan Generation**: Runs `terraform plan` without AWS credentials
- ✅ **PR Comments**: Posts plan output for review
- ✅ **Resource Validation**: Ensures all resources can be created

### 5. Documentation Validation
**Purpose**: Ensures documentation quality and completeness

**Checks**:
- ✅ **Required Sections**: Validates presence of usage documentation
- ✅ **Link Validation**: Basic check for external links
- ✅ **Changelog**: Encourages version tracking best practices

### 6. Final Status Check
**Purpose**: Aggregates all test results and provides final pass/fail status

**Logic**:
- ❌ **Fails** if Terraform validation or Lambda testing fails
- ⚠️ **Warns** for security or documentation issues
- ✅ **Passes** when all critical checks succeed

## 🔧 Local Testing

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

## 📊 Test Results

### Pull Request Comments
The pipeline automatically posts detailed comments on pull requests with:

- **Terraform Validation Results**: Format, init, and validation status
- **Terraform Plan Output**: Complete resource planning details
- **Test Summary**: Overall pipeline status and any issues

### Status Badges
The README includes a status badge showing the current pipeline status:
```markdown
[![CI/CD Pipeline](https://github.com/mikmorley/terraform-aws-ec2-backup/actions/workflows/terraform-lint.yml/badge.svg)](https://github.com/mikmorley/terraform-aws-ec2-backup/actions/workflows/terraform-lint.yml)
```

## 🚨 Troubleshooting

### Common Issues

**Terraform Format Failures**:
```bash
# Fix formatting
terraform fmt -recursive
git add .
git commit -m "Fix Terraform formatting"
```

**Lambda ESLint Errors**:
```bash
cd lambda/
npx eslint . --ext .js --fix
git add .
git commit -m "Fix ESLint issues"
```

**Security Scan Failures**:
- Review tfsec and Checkov output
- Update configuration to address security concerns
- For false positives, add appropriate ignore comments

**Terraform Plan Failures**:
- Check variable validation rules
- Ensure all required variables are provided in test configuration
- Verify resource compatibility

## 🔄 Continuous Improvement

The testing pipeline is designed to evolve with the module:

- **New Features**: Add corresponding tests
- **Security Updates**: Integrate new scanning tools
- **Performance**: Monitor test execution times
- **Coverage**: Expand test scenarios as needed

### Future Enhancements
- Integration testing with real AWS resources (using test accounts)
- Performance testing for Lambda functions
- Automated documentation generation
- Release automation with semantic versioning