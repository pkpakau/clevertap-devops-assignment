# Runbook: KubePodCrashLooping — Event Ingestion Service

*For on-call engineer. Follow in order, don't skip steps.*

---

## Step 1 — Confirm Blast Radius (2 min)

```bash
kubectl get pods -n prod | grep event-ingestion
kubectl describe pod <pod-name> -n prod
```

All pods crashing or just one?
- All pods → deploy issue or config issue
- One pod → node issue, cordon that node

Check Kafka lag immediately — if lag is climbing, impact is already happening.
```bash
kafka-consumer-groups.sh --bootstrap-server <broker> --describe --group event-ingestion
```
Lag > 100K and climbing → escalate now, don't wait.

---

## Step 2 — Read the Logs (3 min)

```bash
kubectl logs <pod-name> -n prod --previous
```

What to look for:
- `OOMKilled` → memory limit too low or memory leak
- Exit code `1` → app crash, read the full stacktrace
- Exit code `137` → OOM again
- `Connection refused` → Kafka or DB is down, not this service's fault
- `secret not found` → ESO sync issue, check ExternalSecret

---

## Step 3 — Check Recent Changes (2 min)

```bash
helm history event-ingestion -n prod
kubectl rollout history deployment/event-ingestion -n prod
```

Deploy in last 2 hours? Roll it back, ask questions later.

```bash
helm rollback event-ingestion -n prod
kubectl rollout status deployment/event-ingestion -n prod
```

---

## Step 4 — Decision Tree

```
CrashLoopBackOff
    │
    ├── Recent deploy?
    │   YES → helm rollback event-ingestion -n prod
    │
    ├── OOMKilled?
    │   → Scale memory limit via PR + hotfix deploy
    │   → Don't kubectl edit — that's drift
    │   → Temporary: kubectl set resources deployment event-ingestion -n prod --limits=memory=1Gi
    │
    ├── Config/Secret missing?
    │   → kubectl get externalsecret -n prod
    │   → kubectl describe externalsecret event-ingestion-secrets -n prod
    │   → Check ESO pod: kubectl get pods -n external-secrets
    │
    ├── Dependency down (Kafka/DB)?
    │   → Not your incident, page the owning team
    │   → Scale down this service to stop crash loop noise
    │
    └── None of the above?
        → Scale out first to restore service
        → kubectl scale deployment event-ingestion -n prod --replicas=+2
        → Then debug with buffer
```

---

## Escalation Criteria

| Condition | Action |
|---|---|
| > 15 min unresolved | Page team lead |
| Kafka lag > 100K | Page data engineering team |
| All pods down > 5 min | Customer facing impact, start comms |
| Root cause unknown after 30 min | War room, pull in senior engineers |

---

## Internal Comms (Slack)

```
P1 - Event Ingestion CrashLooping
Impact: campaign events not processing
Time: <HH:MM IST>
Status: Investigating / Rollback in progress
Owner: <your name>
Next update: 15 min
```

## Customer Comms (only if SLA breached, check with lead first)

```
We are aware of an issue affecting event processing.
Our team is actively working on a fix.
Next update in 30 minutes.
```

---

## Post Incident Review Checklist

1. Timeline — when did it start vs when detected vs when resolved
2. Detection gap — did our alert catch it or did a customer report it? Customer reported = gap to fix
3. Actual root cause — not "pod crashed", real reason (e.g. memory leak in v1.2.3 due to unbounded cache)
4. Kafka lag peak and how long to recover
5. Was rollback needed? How long did it take?
6. Max 3 action items, each with an owner and a date
7. Did this runbook help? Update it if steps were missing or wrong

PIRs with 10 action items get nothing done. Keep it short.
