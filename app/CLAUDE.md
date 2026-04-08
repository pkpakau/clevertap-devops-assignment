# App — Claude Context

## What This Service Does

Event ingestion service. Receives inbound campaign events via HTTP, publishes to Kafka downstream.
Critical path — if this is down, campaign events are lost.

Endpoints:
- `GET /health` — liveness check
- `GET /ready` — readiness check (checks downstream deps)
- `POST /ingest` — accepts events, needs `account_id` and `event_name`
- `GET /metrics/info` — version, uptime, region, env

---

## Helm Chart

```
helm/
├── values.yaml           base — canary.enabled: false
├── values-staging.yaml   staging overrides
├── values-prod.yaml      prod overrides — canary.enabled: true
└── templates/
    ├── deployment.yaml        staging + PR envs (standard K8s Deployment)
    ├── rollout.yaml           prod only (Argo Rollouts Rollout resource)
    ├── analysis-template.yaml Prometheus queries for canary auto-rollback
    ├── externalsecret.yaml    ESO sync from Secrets Manager
    ├── serviceaccount.yaml    IRSA annotation
    ├── service.yaml
    ├── ingress.yaml           ALB ingress
    ├── hpa.yaml               CPU + memory based autoscaling
    └── poddisruptionbudget.yaml
```

`canary.enabled` flag is the switch. When true, `rollout.yaml` is rendered and `deployment.yaml` is skipped.

---

## Common Helm Commands

```bash
# Deploy to a PR namespace manually
helm upgrade --install event-ingestion helm/ \
  --namespace pr-123 --create-namespace \
  --set image.repository=ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/event-ingestion \
  --set image.tag=sha-abc1234 \
  --set ingress.host=pr-123.dev.clevertap.internal \
  --set externalSecret.enabled=false

# Deploy to staging
helm upgrade --install event-ingestion helm/ \
  --namespace staging \
  --values helm/values-staging.yaml \
  --set image.tag=sha-abc1234

# Check release history
helm history event-ingestion -n prod

# Rollback
helm rollback event-ingestion -n prod

# Diff before upgrade (needs helm-diff plugin)
helm diff upgrade event-ingestion helm/ -n prod --values helm/values-prod.yaml --set image.tag=sha-abc1234
```

---

## Canary Deployments (prod only)

Argo Rollouts manages traffic splitting via ALB weighted target groups.

Flow: new image tag → helm upgrade updates Rollout spec → Argo controller starts canary
- Step 1: 10% canary traffic → 5 min pause
- Step 2: 50% canary traffic → 10 min pause
- Step 3: 100% — promote to stable

Auto-rollback triggers (defined in analysis-template.yaml):
- HTTP error rate > 1% over 5 min window
- p99 latency > 500ms

```bash
# Watch rollout live
kubectl argo rollouts get rollout event-ingestion -n prod --watch

# Manual promote (skip pause, use carefully)
kubectl argo rollouts promote event-ingestion -n prod

# Manual rollback
kubectl argo rollouts abort event-ingestion -n prod
kubectl argo rollouts undo event-ingestion -n prod
```

Rollout stuck at 10%? Check analysis template first:
```bash
kubectl get analysisrun -n prod
kubectl describe analysisrun <name> -n prod
# look at: Prometheus is reachable? query returning values? error rate calculation correct?
```

---

## Secret Management

Secrets never in YAML. Flow:
```
AWS Secrets Manager /clevertap/{env}/{secret}
    → ESO ClusterSecretStore (aws-secrets-store)
    → ExternalSecret CR in each namespace
    → K8s Secret: event-ingestion-secrets
    → pod envFrom: secretRef
```

Check ESO sync status:
```bash
kubectl get externalsecret -n prod
kubectl describe externalsecret event-ingestion-secrets -n prod
# look at: Status.Conditions — should be Ready: True
```

Secret not syncing? Common reasons:
1. IRSA role for ESO doesn't have access to that Secrets Manager path
2. Secret path in values.yaml doesn't match what's actually in Secrets Manager
3. ESO pod itself is down — `kubectl get pods -n external-secrets`

---

## IRSA — Pod Identity

ServiceAccount `event-ingestion-sa` is annotated with IAM role ARN.
Role is created in `terraform/iam-workload-roles.tf`.
Permissions: S3 write to `clevertap-events-{env}/*` + Secrets Manager read for `/clevertap/{env}/*`.

If pod can't access S3 or Secrets Manager:
```bash
# Check annotation is present
kubectl describe sa event-ingestion-sa -n prod

# Verify token is being mounted
kubectl describe pod <pod> -n prod | grep -A5 "Volumes"

# Test from inside pod
kubectl exec -it <pod> -n prod -- aws sts get-caller-identity
# should return the event-ingestion-role ARN not the node role
```

---

## Ephemeral PR Namespaces

Each PR gets `pr-{number}` namespace in dev cluster.
Created by `app-pr.yml` on PR open, deleted on PR close.
`externalSecret.enabled=false` in PR envs — no real secrets, uses dummy values.

List all PR namespaces:
```bash
kubectl get namespaces | grep pr-
```

Manually delete a stale one:
```bash
helm uninstall event-ingestion -n pr-123
kubectl delete namespace pr-123
```

---

## Common Issues

**Pod CrashLoopBackOff**
See runbook: `runbooks/pod-crashlooping.md`

**Canary stuck / not progressing**
- Check AnalysisRun: `kubectl get analysisrun -n prod`
- Check Prometheus is reachable from cluster: `kubectl exec -it <pod> -n monitoring -- curl prometheus:9090/-/healthy`
- Check the metric query returns data — empty result = analysis fails

**Image pull error**
- ECR auth token expired (12h TTL) — node should refresh automatically via node role
- Cross-account pull (staging pulling from dev ECR) — check ECR repo policy allows staging account

**HPA not scaling**
- Metrics server must be running: `kubectl get deployment metrics-server -n kube-system`
- Check HPA status: `kubectl describe hpa event-ingestion -n prod`
