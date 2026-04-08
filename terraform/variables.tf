# ─────────────────────────────────────────
# Common
# ─────────────────────────────────────────
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "aws_account_id" {
  description = "Target AWS account ID"
  type        = string
}

variable "cost_center" {
  description = "Cost center tag for billing allocation"
  type        = string
  default     = "platform"
}

variable "team" {
  description = "Owning team tag"
  type        = string
  default     = "devops"
}

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets (EKS nodes)"
  type        = list(string)
}

variable "intra_subnets" {
  description = "CIDR blocks for intra subnets (RDS, ElastiCache)"
  type        = list(string)
}

variable "enable_tgw" {
  description = "Create a Transit Gateway in this region (set true for hub region only)"
  type        = bool
  default     = false
}

variable "tgw_id" {
  description = "Existing Transit Gateway ID to attach to (for non-hub regions)"
  type        = string
  default     = null
}

variable "enable_tgw_attachment" {
  description = "Attach VPC to an existing TGW (for non-hub regions)"
  type        = bool
  default     = false
}

# ─────────────────────────────────────────
# EKS
# ─────────────────────────────────────────
variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_groups" {
  description = "Node group configurations — supports mixed On-Demand and Spot"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size_gb   = optional(number, 50)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
}

variable "allowed_cidr_blocks" {
  description = "CIDRs allowed to reach the private EKS API server (e.g. VPC CIDR, VPN)"
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────
# GitHub OIDC
# ─────────────────────────────────────────
variable "prometheus_retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 15
}

variable "github_org" {
  description = "GitHub organisation or username (e.g. pkpakau)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. clevertap-devops-assignment)"
  type        = string
}
