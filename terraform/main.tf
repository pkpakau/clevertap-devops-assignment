locals {
  name = "clevertap-${var.environment}"
}

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  name        = local.name
  environment = var.environment
  region      = var.region

  cidr            = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  intra_subnets   = var.intra_subnets

  # Transit Gateway — hub & spoke across regions
  # Hub region (us-east-1) creates the TGW; other regions attach to it
  enable_tgw            = var.enable_tgw
  tgw_id                = var.tgw_id
  enable_tgw_attachment = var.enable_tgw_attachment

  # Flow logs lifecycle
  flow_logs_retention_days = 30
  flow_logs_glacier_days   = 90
  flow_logs_expiry_days    = 365
}

# ─────────────────────────────────────────
# EKS Cluster
# ─────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name    = local.name
  cluster_version = var.cluster_version
  environment     = var.environment
  region          = var.region

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  node_groups = var.node_groups

  # Allow VPC CIDR to reach private API server endpoint
  allowed_cidr_blocks = concat([var.vpc_cidr], var.allowed_cidr_blocks)
}
