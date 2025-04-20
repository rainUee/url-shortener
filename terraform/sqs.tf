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