environment    = "staging"
region         = "ap-south-1"
aws_account_id = "222222222222"
cost_center    = "platform"
team           = "devops"

# VPC — 10.3.0.0/16
vpc_cidr = "10.3.0.0/16"
azs      = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

public_subnets  = ["10.3.0.0/24", "10.3.1.0/24", "10.3.2.0/24"]
private_subnets = ["10.3.10.0/24", "10.3.11.0/24", "10.3.12.0/24"]
intra_subnets   = ["10.3.20.0/24", "10.3.21.0/24", "10.3.22.0/24"]

# Spoke region — attaches to TGW created in us-east-1
enable_tgw            = false
enable_tgw_attachment = true
tgw_id                = "tgw-REPLACE_AFTER_US_EAST_1_APPLY"

# EKS
cluster_version = "1.29"

node_groups = {
  on_demand = {
    instance_types = ["m5.xlarge"]
    capacity_type  = "ON_DEMAND"
    min_size       = 2
    max_size       = 6
    desired_size   = 2
    disk_size_gb   = 50
    labels         = { "capacity-type" = "on-demand", "env" = "staging" }
    taints         = []
  }
  spot = {
    instance_types = ["m5.xlarge", "m5a.xlarge", "m4.xlarge"]
    capacity_type  = "SPOT"
    min_size       = 0
    max_size       = 20
    desired_size   = 0
    disk_size_gb   = 50
    labels         = { "capacity-type" = "spot", "env" = "staging" }
    taints = [{
      key    = "spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }]
  }
}
