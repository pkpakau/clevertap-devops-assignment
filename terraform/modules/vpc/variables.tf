variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets — EKS worker nodes (one per AZ)"
  type        = list(string)
}

variable "intra_subnets" {
  description = "CIDR blocks for intra subnets — RDS, ElastiCache, no internet (one per AZ)"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "enable_tgw" {
  description = "Create a Transit Gateway and attach this VPC to it"
  type        = bool
  default     = false
}

variable "tgw_id" {
  description = "Existing Transit Gateway ID to attach to (required if enable_tgw_attachment = true)"
  type        = string
  default     = null
}

variable "enable_tgw_attachment" {
  description = "Attach VPC to an existing Transit Gateway (use when TGW is managed separately)"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Days to keep VPC flow logs in S3 standard storage before transitioning to Glacier"
  type        = number
  default     = 30
}

variable "flow_logs_glacier_days" {
  description = "Days after creation to transition flow logs to Glacier"
  type        = number
  default     = 90
}

variable "flow_logs_expiry_days" {
  description = "Days after creation to permanently delete flow logs"
  type        = number
  default     = 365
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
