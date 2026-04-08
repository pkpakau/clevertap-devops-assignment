environment    = "prod"
region         = "us-east-1"
aws_account_id = "333333333333"
cost_center    = "platform"
team           = "devops"

# VPC — 10.4.0.0/16
vpc_cidr = "10.4.0.0/16"
azs      = ["us-east-1a", "us-east-1b", "us-east-1c"]

public_subnets  = ["10.4.0.0/24", "10.4.1.0/24", "10.4.2.0/24"]
private_subnets = ["10.4.10.0/24", "10.4.11.0/24", "10.4.12.0/24"]
intra_subnets   = ["10.4.20.0/24", "10.4.21.0/24", "10.4.22.0/24"]

# Hub region — TGW created here
enable_tgw            = true
enable_tgw_attachment = false
tgw_id                = null

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
