#!/bin/bash

# 出错时退出
set -e

echo "开始 URL 短链接生成器应用部署..."

# 更新 Lambda 函数的文件
echo "准备 Lambda 函数..."

# 创建目录
mkdir -p lambda-create
mkdir -p lambda-redirect
mkdir -p lambda-statistics

# 复制代码到各自目录
cp create.js lambda-create/
cp redirect.js lambda-redirect/
cp statistics.js lambda-statistics/

# 创建 package.json
cat > lambda-create/package.json << EOL
{
  "name": "url-shortener-create",
  "version": "1.0.0",
  "description": "Lambda 函数用于创建短链接",
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
  "description": "Lambda 函数用于重定向短链接",
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
  "description": "Lambda 函数用于处理访问统计",
  "main": "statistics.js",
  "dependencies": {
    "aws-sdk": "^2.1099.0"
  }
}
EOL

# 安装依赖
echo "安装 Lambda 函数依赖..."
cd lambda-create && npm install --production && cd ..
cd lambda-redirect && npm install --production && cd ..
cd lambda-statistics && npm install --production && cd ..

# 创建 ZIP 文件
echo "创建 Lambda 函数 ZIP 文件..."
cd lambda-create && zip -r ../lambda-create.zip . && cd ..
cd lambda-redirect && zip -r ../lambda-redirect.zip . && cd ..
cd lambda-statistics && zip -r ../lambda-statistics.zip . && cd ..

# 初始化 Terraform
echo "初始化 Terraform..."
terraform init

# 应用 Terraform 配置
echo "应用 Terraform 配置..."
terraform apply -auto-approve

# 获取输出
echo "获取 API Gateway URL 和 S3 前端 URL..."
API_URL=$(terraform output -raw api_gateway_url)
FRONTEND_URL=$(terraform output -raw frontend_url)
S3_BUCKET_NAME=$(echo $FRONTEND_URL | sed -E 's|http://([^\.]+)\..*|\1|')

# 更新前端 HTML 文件中的 API 端点
echo "更新前端 HTML 中的 API 端点..."
sed -i.bak "s|YOUR_API_GATEWAY_URL|$API_URL|g" index.html

# 上传前端文件到 S3
echo "上传前端文件到 S3..."
aws s3 cp index.html s3://$S3_BUCKET_NAME/ --acl public-read

# 清理临时文件
echo "清理临时文件..."
rm -rf lambda-create lambda-redirect lambda-statistics
rm -f index.html.bak

echo ""
echo "URL 短链接生成器部署完成！"
echo "----------------------------------------"
echo "API Gateway URL: $API_URL"
echo "前端 URL: $FRONTEND_URL"
echo ""
echo "要测试短链接生成器，请访问: $FRONTEND_URL"
echo "----------------------------------------"