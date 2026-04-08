locals {
  common_tags = merge(
    {
      Name        = var.name
      Environment = var.environment
      Region      = var.region
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${var.name}-vpc" })
}

# ─────────────────────────────────────────
# Internet Gateway (for public subnets)
# ─────────────────────────────────────────
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-igw" })
}

# ─────────────────────────────────────────
# Public Subnets
# ─────────────────────────────────────────
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                     = "${var.name}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────
# NAT Gateways (one per AZ for HA)
# ─────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = length(var.public_subnets)
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.name}-nat-eip-${var.azs[count.index]}" })
}

resource "aws_nat_gateway" "this" {
  count         = length(var.public_subnets)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(local.common_tags, { Name = "${var.name}-nat-${var.azs[count.index]}" })

  depends_on = [aws_internet_gateway.this]
}

# ─────────────────────────────────────────
# Private Subnets (EKS worker nodes)
# ─────────────────────────────────────────
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, {
    Name                              = "${var.name}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-private-rt-${var.azs[count.index]}" })
}

resource "aws_route" "private_nat" {
  count                  = length(var.private_subnets)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ─────────────────────────────────────────
# Intra Subnets (RDS, ElastiCache — no internet)
# ─────────────────────────────────────────
resource "aws_subnet" "intra" {
  count = length(var.intra_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.intra_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.name}-intra-${var.azs[count.index]}"
  })
}

resource "aws_route_table" "intra" {
  vpc_id = aws_vpc.this.id
  # No routes — fully isolated, no internet, no NAT
  tags = merge(local.common_tags, { Name = "${var.name}-intra-rt" })
}

resource "aws_route_table_association" "intra" {
  count          = length(aws_subnet.intra)
  subnet_id      = aws_subnet.intra[count.index].id
  route_table_id = aws_route_table.intra.id
}

# ─────────────────────────────────────────
# Transit Gateway (hub & spoke — scales better than VPC peering)
# TGW is created here only when this is the "hub" region.
# Other regions attach to this TGW via enable_tgw_attachment = true.
# ─────────────────────────────────────────
resource "aws_ec2_transit_gateway" "this" {
  count = var.enable_tgw ? 1 : 0

  description                     = "${var.name} Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments  = "disable"

  tags = merge(local.common_tags, { Name = "${var.name}-tgw" })
}

# Attach this VPC to the TGW (either newly created or existing)
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count = var.enable_tgw || var.enable_tgw_attachment ? 1 : 0

  transit_gateway_id = var.enable_tgw ? aws_ec2_transit_gateway.this[0].id : var.tgw_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = aws_subnet.private[*].id

  tags = merge(local.common_tags, { Name = "${var.name}-tgw-attachment" })
}

# Add TGW route to private route tables so cross-region traffic flows through TGW
resource "aws_route" "private_tgw" {
  count = (var.enable_tgw || var.enable_tgw_attachment) ? length(var.private_subnets) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = var.enable_tgw ? aws_ec2_transit_gateway.this[0].id : var.tgw_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# ─────────────────────────────────────────
# VPC Flow Logs → S3 with lifecycle policy
# ─────────────────────────────────────────
resource "aws_s3_bucket" "flow_logs" {
  bucket        = "${var.name}-vpc-flow-logs-${var.region}"
  force_destroy = var.environment != "prod"

  tags = merge(local.common_tags, { Name = "${var.name}-vpc-flow-logs" })
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  bucket                  = aws_s3_bucket.flow_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    id     = "flow-logs-lifecycle"
    status = "Enabled"

    transition {
      days          = var.flow_logs_retention_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.flow_logs_expiry_days
    }
  }
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = "${aws_s3_bucket.flow_logs.arn}/flow-logs/"

  log_destination_type = "s3"
  log_format           = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status}"

  tags = merge(local.common_tags, { Name = "${var.name}-flow-log" })
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.name}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetBucketAcl"
      ]
      Resource = [
        aws_s3_bucket.flow_logs.arn,
        "${aws_s3_bucket.flow_logs.arn}/*"
      ]
    }]
  })
}
