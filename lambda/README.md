# aws-terraform-scheduled-ec2-ami-backup-lambda

## Manual (Re)Build of Lambda Package

```
echo "Removing any cached node_modules"
rm -rf ./lambda/node_modules

echo "Installing NPM dependencies"
cd ./lambda && npm install && cd ..

echo "Removing original archive"
rm ./zip/lambda_function.zip

echo "Creating updated archive"
cd ./lambda && zip -r ../zip/lambda_function.zip .
```