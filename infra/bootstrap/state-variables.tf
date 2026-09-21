variable "aws_region" {
  description = "AWS region containing the Terraform state bucket"
  type        = string
  default     = "eu-west-3"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket used for Terraform state"
  type        = string
}