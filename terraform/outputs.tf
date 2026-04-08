output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "intra_subnet_ids" {
  description = "Intra subnet IDs (RDS, ElastiCache)"
  value       = module.vpc.intra_subnet_ids
}

output "transit_gateway_id" {
  description = "Transit Gateway ID (null if not created in this region)"
  value       = module.vpc.transit_gateway_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS private API endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN — use this to create IRSA roles for workloads"
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_provider_url" {
  description = "OIDC provider URL"
  value       = module.eks.oidc_provider_url
}

output "ecr_repository_url" {
  description = "ECR repository URL for event-ingestion"
  value       = aws_ecr_repository.event_ingestion.repository_url
}

output "event_ingestion_role_arn" {
  description = "IRSA role ARN for event-ingestion pods"
  value       = aws_iam_role.event_ingestion.arn
}

output "app_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions app deployments"
  value       = aws_iam_role.app_deploy.arn
}
