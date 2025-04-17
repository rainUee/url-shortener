#!/bin/bash

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REPO_NAME="url-shortener-admin"

# Login to ECR
echo "--------Logging in to ECR--------"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
echo "--------Logged in to ECR--------"

# Build Docker image
echo "--------Building Docker image--------"
docker buildx build --platform linux/amd64 -t "$ECR_REPO_NAME:latest" --load .
echo "--------Docker image built--------"

# Tag image
echo "--------Tagging Docker image--------"
docker tag $ECR_REPO_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest
echo "--------Docker image tagged--------"
# Push image to ECR
echo "--------Pushing Docker image to ECR--------"
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest
echo "--------Docker image pushed to ECR--------"

echo "Docker image has been built and pushed to ECR successfully!"