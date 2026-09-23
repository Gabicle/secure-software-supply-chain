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
