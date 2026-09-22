variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "cluster_role_boundary_arn" {
  type      = string
  sensitive = true
}

variable "node_role_boundary_arn" {
  type      = string
  sensitive = true
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_desired_size" {
  type = number
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "postgres_version" {
  type = string
}

variable "rds_instance_class" {
  type = string
}

variable "rds_allocated_storage" {
  type = number
}

variable "rds_max_allocated_storage" {
  type = number
}

variable "database_name" {
  type = string
}

variable "database_username" {
  type = string
}

variable "terraform_execution_role_arn" {
  description = "IAM role assumed by Terraform when provisioning AWS resources"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}