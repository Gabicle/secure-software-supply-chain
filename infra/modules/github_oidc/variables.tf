variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the CI role"
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the GitHub Actions role may push to"
  type        = list(string)
}

variable "github_owner_id" {
  description = "Immutable GitHub repository owner ID"
  type        = string
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID"
  type        = string
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary ARN for the GitHub Actions ECR role"
  type        = string
}
