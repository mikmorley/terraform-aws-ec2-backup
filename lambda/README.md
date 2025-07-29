# terraform-aws-ec2-backup Lambda Function

## Automated Build Process

**Note**: As of the latest version, Lambda packages are built automatically at runtime during Terraform deployment. The zip file is no longer committed to the repository.

## Manual (Re)Build of Lambda Package (Development)

For development and testing purposes, you can manually rebuild the Lambda package:

```bash
#!/bin/bash

echo "Removing any cached node_modules and old zip"
rm -rf ./lambda/node_modules
rm -f ./zip/lambda_function.zip

echo "Installing production dependencies only"
cd ./lambda && npm ci --omit=dev && cd ..

echo "Creating updated archive (excluding dev dependencies and test files)"
if command -v zip >/dev/null 2>&1; then
    cd ./lambda && zip -r ../zip/lambda_function.zip . -x "*.git*" "*.DS_Store*" "node_modules/.cache/*" "*.test.js" "test.js" "**/test/**" "**/tests/**" && cd ..
else
    cd ./lambda && find . -name "*.test.js" -delete && find . -name "test.js" -delete
    cd ./lambda && python3 -m zipfile -c ../zip/lambda_function.zip . && cd ..
fi

echo "Lambda package rebuilt successfully"
ls -lh ./zip/lambda_function.zip
```

## Runtime Build Process

During Terraform deployment, the Lambda package is built using the `terraform_data` resource with these steps:

1. Create isolated build directory in `.terraform/lambda-build`
2. Copy source files to build directory
3. Install production dependencies only (`npm ci --omit=dev`)
4. Create deployment package excluding development files
5. Clean up build directory (keeping source clean)
6. Calculate source code hash for change detection

**Benefits:**
- No zip files committed to repository
- Source directory remains clean
- Fresh build on every deployment
- Production dependencies only