output "repository_names" {
  description = "Names of the ECR repositories"
  value = {
    for key, repository in aws_ecr_repository.this :
    key => repository.name
  }
}

output "repository_urls" {
  description = "URLs of the ECR repositories"
  value = {
    for key, repository in aws_ecr_repository.this :
    key => repository.repository_url
  }
}

output "repository_arns" {
  description = "ARNs of the ECR repositories"
  value = {
    for key, repository in aws_ecr_repository.this :
    key => repository.arn
  }
}
