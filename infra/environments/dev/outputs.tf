output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_master_user_secret_arn" {
  value     = module.rds.master_user_secret_arn
  sensitive = true
}

output "ecr_repository_names" {
  description = "Names of the application ECR repositories"
  value       = module.ecr.repository_names
}

output "ecr_repository_urls" {
  description = "URLs of the application ECR repositories"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "ARNs of the application ECR repositories"
  value       = module.ecr.repository_arns
}

output "github_actions_ecr_role_arn" {
  description = "IAM role assumed by GitHub Actions for ECR publishing"
  value       = module.github_oidc.role_arn
}
