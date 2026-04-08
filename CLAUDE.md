# CleverTap DevOps Platform — Claude Context

This repo is a Staff DevOps Engineer technical assessment built by Parag K.
It covers multi-region EKS infrastructure, CI/CD pipelines, and platform tooling for a 40B+ events/day SaaS platform.

---

## Repo Structure

```
├── terraform/          Infrastructure as Code — EKS, VPC, IAM, cluster addons
├── app/                Sample event-ingestion microservice + Helm chart
├── .github/workflows/  GitHub Actions pipelines (terraform + app)
├── docs/               Architecture decisions, design write-ups
└── runbooks/           Break-fix guides for on-call engineers
```

---

## AWS Account Layout

| Account | ID (placeholder) | Purpose |
|---|---|---|
| dev | 111111111111 | PR branch deployments, ephemeral namespaces |
| staging | 222222222222 | Post-merge validation |
| prod | 333333333333 | Live traffic, us-east-1 + ap-south-1 |

All GitHub Actions auth via OIDC — zero static AWS credentials anywhere.

---

## Terraform

Single `main.tf` with per-env tfvars. No separate directories per environment.

```
terraform/
├── main.tf                     calls vpc + eks + eks-addons modules
├── backend.tf                  partial backend — values passed via -backend-config at init
├── variables.tf
├── outputs.tf
├── iam-github-oidc.tf          GitHub Actions OIDC provider + plan/apply roles
├── iam-workload-roles.tf       app-deploy-role, event-ingestion-role, ECR repo
├── modules/
│   ├── vpc/                    VPC, subnets (public/private/intra), TGW, flow logs
│   ├── eks/                    EKS cluster, IRSA, node groups, managed addons
│   └── eks-addons/             ALB controller, Cluster Autoscaler, NTH, ESO, Argo Rollouts, Prometheus
└── tfvars/
    ├── dev/us-east-1.tfvars
    ├── dev/ap-south-1.tfvars
    ├── staging/us-east-1.tfvars
    ├── staging/ap-south-1.tfvars
    ├── prod/us-east-1.tfvars
    └── prod/ap-south-1.tfvars
```

State: S3 bucket per account+region, DynamoDB lock table per account.
Bootstrap: run `terraform/bootstrap/bootstrap.sh <env>` once before first `terraform init`.

See `terraform/CLAUDE.md` for detailed module info and common commands.

---

## App — Event Ingestion Service

FastAPI service. Receives campaign events, publishes to Kafka.

```
app/
├── Dockerfile              multi-stage build, non-root user, read-only fs
├── requirements.txt
├── src/main.py             /health, /ready, /ingest endpoints
└── helm/
    ├── values.yaml         base values
    ├── values-staging.yaml staging overrides
    ├── values-prod.yaml    prod overrides (canary.enabled: true)
    └── templates/
        ├── deployment.yaml     used for staging + PR envs
        ├── rollout.yaml        Argo Rollouts canary for prod only
        ├── analysis-template.yaml  Prometheus error rate + p99 auto-rollback
        ├── externalsecret.yaml ESO → AWS Secrets Manager
        ├── hpa.yaml
        ├── poddisruptionbudget.yaml
        ├── ingress.yaml        ALB ingress
        ├── service.yaml
        └── serviceaccount.yaml IRSA annotation
```

`canary.enabled` in values-prod.yaml switches between `deployment.yaml` and `rollout.yaml`.

See `app/CLAUDE.md` for Helm commands, canary debugging, ESO troubleshooting.

---

## CI/CD Pipelines

### Terraform Workflows

| File | Trigger | What it does |
|---|---|---|
| `terraform-plan.yml` | PR opened/updated | Plan only, posts diff as PR comment |
| `terraform-dev.yml` | Manual dispatch | Apply to dev account (engineer validates before merging) |
| `terraform-staging.yml` | Merge to main | Apply to staging (1 approval required) |
| `terraform-prod.yml` | `v*.*.*` tag | Apply to prod (2 approvals required) |
| `terraform-drift.yml` | Every 6 hours | Plan all envs, Slack alert on drift |

### App Workflows

| File | Trigger | What it does |
|---|---|---|
| `app-pr.yml` | PR opened/updated | Gitleaks → Semgrep → lint/test → build → Trivy → ECR push → deploy to `pr-{N}` namespace |
| `app-pr.yml` | PR closed | Delete `pr-{N}` namespace |
| `app-staging.yml` | Merge to main | Promote image dev→staging ECR, helm upgrade, smoke tests |
| `app-prod.yml` | `v*.*.*` tag | Promote image staging→prod ECR, Argo Rollouts canary |

---

## Cluster Bootstrap (eks-addons module)

These run inside the cluster, managed by Terraform helm_release:

| Tool | Namespace | Purpose |
|---|---|---|
| AWS Load Balancer Controller | kube-system | ALB ingress |
| Cluster Autoscaler | kube-system | Scale node groups |
| AWS Node Termination Handler | kube-system | Spot interruption drain |
| External Secrets Operator | external-secrets | Sync secrets from Secrets Manager |
| Argo Rollouts | argo-rollouts | Canary deployments |
| kube-prometheus-stack | monitoring | Prometheus + Grafana + Alertmanager |

---

## Secret Management

No secrets in any YAML or GitHub Actions env vars.

Flow: `AWS Secrets Manager → ESO ClusterSecretStore → ExternalSecret CR → K8s Secret → pod envFrom`

Secrets path pattern: `/clevertap/{env}/{secret-name}`
Example: `/clevertap/prod/kafka-brokers`

---

## GitHub Settings Required

Variables (Settings → Secrets and variables → Variables):
- `DEV_ACCOUNT_ID`
- `STAGING_ACCOUNT_ID`
- `PROD_ACCOUNT_ID`

Secrets:
- `SLACK_WEBHOOK_URL`
- `SEMGREP_APP_TOKEN`

Environments: `dev` (no approval), `staging` (1 reviewer), `production` (2 reviewers)

Branch protection on `main`: PR required, 1 approval, terraform-plan must pass.
