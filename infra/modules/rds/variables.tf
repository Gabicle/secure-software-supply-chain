variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC containing the database"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the RDS subnet group"
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "Security group permitted to connect to PostgreSQL"
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL engine version"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Initial database storage in GiB"
  type        = number
}

variable "max_allocated_storage" {
  description = "Maximum storage autoscaling limit in GiB"
  type        = number
}

variable "database_name" {
  description = "Initial PostgreSQL database name"
  type        = string
}

variable "database_username" {
  description = "PostgreSQL master username"
  type        = string
}

variable "multi_az" {
  description = "Whether the database uses a Multi-AZ deployment"
  type        = bool
}

variable "backup_retention_days" {
  description = "Number of days automated backups are retained"
  type        = number
}

variable "deletion_protection" {
  description = "Protect the database from accidental deletion"
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot when destroying the database"
  type        = bool
}