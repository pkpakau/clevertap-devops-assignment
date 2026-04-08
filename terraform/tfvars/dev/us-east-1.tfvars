environment    = "dev"
region         = "us-east-1"
aws_account_id = "111111111111"
cost_center    = "platform"
team           = "devops"

# VPC — 10.0.0.0/16
vpc_cidr = "10.0.0.0/16"
azs      = ["us-east-1a", "us-east-1b", "us-east-1c"]

public_subnets  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
intra_subnets   = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

# Hub region — TGW created here, ap-south-1 attaches to it
enable_tgw            = true
enable_tgw_attachment = false
tgw_id                = null

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

github_org  = "pkpakau"
github_repo = "clevertap-devops-assignment"
