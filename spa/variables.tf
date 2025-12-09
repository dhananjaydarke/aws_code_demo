variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "students_subdomain" {
  type = string
}

variable "hosted_zones_state_bucket" {
  type = string
}

variable "hosted_zones_state_key" {
  type = string
}

variable "network_state_bucket" {
  type = string
}

variable "network_state_key" {
  type = string
}

variable "ecs_state_bucket" {
  type = string
}

variable "ecs_state_key" {
  type = string
}
