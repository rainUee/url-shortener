# 生成随机后缀用于全局唯一的桶名
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

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