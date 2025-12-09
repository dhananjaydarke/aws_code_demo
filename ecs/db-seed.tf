#############################################
# DB SEEDER - ECS ONE-SHOT TASK
#############################################

# Security group for the DB seeder task
resource "aws_security_group" "db_seed_sg" {
  name   = "students-db-seed-sg"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  # Seeder needs outbound access to RDS
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow DB Seeder to reach SQL Server on port 1433
resource "aws_security_group_rule" "allow_seed_to_rds" {
  type                     = "ingress"
  from_port                = 1433
  to_port                  = 1433
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.rds.outputs.rds_sg_id
  source_security_group_id = aws_security_group.db_seed_sg.id
}

#############################################
# ECS TASK DEFINITION FOR DB SEED
#############################################

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
      image     = var.db_seed_image # ECR image
      essential = true

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

#############################################
# RUN TASK ONE TIME USING NULL_RESOURCE
#############################################
/*
resource "null_resource" "run_db_seed" {
  triggers = {
    seed_version = "v1"
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = @"
aws ecs run-task --cluster ${aws_ecs_cluster.students.id} --launch-type FARGATE --task-definition ${aws_ecs_task_definition.db_seed_task.arn} --network-configuration \"awsvpcConfiguration={subnets=[${join(",", data.terraform_remote_state.network.outputs.private_subnet_ids)}],securityGroups=[${aws_security_group.db_seed_sg.id}],assignPublicIp=DISABLED}\" --region ${var.aws_region}
"@
  }
}
*/
resource "null_resource" "run_db_seed" {
  triggers = {
    seed_version = "v1"
  }

  provisioner "local-exec" {
    //interpreter = ["/bin/bash", "-c"]
    command = <<EOF

aws ecs run-task \
  --cluster ${aws_ecs_cluster.students.id} \
  --launch-type FARGATE \
  --task-definition ${aws_ecs_task_definition.db_seed_task.arn} \
  --network-configuration '{
    "awsvpcConfiguration": {
      "subnets": ${jsonencode(data.terraform_remote_state.network.outputs.private_subnet_ids)},
      "securityGroups": ["${aws_security_group.db_seed_sg.id}"],
      "assignPublicIp": "DISABLED"
    }
  }' \
  --region ${var.aws_region}

EOF
  }
}



#############################################
# OUTPUTS (OPTIONAL)
#############################################

output "db_seed_task_arn" {
  value = aws_ecs_task_definition.db_seed_task.arn
}

output "db_seed_sg_id" {
  value = aws_security_group.db_seed_sg.id
}


output "task_definition" {
  value = aws_ecs_task_definition.db_seed_task.arn
}
