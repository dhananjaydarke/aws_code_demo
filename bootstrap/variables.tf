variable "aws_region" {
  type        = string
  description = "AWS region for the backend resources"
  default     = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "Name of the Terraform state S3 bucket"
  default     = "djuni-terraform-state"
}

variable "lock_table_name" {
  type        = string
  description = "Name of the DynamoDB table for state locking"
  default     = "djuni-terraform-locks"
}
