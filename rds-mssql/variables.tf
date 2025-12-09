variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "network_state_bucket" {
  type        = string
  description = "S3 bucket for network state"
}

variable "network_state_key" {
  type        = string
  description = "S3 key for network state"
}

variable "db_name" {
  type    = string
  default = "StudentsDB"
}

variable "db_user" {
  type    = string
  default = "students_admin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "publicly_accessible" {
  type    = bool
  default = false
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "engine_version" {
  type    = string
  default = "15.00.4236.7.v1"
}

variable "sql_file" {
  type    = string
  default = "init/students_seed.sql"
}

variable "ecs_state_bucket" {
  type        = string
  description = "S3 bucket storing ECS state"
}

variable "ecs_state_key" {
  type        = string
  description = "S3 path/key for ECS state"
}
