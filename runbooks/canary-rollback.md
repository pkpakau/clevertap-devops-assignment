# Runbook: Canary Rollback — Production Deploy

*Argo Rollouts manages canary in prod. This runbook covers both auto and manual rollback.*

---

## Auto Rollback (Argo handles it)

If Prometheus error rate > 1% or p99 latency > 500ms during canary, Argo rolls back automatically.
You'll get a Slack alert. Verify rollback happened:

```bash
kubectl argo rollouts get rollout event-ingestion -n prod
# Status should show: Degraded → rolling back → Healthy
```

If auto rollback completed, service is restored. Start PIR.

---

## Canary Stuck — Not Progressing

Canary stuck at 10% or 50%, not moving forward:

```bash
# Check what Argo thinks is happening
kubectl argo rollouts get rollout event-ingestion -n prod --watch

# Check analysis runs
kubectl get analysisrun -n prod
kubectl describe analysisrun <name> -n prod
```

Common reasons it's stuck:
1. Prometheus unreachable → analysis can't run → rollout pauses
2. Prometheus query returns no data → treated as failure
3. Error rate just above 1% threshold → Argo is waiting, not failed yet

Check Prometheus is reachable:
```bash
kubectl exec -it deploy/event-ingestion -n prod -- curl -s http://prometheus-operated.monitoring:9090/-/healthy
```

---

## Manual Rollback

Use this if auto rollback didn't trigger but you're seeing issues:

```bash
# Abort the canary immediately — stops traffic shifting, rolls back to stable
kubectl argo rollouts abort event-ingestion -n prod

# Confirm rollback
kubectl argo rollouts get rollout event-ingestion -n prod
```

Or via Helm:
```bash
helm rollback event-ingestion -n prod
helm history event-ingestion -n prod  # verify
```

---

## Manual Promote (skip remaining steps)

Use only if you've validated the canary yourself and want to skip wait times:

```bash
kubectl argo rollouts promote event-ingestion -n prod
```

Don't use this to bypass a failing analysis. Fix the issue first.

---

## After Rollback

1. Verify stable version is serving traffic
```bash
kubectl argo rollouts get rollout event-ingestion -n prod
# should show: Healthy, stable revision serving 100%
```

2. Check error rate is back to baseline in Grafana

3. Identify what caused the rollback — check the AnalysisRun that failed:
```bash
kubectl describe analysisrun <failed-run-name> -n prod
```

4. Fix the issue in a new branch, don't re-deploy the same image
