variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS cluster and worker nodes"
  type        = list(string)
}

variable "cluster_role_boundary_arn" {
  description = "Permissions boundary ARN for the EKS cluster IAM role"
  type        = string
}

variable "node_role_boundary_arn" {
  description = "Permissions boundary ARN for the EKS worker node IAM role"
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types used by the EKS managed node group"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}