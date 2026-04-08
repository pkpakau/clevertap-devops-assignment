# Section 3b: Internal Developer Platform (IDP)

## What We Built at Amazon Music (Reference)

We had a platform where a team needing a 3-tier app would fill out a form — service name, team, cost center, LDAP owner, financial owner.

It would create:
- Git repo with sample code (React, Node, whatever they picked)
- CDN + subdomain with split horizon DNS
- S3 static hosting with identity provider
- CDK code with base stack
- CI/CD pipeline wired in
- Monitoring and observability out of the box

Clear resources with one click — deletes all stacks. No orphaned resources, no surprise bills.

## How I'd Build This for CleverTap

### Self-Service Flow

Engineer fills out a form (Backstage or internal portal):
- Service name
- Team / cost center
- Environment type (dev, integration, load test)
- Required infra (RDS, ElastiCache, Kafka topic, S3)
- TTL — when should this environment die?

Portal calls Terraform Cloud API or Atlantis to provision.
Everything tagged automatically from the form inputs — no manual tagging needed.

### For Kubernetes Environments

Prefer a separate account per team for full isolation.
If cost is a constraint, use separate namespace + NetworkPolicy + IAM permission boundary.
Never share a namespace between teams — debugging becomes a nightmare.

### Cost Guardrails

1. TTL tag on every resource — Lambda runs nightly, deletes anything past TTL
2. Max spend limit per environment type — dev env can't provision > $50/day of resources
3. Approved modules only — teams can't provision arbitrary things, only vetted templates
4. Budget alert at 80% of team allocation

### Security Guardrails

1. All templates enforce approved module versions — no custom security group rules, no open 0.0.0.0/0
2. RBAC via AWS SSO — dev team gets dev account access, nothing else
3. No production data in dev environments — enforced by network isolation and IAM

### Cleanup Automation

TTL-based cleanup is the most important part. Without it you end up with hundreds of forgotten environments eating money.

Every provisioned environment gets:
```
TTL = creation_date + requested_duration
Owner = LDAP_user_who_created_it
```

7 days before TTL: email to owner
1 day before TTL: Slack DM to owner
TTL reached + no extension request: auto-delete

Extension requests go through the same portal — forces conscious decision to keep it.

### What This Solves

Dev teams ship faster — no waiting for DevOps team to provision.
DevOps team stops being a bottleneck and focuses on the platform itself.
Finance gets visibility — every environment has a cost owner from day one.
