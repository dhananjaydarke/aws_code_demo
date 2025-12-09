terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "djuni-terraform-state"
    key            = "ecs/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "djuni-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region # should be us-east-1
}

resource "aws_ecr_repository" "backend_repo" {
  name                 = "students-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_lifecycle_policy" "backend_repo_policy" {
  repository = aws_ecr_repository.backend_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 30 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = var.aws_region
  }
}
data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket = var.rds_state_bucket
    key    = var.rds_state_key
    region = var.aws_region
  }
}

# Security group for ECS tasks
resource "aws_security_group" "ecs_sg" {
  name   = "students-ecs-sg"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  # Allow traffic from within the VPC on backend port (NLB -> ECS)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # or output vpc_cidr if you have it
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "students" {
  name = "students-cluster"
}

data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "students-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "students-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

# NLB (still named backend_alb for state compatibility, but it's a Network Load Balancer)
resource "aws_lb" "backend_alb" {
  name               = "students-backend-nlb"
  load_balancer_type = "network"
  internal           = false
  subnets            = data.terraform_remote_state.network.outputs.private_subnet_ids
  # NLBs do NOT use security groups, so no "security_groups" here
}

resource "aws_lb_target_group" "backend_tg" {
  name        = "students-backend-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  target_type = "ip" //ECS

  health_check {
    protocol            = "TCP"
    port                = "8080"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    //interval            = 30
    //timeout             = 10
  }
  /*
  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
*/

}


resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = aws_lb.backend_alb.arn
  port              = 80
  protocol          = "TCP" # NLB = TCP, not HTTP

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}
resource "aws_cloudwatch_log_group" "ecs_backend" {
  name              = "/ecs/students-backend"
  retention_in_days = 7
}
resource "aws_ecs_task_definition" "backend_task" {
  family                   = "students-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn


  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/students-backend"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "DB_HOST", value = data.terraform_remote_state.rds.outputs.db_endpoint },
        { name = "DB_PORT", value = tostring(data.terraform_remote_state.rds.outputs.db_port) },
        { name = "DB_NAME", value = data.terraform_remote_state.rds.outputs.db_name },
        { name = "DB_USER", value = data.terraform_remote_state.rds.outputs.db_user },
        { name = "DB_PASSWORD", value = data.terraform_remote_state.rds.outputs.db_password }
      ]
    }
  ])
}

resource "aws_ecs_service" "backend_service" {
  name            = "students-backend-service"
  cluster         = aws_ecs_cluster.students.id
  task_definition = aws_ecs_task_definition.backend_task.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets          = data.terraform_remote_state.network.outputs.private_subnet_ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false

  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "backend"
    container_port   = 8080
  }
  depends_on = [
    aws_lb_listener.backend_listener
  ]
  lifecycle {
    ignore_changes = [desired_count]
  }
}
# Log group for db seed task
resource "aws_cloudwatch_log_group" "db_seed_logs" {
  name              = "/ecs/students-db-seed"
  retention_in_days = 7
}
# Task definition for DB seed
/*
resource "aws_ecs_task_definition" "db_seed_task" {
  family                   = "students-db-seed"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "db-seed"
      image     = "mcr.microsoft.com/mssql-tools" # public image, no ECR needed
      essential = true

      environment = [
        { name = "DB_HOST", value = data.terraform_remote_state.rds.outputs.db_endpoint },
        { name = "DB_PORT", value = tostring(data.terraform_remote_state.rds.outputs.db_port) },
        { name = "DB_NAME", value = data.terraform_remote_state.rds.outputs.db_name },
        { name = "DB_USER", value = data.terraform_remote_state.rds.outputs.db_user },
        { name = "DB_PASSWORD", value = data.terraform_remote_state.rds.outputs.db_password }
      ]

      mountPoints = []
      command = [
        "/bin/sh",
        "-c",
        "/opt/mssql-tools/bin/sqlcmd -S $DB_HOST,$DB_PORT -U $DB_USER -P $DB_PASSWORD -d $DB_NAME -i /app/students_seed.sql"
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.db_seed_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "db-seed"
        }
      }
    }
  ])

  # Use an EFS or baked image for the SQL file; simplest is bake into a custom image.
}
*/
resource "aws_cloudwatch_log_group" "db_fetch_logs" {
  name              = "/ecs/students-db-fetch"
  retention_in_days = 7
}
resource "aws_ecs_task_definition" "db_fetch_task" {
  family                   = "students-db-fetch"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "db-fetch"
      image     = "437147519305.dkr.ecr.us-east-1.amazonaws.com/students-db-poller:latest"
      essential = true

      environment = [
        { name = "DB_HOST", value = data.terraform_remote_state.rds.outputs.db_endpoint },
        { name = "DB_PORT", value = tostring(data.terraform_remote_state.rds.outputs.db_port) },
        { name = "DB_NAME", value = data.terraform_remote_state.rds.outputs.db_name },
        { name = "DB_USER", value = data.terraform_remote_state.rds.outputs.db_user },
        { name = "DB_PASSWORD", value = data.terraform_remote_state.rds.outputs.db_password }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.db_fetch_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "db-fetch"
        }
      }
    }
  ])
}

# IAM Role for EventBridge to run ECS tasks
resource "aws_iam_role" "events_run_task_role" {
  name = "students-events-run-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy" "events_run_task_policy" {
  role = aws_iam_role.events_run_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks"
        ]
        Resource = [
          aws_ecs_task_definition.db_fetch_task.arn
        ]
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

# Every 5 minutes
resource "aws_cloudwatch_event_rule" "db_fetch_schedule" {
  name                = "students-db-fetch-every-5-min"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "db_fetch_target" {
  rule      = aws_cloudwatch_event_rule.db_fetch_schedule.name
  target_id = "students-db-fetch-task"

  arn      = aws_ecs_cluster.students.arn
  role_arn = aws_iam_role.events_run_task_role.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.db_fetch_task.arn
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = data.terraform_remote_state.network.outputs.private_subnet_ids
      security_groups  = [aws_security_group.ecs_sg.id]
      assign_public_ip = "false"
    }
  }
}

output "backend_alb_dns_name" {
  value = aws_lb.backend_alb.dns_name # This is now the NLB DNS name
}

output "backend_repo_url" {
  value = aws_ecr_repository.backend_repo.repository_url
}

output "ecs_sg_id" {
  value = aws_security_group.ecs_sg.id
}

output "backend_alb_arn" {
  value = aws_lb.backend_alb.arn # This is now the NLB ARN
}
output "ecs_cluster_arn" {
  value = aws_ecs_cluster.students.arn
}

output "ecs_tasks_sg_id" {
  value = aws_security_group.ecs_sg.id
}
output "db_seed_task_def_arn" {
  value = aws_ecs_task_definition.db_seed_task.arn
}
