provider "aws" {
  region = "us-east-1"
}

# 生成随机后缀用于全局唯一的桶名
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# DynamoDB 表用于 URL 映射
resource "aws_dynamodb_table" "url_shortener_table" {
  name           = "url-shortener-mappings"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "short_code"

  attribute {
    name = "short_code"
    type = "S"
  }

  tags = {
    Name        = "url-shortener-dynamodb-table"
    Environment = "production"
  }
}

# 创建 SQS 队列用于 URL 统计
resource "aws_sqs_queue" "url_stats_queue" {
  name                      = "url-statistics-queue"
  delay_seconds             = 0
  message_retention_seconds = 86400  # 1 天
  visibility_timeout_seconds = 30
  
  tags = {
    Environment = "production"
  }
}

# 获取当前 AWS 账户 ID
data "aws_caller_identity" "current" {}

# Lambda 函数用于创建短 URL - 使用 LabRole
resource "aws_lambda_function" "create_short_url" {
  filename      = "lambda-create.zip"
  function_name = "url-shortener-create"
  role          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  handler       = "create.handler"
  runtime       = "nodejs16.x"
  timeout       = 10

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.url_shortener_table.name,
      # 使用 API Gateway URL 作为基础 URL
      BASE_URL       = "https://${aws_api_gateway_rest_api.url_shortener_api.id}.execute-api.${var.region}.amazonaws.com/dev"
      FRONTEND_DOMAIN = "${aws_s3_bucket.frontend_bucket.bucket}.s3-website-${var.region}.amazonaws.com"
    }
  }
}

# Lambda 函数用于重定向到原始 URL - 使用 LabRole
resource "aws_lambda_function" "redirect_url" {
  filename      = "lambda-redirect.zip"
  function_name = "url-shortener-redirect"
  role          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  handler       = "redirect.handler"
  runtime       = "nodejs16.x"
  timeout       = 10

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.url_shortener_table.name,
      STATS_QUEUE    = aws_sqs_queue.url_stats_queue.url
      FRONTEND_DOMAIN = "${aws_s3_bucket.frontend_bucket.bucket}.s3-website-${var.region}.amazonaws.com"
    }
  }
}

# Lambda 函数用于处理统计 - 使用 LabRole
resource "aws_lambda_function" "process_statistics" {
  filename      = "lambda-statistics.zip"
  function_name = "url-shortener-statistics"
  role          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  handler       = "statistics.handler"
  runtime       = "nodejs16.x"
  timeout       = 30

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.url_shortener_table.name
    }
  }
}

# 连接 SQS 到 Statistics Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.url_stats_queue.arn
  function_name    = aws_lambda_function.process_statistics.function_name
  batch_size       = 10
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "url_shortener_api" {
  name        = "url-shortener-api"
  description = "URL Shortener API"
}

# API Gateway Resource 用于缩短 URL
resource "aws_api_gateway_resource" "shorten" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  parent_id   = aws_api_gateway_rest_api.url_shortener_api.root_resource_id
  path_part   = "shorten"
}

# API Gateway Method 用于缩短 URL
resource "aws_api_gateway_method" "shorten_post" {
  rest_api_id   = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id   = aws_api_gateway_resource.shorten.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration 与 Lambda 集成用于缩短
resource "aws_api_gateway_integration" "shorten_lambda" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.shorten.id
  http_method = aws_api_gateway_method.shorten_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_short_url.invoke_arn
}

# API Gateway Resource 用于重定向
resource "aws_api_gateway_resource" "short_code" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  parent_id   = aws_api_gateway_rest_api.url_shortener_api.root_resource_id
  path_part   = "{shortCode}"
}

# API Gateway Method 用于重定向
resource "aws_api_gateway_method" "redirect_get" {
  rest_api_id   = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id   = aws_api_gateway_resource.short_code.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.shortCode" = true
  }
}

# API Gateway Integration 与 Lambda 集成用于重定向
resource "aws_api_gateway_integration" "redirect_lambda" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.short_code.id
  http_method = aws_api_gateway_method.redirect_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.redirect_url.invoke_arn
}

