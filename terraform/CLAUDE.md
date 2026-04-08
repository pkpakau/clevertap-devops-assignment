# Terraform — Claude Context

## How State Works

Partial backend config — same code runs for all envs, backend values passed at init time.

```bash
# Always run this before plan/apply in a new shell
terraform init \
  -backend-config="bucket=tf-state-{env}-{region}" \
  -backend-config="key=clevertap/terraform.tfstate" \
  -backend-config="region={region}" \
  -backend-config="dynamodb_table=tf-locks-{env}"
```

S3 bucket naming: `tf-state-dev-us-east-1`, `tf-state-prod-ap-south-1` etc.
DynamoDB table: one per account — `tf-locks-dev`, `tf-locks-staging`, `tf-locks-prod`.

If buckets don't exist yet: `./bootstrap/bootstrap.sh <env>`

---

## Common Commands

```bash
# Plan dev us-east-1
terraform init -backend-config="bucket=tf-state-dev-us-east-1" \
  -backend-config="key=clevertap/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=tf-locks-dev"

terraform plan -var-file="tfvars/dev/us-east-1.tfvars"

# Apply (dev only — staging/prod go through GitHub Actions)
terraform apply -var-file="tfvars/dev/us-east-1.tfvars"

# Target a specific resource (use sparingly)
terraform apply -var-file="tfvars/dev/us-east-1.tfvars" -target=module.vpc

# Import existing resource
terraform import -var-file="tfvars/dev/us-east-1.tfvars" aws_s3_bucket.flow_logs my-existing-bucket
```

---

## Module Map

```
main.tf
├── module.vpc          → modules/vpc/
│   Creates: VPC, 3 subnet tiers, NAT GWs, TGW (hub region only), flow logs → S3
│   Outputs: vpc_id, private_subnet_ids, intra_subnet_ids, transit_gateway_id
│
├── module.eks          → modules/eks/
│   Takes: vpc_id, private_subnet_ids from module.vpc
│   Creates: EKS cluster (private endpoint), OIDC provider, node groups, managed addons
│   Outputs: cluster_name, cluster_endpoint, oidc_provider_arn, oidc_provider_url
│
└── module.eks_addons   → modules/eks-addons/
    Takes: cluster_name, cluster_endpoint, oidc_provider_arn from module.eks
    Creates: ALB controller, Cluster Autoscaler, NTH, ESO + ClusterSecretStore,
             Argo Rollouts, kube-prometheus-stack (all via helm_release)
    Depends on: module.eks (must be fully ready first)
```

---

## IAM Files

`iam-github-oidc.tf`
- GitHub OIDC provider (one per account)
- `terraform-plan-role` — assumed by PR workflows, read-only
- `terraform-apply-role` — assumed by deploy workflows, locked to specific GitHub environment

`iam-workload-roles.tf`
- `app-deploy-role` — GitHub Actions app pipelines, ECR push + EKS describe
- `event-ingestion-role` — pod IRSA, S3 write + Secrets Manager read (scoped to /clevertap/{env}/*)
- ECR repository `event-ingestion` with scan-on-push + lifecycle policy

---

## Transit Gateway Design

us-east-1 is the hub region — `enable_tgw = true` creates the TGW.
ap-south-1 is spoke — `enable_tgw_attachment = true` + `tgw_id = <from us-east-1 output>`.

So always apply us-east-1 first, grab the `transit_gateway_id` output, put it in ap-south-1 tfvars.

EU clusters (eu-west-1) do NOT attach to this TGW — data residency law, no cross-region traffic.

---

## CIDR Allocation

| Env | Region | VPC CIDR |
|---|---|---|
| dev | us-east-1 | 10.0.0.0/16 |
| dev | ap-south-1 | 10.1.0.0/16 |
| staging | us-east-1 | 10.2.0.0/16 |
| staging | ap-south-1 | 10.3.0.0/16 |
| prod | us-east-1 | 10.4.0.0/16 |
| prod | ap-south-1 | 10.5.0.0/16 |

Subnets per VPC: public /24, private /24, intra /24 — one per AZ (3 AZs each).

---

## Common Issues

**`Error: state lock`**
Someone else is running apply or a previous run crashed. Check DynamoDB `tf-locks-{env}` table, delete the LockID item if the run is definitely dead.

**`Error acquiring state lock`**
Same as above. Don't delete lock if another apply is genuinely in progress.

**`module.eks_addons: helm_release timeout`**
Addons need cluster nodes to be ready. Check node group status first:
```bash
aws eks describe-nodegroup --cluster-name clevertap-{env} --nodegroup-name {env}-on-demand
```

**`oidc provider already exists`**
OIDC provider is per-account not per-cluster. If another cluster already created it, import it:
```bash
terraform import aws_iam_openid_connect_provider.github_actions arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com
```

**Drift detected in prod**
Don't auto-apply. Check CloudTrail first — who changed what and when. Raise a PR with the fix, let it go through normal approval flow.
