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
    key            = "rds-mssql/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "djuni-terraform-locks"
  }
}
data "http" "myip" {
  url = "https://ifconfig.me/ip"
}
locals {
  my_ip_cidr = "${chomp(data.http.myip.response_body)}/32"
}

provider "aws" {
  region = var.aws_region
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = var.aws_region
  }
}

resource "aws_db_subnet_group" "mssql_subnets" {
  name       = "students-mssql-subnets"
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}

resource "aws_security_group" "rds_sg" {
  name        = "students-rds-mssql-sg"
  description = "Allow SQL Server access"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr]
    #cidr_blocks = [ "47.185.187.194/32" ]
    #cidr_blocks = [local.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
data "terraform_remote_state" "ecs" {
  backend = "s3"
  config = {
    bucket = var.ecs_state_bucket
    key    = var.ecs_state_key
    region = var.aws_region
  }
}

resource "aws_security_group_rule" "allow_ecs_to_rds" {
  type                     = "ingress"
  from_port                = 1433
  to_port                  = 1433
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = data.terraform_remote_state.ecs.outputs.ecs_sg_id
}

resource "aws_db_instance" "mssql" {
  identifier             = "students-mssql-db"
  engine                 = "sqlserver-ex"
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  username               = var.db_user
  password               = var.db_password
  port                   = 1433
  multi_az               = false
  skip_final_snapshot    = true
  deletion_protection    = false
  publicly_accessible    = var.publicly_accessible
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.mssql_subnets.name
}
/*
resource "null_resource" "init_students" {
  depends_on = [aws_db_instance.mssql]

  provisioner "local-exec" {
    command = "sqlcmd -S tcp:${aws_db_instance.mssql.address} -U ${var.db_user} -P \"${var.db_password}\" -d ${var.db_name} -i ${var.sql_file}"
  }
}
        --task-definition ${data.terraform_remote_state.ecs.outputs.db_seed_task_def_arn} \
*/
# One-time DB initialization - runs ECS Fargate db-seed task
resource "null_resource" "init_students" {
  depends_on = [
    aws_db_instance.mssql,
    aws_security_group_rule.allow_ecs_to_rds
  ]

  # If DB instance is recreated, this will rerun
  triggers = {
    db_instance_id = aws_db_instance.mssql.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]

    command = <<-EOT
      echo "Starting ECS DB seed task against RDS..."

      aws ecs run-task \
        --cluster ${data.terraform_remote_state.ecs.outputs.ecs_cluster_arn} \
        --launch-type FARGATE \
        --network-configuration 'awsvpcConfiguration={
          "subnets": ${jsonencode(data.terraform_remote_state.network.outputs.private_subnet_ids)},
          "securityGroups": ["${data.terraform_remote_state.ecs.outputs.ecs_tasks_sg_id}"],
          "assignPublicIp": "DISABLED"
        }' \
        --region ${var.aws_region}

      echo "DB seed task launched."
    EOT
  }
}




output "db_endpoint" {
  value = aws_db_instance.mssql.address
}

output "db_name" {
  value = var.db_name
}

output "db_user" {
  value = var.db_user
}

output "db_password" {
  value     = var.db_password
  sensitive = true
}

output "db_port" {
  value = 1433
}
output "rds_sg_id" {
  value = aws_security_group.rds_sg.id
}
