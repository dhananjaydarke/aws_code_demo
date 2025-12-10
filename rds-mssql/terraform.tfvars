aws_region           = "us-east-1"
network_state_bucket = "djuni-terraform-state"
network_state_key    = "network/terraform.tfstate"

db_name     = "StudentsDB"
db_user     = "students_admin"
db_password = "students_admin123$"

publicly_accessible = false
instance_class      = "db.t3.small"
allocated_storage   = 20
engine_version      = "15.00.4236.7.v1"

sql_file         = "init/students_seed.sql"
ecs_state_bucket = "djuni-terraform-state"
ecs_state_key    = "ecs/terraform.tfstate"
