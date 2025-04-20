provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}