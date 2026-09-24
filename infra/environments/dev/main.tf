module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr = var.vpc_cidr

  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  vpc_flow_logs_role_boundary_arn = var.vpc_flow_logs_role_boundary_arn
}

module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  kubernetes_version = var.kubernetes_version

  private_subnet_ids = module.vpc.private_subnet_ids

  cluster_admin_role_arn    = var.eks_cluster_admin_role_arn
  cluster_role_boundary_arn = var.cluster_role_boundary_arn
  node_role_boundary_arn    = var.node_role_boundary_arn

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

module "rds" {
  source = "../../modules/rds"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  eks_node_security_group_id = module.eks.cluster_security_group_id

  postgres_version      = var.postgres_version
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage

  database_name     = var.database_name
  database_username = var.database_username

  multi_az              = false
  backup_retention_days = 7
  deletion_protection   = true
  skip_final_snapshot   = true

  rds_monitoring_role_boundary_arn = var.rds_monitoring_role_boundary_arn
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "github_oidc" {
  source = "../../modules/github_oidc"

  github_owner         = "Gabicle"
  github_repository    = "secure-software-supply-chain"
  github_branch        = "main"
  github_owner_id      = "49395894"
  github_repository_id = "1383990768"

  ecr_repository_arns      = values(module.ecr.repository_arns)
  permissions_boundary_arn = "arn:aws:iam::542489916995:policy/SecureSupplyChainGitHubActionsEcrRoleBoundary"
}

data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "external_secrets" {
  name                 = "${var.project_name}-${var.environment}-external-secrets"
  assume_role_policy   = data.aws_iam_policy_document.external_secrets_assume_role.json
  permissions_boundary = var.external_secrets_role_boundary_arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "external-secrets"
  }
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid    = "ReadRdsMasterSecret"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      module.rds.master_user_secret_arn
    ]
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "${var.project_name}-${var.environment}-external-secrets"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn

  depends_on = [
    module.eks
  ]
}