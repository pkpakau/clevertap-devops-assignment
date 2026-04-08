environment    = "staging"
region         = "us-east-1"
aws_account_id = "222222222222"
cost_center    = "platform"
team           = "devops"

# VPC — 10.2.0.0/16
vpc_cidr = "10.2.0.0/16"
azs      = ["us-east-1a", "us-east-1b", "us-east-1c"]

public_subnets  = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
private_subnets = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
intra_subnets   = ["10.2.20.0/24", "10.2.21.0/24", "10.2.22.0/24"]

enable_tgw            = true
enable_tgw_attachment = false
tgw_id                = null

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

github_org  = "pkpakau"
github_repo = "clevertap-devops-assignment"
