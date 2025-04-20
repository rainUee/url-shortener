output "api_gateway_url" {
  value = "${aws_api_gateway_deployment.url_shortener_deployment.invoke_url}"
}

output "frontend_url" {
  value = "http://${aws_s3_bucket.frontend_bucket.bucket}.s3-website-${var.region}.amazonaws.com"
}