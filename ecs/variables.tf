variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "db_seed_image" {
  type        = string
  description = "ECR image URI for the DB seed task"
}

variable "network_state_bucket" {
  type        = string
  description = "S3 bucket for network state"
}

variable "network_state_key" {
  type        = string
  description = "S3 key for network state"
}
variable "rds_state_bucket" {
  type        = string
  description = "S3 bucket for rds-mssql state"
}

variable "rds_state_key" {
  type        = string
  description = "S3 key for rds-mssql state"
}
variable "backend_image" {
  type        = string
  description = "ECR image URI for backend"
}