# Lambda 权限用于 API Gateway
resource "aws_lambda_permission" "api_gateway_create" {
  statement_id  = "AllowAPIGatewayInvokeCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_short_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.url_shortener_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_redirect" {
  statement_id  = "AllowAPIGatewayInvokeRedirect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redirect_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.url_shortener_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "url_shortener_deployment" {
  depends_on = [
    aws_api_gateway_integration.shorten_lambda,
    aws_api_gateway_integration.redirect_lambda
  ]

  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  stage_name  = "dev"
  
  # 添加生命周期以避免替换问题
  lifecycle {
    create_before_destroy = true
  }
}

# 添加 CORS 支持
resource "aws_api_gateway_method" "shorten_options" {
  rest_api_id   = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id   = aws_api_gateway_resource.shorten.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "shorten_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.shorten.id
  http_method = aws_api_gateway_method.shorten_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "shorten_options_200" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.shorten.id
  http_method = aws_api_gateway_method.shorten_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "shorten_post_200" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.shorten.id
  http_method = aws_api_gateway_method.shorten_post.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "shorten_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.shorten.id
  http_method = aws_api_gateway_method.shorten_options.http_method
  status_code = aws_api_gateway_method_response.shorten_options_200.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin" = "'http://${aws_s3_bucket.frontend_bucket.bucket}.s3-website-${var.region}.amazonaws.com'"
  }
}

# 同样为短码资源添加 CORS
resource "aws_api_gateway_method" "short_code_options" {
  rest_api_id   = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id   = aws_api_gateway_resource.short_code.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "short_code_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.short_code.id
  http_method = aws_api_gateway_method.short_code_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "short_code_options_200" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.short_code.id
  http_method = aws_api_gateway_method.short_code_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "short_code_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.short_code.id
  http_method = aws_api_gateway_method.short_code_options.http_method
  status_code = aws_api_gateway_method_response.short_code_options_200.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

# S3 bucket 用于前端 - 使用随机后缀避免命名冲突
resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "url-shortener-frontend-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# 启用 S3 网站托管功能
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }
}

# 设置桶的公共访问权限
resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 设置桶的 ACL 为公共读取
resource "aws_s3_bucket_ownership_controls" "frontend_ownership" {
  bucket = aws_s3_bucket.frontend_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_cors_configuration" "frontend_cors" {
  bucket = aws_s3_bucket.frontend_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_acl" "frontend_acl" {
  depends_on = [
    aws_s3_bucket_public_access_block.frontend_public_access,
    aws_s3_bucket_ownership_controls.frontend_ownership,
  ]

  bucket = aws_s3_bucket.frontend_bucket.id
  acl    = "public-read"
}

# 输出值
output "api_gateway_url" {
  value = "${aws_api_gateway_deployment.url_shortener_deployment.invoke_url}"
}

output "frontend_url" {
  value = "http://${aws_s3_bucket.frontend_bucket.bucket}.s3-website-${var.region}.amazonaws.com"
}

# 变量
variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

# ECR Repository
resource "aws_ecr_repository" "admin_repo" {
  name = "url-shortener-admin"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "url-shortener-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "admin_service" {
  family                   = "url-shortener-admin"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 256
  memory                  = 512
  execution_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  task_role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  container_definitions = jsonencode([
    {
      name  = "admin-service"
      image = "${aws_ecr_repository.admin_repo.repository_url}:latest"
      
      environment = [
        {
          name  = "DYNAMODB_TABLE"
          value = aws_dynamodb_table.url_shortener_table.name
        }
      ]
      
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.admin_service.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "admin_service" {
  name            = "url-shortener-admin"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.admin_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = aws_subnet.private[*].id  # 使用私有子网
    security_groups  = [aws_security_group.admin_service.id]
    assign_public_ip = false  # 不需要公网IP
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.admin.arn
    container_name   = "admin-service"
    container_port   = 3000
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "admin_service" {
  name              = "/ecs/url-shortener-admin"
  retention_in_days = 7
}

# Security Group
resource "aws_security_group" "admin_service" {
  name        = "url-shortener-admin-service"
  description = "Security group for admin service"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.alb.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "url-shortener-vpc"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "url-shortener-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  map_public_ip_on_launch = true
  
  tags = {
    Name = "url-shortener-public-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "url-shortener-igw"
  }
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}


