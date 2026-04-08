# Section 4a: 90-Day Cost Reduction Plan

Target: $105-126K savings from $420K/month bill.
Based on my past experience with similar workloads.

---

## Week 1-2: Quick Wins

**1. Hunt untracked resources**
If you're not fully on IaC, lots of resources get untracked.
Elastic IPs especially — delete unused ones immediately.
[ Low Effort | Medium Risk ]

**2. Stale EBS volumes**
EBS volumes stay when you delete EC2s — default behavior is to retain.
Not managed by IaC means nobody's watching them.
Check Cost Explorer → EC2 → EBS, filter for unattached.
[ Low Effort | High Risk — verify before deleting ]

**3. Manually created EC2s without tags**
Flag any EC2 without required tags (Env/Team/Service).
These are almost always forgotten instances.
Chase the owners or schedule deletion.
[ Low Effort | Medium Risk ]

**4. Cost Explorer review**
Find top 5 most expensive services. Identify loose infra.
Chase stakeholders to clean up or put a deletion date on it.
[ Low Effort | Low Risk ]

Estimated savings Week 1-2: ~$20K/month

---

## Month 1-2: Right-sizing and Commitments

**1. NAT Gateway consolidation (non-prod)**
Don't create separate NAT GWs for each public subnet in dev/staging.
One NAT per AZ is fine for non-prod, one NAT total is fine for dev.
NATs are 32$/month each — in a multi-VPC environment this becomes a major cost factor.
[ Medium Effort | Medium Risk — needs discussion with teams ]

**2. S3 Intelligent Tiering**
VPC flow logs, application logs, old backups — move to S3 Intelligent Tiering.
Also needed for ISO 27001 audit evidence storage.
[ Medium Effort | Low Risk ]

**3. Savings Plans**
Compute Savings Plans over EC2 Reserved Instances for EKS.
Reason: Compute SP covers any EC2 instance type and size — flexible when you're running mixed instance types on node groups.
EC2 RI locks you to a specific instance type — bad for Spot mixed groups.
Commit 1 year for predictable baseline workload (on-demand node groups).
Don't commit Spot — those scale dynamically.
[ Medium Effort | Low Risk — just a billing commitment ]

**4. Spot for dev/test workloads**
Use Spot instances for dev and non-critical staging workloads.
On-demand for fixed production workloads.
[ Medium Effort | Medium Risk — needs proper NTH setup which we have ]

Estimated savings Month 1-2: ~$60K/month

---

## Month 2-3: Architectural Changes

**1. VPC Endpoints for S3 and ECR**
If you're accessing S3 from private subnet resources, VPC Endpoint Gateway is free same-region data transfer vs going through NAT/internet.
EKS nodes pull ECR images constantly — VPC Endpoint for ECR saves significant data transfer costs.
[ Medium Effort | Low Risk ]

**2. RDS right-sizing**
Check CPU and memory utilization. Most RDS instances are over-provisioned.
Scale down if utilization is consistently under 40%.
[ Medium Effort | Medium Risk — test in staging first ]

**3. Aurora Postgres consideration**
If RDS auto-scaling is operationally overhead, Aurora Postgres with configurable ACUs can scale down to 0 for non-prod.
Yes it's more expensive per ACU but saves ops time and you're not paying for idle capacity.
[ High Effort | High Risk — migration needed ]

**4. Graviton instances**
Switch to AWS Graviton (arm64) for EKS node groups.
Cheaper per vCPU, often faster too.
m7g.xlarge vs m5.xlarge — about 20% cheaper for comparable performance.
[ Medium Effort | Medium Risk — need to verify app builds arm64 ]

Mostly I see silent network costs and they're the most non-obvious.
Other savings will surface once I see actual internal architecture and Cost Explorer breakdown.

Estimated savings Month 2-3: ~$30K/month

Total estimated: ~$110K/month — within the 25-30% target.
