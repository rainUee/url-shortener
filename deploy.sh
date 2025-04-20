#!/bin/bash
set -e

deploy_admin_service() {
    echo "-------- Starting Admin Service Deployment --------"
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION="us-east-1"
    ECR_REPO_NAME="url-shortener-admin"

    # Check if ECR repository exists
    if ! aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" &>/dev/null; then
        echo "ERROR: ECR repository '$ECR_REPO_NAME' does not exist. Run infra deployment first!"
        exit 1
    fi

    echo "-------- Logging in to ECR --------"
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

    echo "-------- Building Docker image --------"
    docker buildx build --platform linux/amd64 -t "$ECR_REPO_NAME:latest" -f ./admin-service/Dockerfile ./admin-service --load

    echo "-------- Tagging and pushing to ECR --------"
    docker tag $ECR_REPO_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest

    echo "Admin Service deployed to ECR successfully!"
}

deploy_infrastructure() {
    echo "-------- Starting Infrastructure Deployment --------"

    # Prepare Lambda ZIPs in the terraform directory
    echo "Preparing Lambda functions in terraform/ directory..."
    mkdir -p terraform/lambda-create terraform/lambda-redirect terraform/lambda-statistics

    # Copy Lambda code and dependencies
    cp create.js terraform/lambda-create/
    cp redirect.js terraform/lambda-redirect/
    cp statistics.js terraform/lambda-statistics/

    # Create package.json files
    cat > terraform/lambda-create/package.json <<EOL
{
  "name": "url-shortener-create",
  "version": "1.0.0",
  "dependencies": {
    "aws-sdk": "^2.1099.0"
  }
}
EOL

    cat > terraform/lambda-redirect/package.json <<EOL
{
  "name": "url-shortener-redirect",
  "version": "1.0.0",
  "dependencies": {
    "aws-sdk": "^2.1099.0"
  }
}
EOL

    cat > terraform/lambda-statistics/package.json <<EOL
{
  "name": "url-shortener-statistics",
  "version": "1.0.0",
  "dependencies": {
    "aws-sdk": "^2.1099.0"
  }
}
EOL

    # Install dependencies and create ZIPs
    echo "Building Lambda ZIP files..."
    cd terraform/lambda-create && npm install --production && zip -r ../lambda-create.zip . && cd ../..
    cd terraform/lambda-redirect && npm install --production && zip -r ../lambda-redirect.zip . && cd ../..
    cd terraform/lambda-statistics && npm install --production && zip -r ../lambda-statistics.zip . && cd ../..

    # Run Terraform
    echo "Initializing and applying Terraform..."
    cd terraform
    terraform init
    terraform apply -auto-approve

    # Get outputs
    API_URL=$(terraform output -raw api_gateway_url)
    FRONTEND_URL=$(terraform output -raw frontend_url)
    S3_BUCKET_NAME=$(echo "$FRONTEND_URL" | sed -E 's|http://([^\.]+)\..*|\1|')

    # Deploy frontend
    echo "Deploying frontend to S3..."
    cd ..
    sed -i.bak "s|YOUR_API_GATEWAY_URL|$API_URL|g" index.html
    aws s3 cp index.html s3://$S3_BUCKET_NAME/ --acl public-read

    # Cleanup
    echo "Cleaning up..."
    rm -rf terraform/lambda-* terraform/lambda-*.zip index.html.bak

    echo "Infrastructure deployed successfully!"
    echo "API Gateway URL: $API_URL"
    echo "Frontend URL: $FRONTEND_URL"
}

main() {
    echo "========================================"
    echo " URL Shortener Full Deployment Script "
    echo "========================================"
    
    # 强制先部署 infra，再部署 admin
    if [ "$1" == "admin" ]; then
        deploy_admin_service
    elif [ "$1" == "infra" ]; then
        deploy_infrastructure
    else
        # 默认顺序：先 infra，后 admin
        deploy_infrastructure
        deploy_admin_service
    fi
}

main "$@"