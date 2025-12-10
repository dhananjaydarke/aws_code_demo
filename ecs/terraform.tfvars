aws_region    = "us-east-1"
db_seed_image = "803947795681.dkr.ecr.us-east-1.amazonaws.com/students-db-seed:latest"

network_state_bucket = "djuni-terraform-state"
network_state_key    = "network/terraform.tfstate"

rds_state_bucket = "djuni-terraform-state"
rds_state_key    = "rds-mssql/terraform.tfstate"

backend_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/students-backend:latest"
