output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs — use for EKS node groups"
  value       = aws_subnet.private[*].id
}

output "intra_subnet_ids" {
  description = "List of intra subnet IDs — use for RDS, ElastiCache"
  value       = aws_subnet.intra[*].id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID (null if enable_tgw = false)"
  value       = var.enable_tgw ? aws_ec2_transit_gateway.this[0].id : null
}

output "flow_logs_bucket" {
  description = "S3 bucket name for VPC flow logs"
  value       = aws_s3_bucket.flow_logs.bucket
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}
