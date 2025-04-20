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