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
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.admin_service.id]
    assign_public_ip = false
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