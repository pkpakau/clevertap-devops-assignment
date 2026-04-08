environment    = "prod"
region         = "ap-south-1"
aws_account_id = "333333333333"
cost_center    = "platform"
team           = "devops"

# VPC — 10.5.0.0/16
vpc_cidr = "10.5.0.0/16"
azs      = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

public_subnets  = ["10.5.0.0/24", "10.5.1.0/24", "10.5.2.0/24"]
private_subnets = ["10.5.10.0/24", "10.5.11.0/24", "10.5.12.0/24"]
intra_subnets   = ["10.5.20.0/24", "10.5.21.0/24", "10.5.22.0/24"]

# Spoke region — attaches to TGW created in us-east-1
enable_tgw            = false
enable_tgw_attachment = true
tgw_id                = "tgw-REPLACE_AFTER_US_EAST_1_APPLY"

# EKS
cluster_version = "1.29"

node_groups = {
  on_demand = {
    instance_types = ["m5.xlarge", "m5.2xlarge"]
    capacity_type  = "ON_DEMAND"
    min_size       = 3
    max_size       = 10
    desired_size   = 3
    disk_size_gb   = 100
    labels         = { "capacity-type" = "on-demand", "env" = "prod" }
    taints         = []
  }
  spot = {
    instance_types = ["m5.xlarge", "m5a.xlarge", "m4.xlarge", "m5d.xlarge"]
    capacity_type  = "SPOT"
    min_size       = 0
    max_size       = 50
    desired_size   = 2
    disk_size_gb   = 100
    labels         = { "capacity-type" = "spot", "env" = "prod" }
    taints = [{
      key    = "spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }]
  }
}
