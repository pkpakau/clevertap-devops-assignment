environment    = "dev"
region         = "ap-south-1"
aws_account_id = "111111111111"
cost_center    = "platform"
team           = "devops"

# VPC — 10.1.0.0/16
vpc_cidr = "10.1.0.0/16"
azs      = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

public_subnets  = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
private_subnets = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
intra_subnets   = ["10.1.20.0/24", "10.1.21.0/24", "10.1.22.0/24"]

# Spoke region — attaches to TGW created in us-east-1
# tgw_id is populated after us-east-1 is applied (output: transit_gateway_id)
enable_tgw            = false
enable_tgw_attachment = true
tgw_id                = "tgw-REPLACE_AFTER_US_EAST_1_APPLY"

# EKS
cluster_version = "1.29"

node_groups = {
  on_demand = {
    instance_types = ["m5.large"]
    capacity_type  = "ON_DEMAND"
    min_size       = 1
    max_size       = 3
    desired_size   = 1
    disk_size_gb   = 50
    labels         = { "capacity-type" = "on-demand", "env" = "dev" }
    taints         = []
  }
  spot = {
    instance_types = ["m5.large", "m5a.large", "m4.large"]
    capacity_type  = "SPOT"
    min_size       = 0
    max_size       = 10
    desired_size   = 0
    disk_size_gb   = 50
    labels         = { "capacity-type" = "spot", "env" = "dev" }
    taints = [{
      key    = "spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }]
  }
}
