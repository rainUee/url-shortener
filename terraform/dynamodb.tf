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