# Section 4b: FinOps Process Design

## Tagging Strategy

Every resource must have these tags. Non-negotiable.

```
Env         = dev | staging | prod
Team        = platform | backend | frontend | data
Service     = event-ingestion | campaign-processor | etc
CostCenter  = <LDAP cost center code>
Owner       = <LDAP user or team DL>
```

Enforce via Service Control Policies (SCP) at AWS Org level.
If a resource doesn't have required tags, SCP blocks creation.
This is the only way to actually enforce it — documentation and processes don't work.

## Month 1-2: Visibility

Create tag-based weekly cost report per team from AWS Cost Explorer.
Send to team leads every Monday morning.
Teams see their spend, start asking questions about what's expensive.
Don't charge them yet — just make it visible.

This phase is about building awareness, not accountability.

## Month 2-3: Soft Chargeback

Create team cloud budgets based on current actual spend.
Flag teams that exceed budget in engineering review meetings.
Soft chargeback = internal visibility only, doesn't affect actual billing.

Budget alerts: 80% threshold → Slack to team lead, 100% → Slack + email.

## Month 4+: Hard Chargeback

Similar to how we ran it at Amazon — every team owns their AWS costs.
Each team gets a monthly cloud budget, overage comes from their engineering budget.
Easier to delegate cost decisions — team lead can approve or reject new infra based on budget.

This model works because:
- Engineers start thinking about cost when building new features
- Easier to justify infra investments (ROI conversation)
- Platform team stops being cost police

## Showback Dashboard (Grafana)

Live dashboard showing cost by team/service/env.
Data from AWS Cost Explorer API, refreshed daily.
Each team can see their own spend without needing AWS Console access.

Key views:
- Cost by service this month vs last month
- Top 5 most expensive resources per team
- Trend — is spend growing or shrinking?
- Untagged resource cost (should always be zero if SCPs are enforced)
