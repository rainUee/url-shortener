#!/bin/bash

# Exit on error
set -e

echo "Creating Lambda function packages..."

# Create directories for each Lambda function
mkdir -p lambda-create
mkdir -p lambda-redirect
mkdir -p lambda-statistics

# Copy Lambda function files to respective directories
cp create.js lambda-create/
cp redirect.js lambda-redirect/
cp statistics.js lambda-statistics/

# Create package.json files for each Lambda function
cat > lambda-create/package.json << EOL
{
  "name": "url-shortener-create",
  "version": "1.0.0",
  "description": "Lambda function to create short URLs",
  "main": "create.js",
  "dependencies": {
    "aws-sdk": "^2.1099.0"
  }
}
EOL

cat > lambda-redirect/package.json << EOL
{
  "name": "url-shortener-redirect",
  "version": "1.0.0",
  "description": "Lambda function to redirect short URLs",
  "main": "redirect.js",
  "dependencies": {
    "aws-sdk": "^2.1099.0"
  }
}
EOL

cat > lambda-statistics/package.json << EOL
{
  "name": "url-shortener-statistics",
  "version": "1.0.0",
  "description": "Lambda function to process URL statistics",
  "main": "statistics.js",
  "dependencies": {
    "aws-sdk": "^2.1099.0"
  }
}
EOL

# Install dependencies for each Lambda function
echo "Installing dependencies for Lambda functions..."

cd lambda-create
npm install --production
cd ..

cd lambda-redirect
npm install --production
cd ..

cd lambda-statistics
npm install --production
cd ..

# Create ZIP files for each Lambda function
echo "Creating ZIP files for Lambda functions..."

# Create URL Lambda
cd lambda-create
zip -r ../lambda-create.zip .
cd ..

# Redirect URL Lambda
cd lambda-redirect
zip -r ../lambda-redirect.zip .
cd ..

# Statistics Lambda
cd lambda-statistics
zip -r ../lambda-statistics.zip .
cd ..

# Create S3 bucket for frontend
# echo "Creating S3 bucket for frontend..."
# aws s3 mb s3://url-shortener-frontend --region us-east-1 || true

BUCKET_NAME="url-shortener-frontend-shiyu"
REGION="us-east-1"

echo "Checking if S3 bucket '$BUCKET_NAME' exists..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket '$BUCKET_NAME' already exists. Skipping creation."
else
  echo "Creating S3 bucket '$BUCKET_NAME'..."
  aws s3 mb s3://"$BUCKET_NAME" --region "$REGION"
fi

# Upload frontend files to S3
echo "Uploading frontend files to S3..."
aws s3 cp index.html s3://url-shortener-frontend-shiyu/

# Set bucket policy for website hosting
cat > bucket-policy.json << EOL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPublicReadWrite",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::url-shortener-frontend-shiyu",
        "arn:aws:s3:::url-shortener-frontend-shiyu/*"
      ]    
    }
  ]
}
EOL

aws s3api put-bucket-policy --bucket url-shortener-frontend-shiyu --policy file://bucket-policy.json

# Enable website hosting for the bucket
aws s3 website s3://url-shortener-frontend-shiyu/ --index-document index.html

echo "Cleaning up temporary files..."
rm -rf lambda-create
rm -rf lambda-redirect
rm -rf lambda-statistics
rm bucket-policy.json

echo "Package creation complete!"
echo "Lambda function ZIP files are ready for deployment."
echo "Frontend files have been uploaded to S3."
echo "You can now run 'terraform apply' to deploy the infrastructure."