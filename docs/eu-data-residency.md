# Section 1c: EU Data Residency Design

## Problem

EU data residency laws require customer data never leaves eu-west-1.
Still need a single control plane for deployments.

## Architecture

Create a separate EU AWS account. Dedicated EKS cluster in eu-west-1.
No Transit Gateway or VPC peering to US or APAC accounts — data residency law means no transit or rest in another region. Network path must not exist.

## Single Control Plane — ArgoCD Hub and Spoke

Central ArgoCD in a management/control plane account.
Each regional cluster (us-east-1, ap-south-1, eu-west-1) registered as an Argo target.

ArgoCD ApplicationSet creates per-cluster applications with cluster-specific helm values.
EU cluster gets eu-specific values — different ingress config, different secret paths, same base chart.

Advantages:
- All apps managed from single ArgoCD, consistent architecture
- Different helm values per cluster handles regional config differences
- Adding a new region = add a new cluster target, no new pipelines needed

## IAM Boundary — Enforcing Data Residency

IAM Permission Boundary on all roles in EU account — restricts all API calls to eu-west-1 only.

```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": "eu-west-1"
    }
  }
}
```

Even if someone creates a role with broader permissions, the boundary caps it at eu-west-1.

## CI/CD Enforcement

Separate GitHub environment `eu-production` in GitHub Actions.
Environment is configured with eu-west-1 specific variables and role ARNs.
Workflow only has access to EU account role — cannot accidentally deploy to US cluster.

AWS Config rule: if any resource is found outside eu-west-1 in the EU account, mark as non-compliant and alert. Catches anything that slips through.

Audit logs stay in the same EU account — not shipped cross-region.

## What Does NOT Connect to EU

- No TGW attachment
- No VPC peering
- No cross-account S3 replication to non-EU buckets
- Secrets Manager paths scoped to EU account only
