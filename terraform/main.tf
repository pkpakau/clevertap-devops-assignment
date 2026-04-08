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

# ─────────────────────────────────────────
# EKS Add-ons
# Installed after cluster is ready:
#   ALB Controller, Cluster Autoscaler, Node Termination Handler,
#   External Secrets Operator, Argo Rollouts, Prometheus+Grafana
# ─────────────────────────────────────────
module "eks_addons" {
  source = "./modules/eks-addons"

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_ca_certificate
  oidc_provider_arn      = module.eks.oidc_provider_arn
  oidc_provider_url      = module.eks.oidc_provider_url

  region         = var.region
  environment    = var.environment
  aws_account_id = var.aws_account_id
  vpc_id         = module.vpc.vpc_id

  prometheus_retention_days = var.prometheus_retention_days

  depends_on = [module.eks]
}
