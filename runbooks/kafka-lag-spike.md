# Runbook: Kafka Lag Spike — Event Ingestion Consumer

*Alert: KafkaConsumerGroupLag > 100K for group event-ingestion*

---

## Step 1 — Check Current Lag (2 min)

```bash
kafka-consumer-groups.sh \
  --bootstrap-server <broker>:9092 \
  --describe \
  --group event-ingestion
```

Note: which partitions are lagging? All of them or specific ones?
- All partitions lagging → consumer is slow or down
- Specific partitions → likely a poison pill message or hot partition

---

## Step 2 — Is the Consumer Running?

```bash
kubectl get pods -n prod | grep event-ingestion
```

Pods down or crashing? → See pod-crashlooping runbook first, fix that, lag will recover.

Pods running fine? → Consumer is slow or overwhelmed.

---

## Step 3 — Check Consumer Throughput

Check Grafana dashboard for event-ingestion:
- Messages consumed per second — is it dropping?
- Pod CPU/memory — are pods saturated?
- Downstream latency — is Kafka publish slow due to a downstream bottleneck?

---

## Step 4 — Decision Tree

```
Lag > 100K
    │
    ├── Pods down/crashing?
    │   → Fix pods first (pod-crashlooping runbook)
    │   → Lag will recover once pods are healthy
    │
    ├── Pods healthy but lag growing?
    │   → Scale out consumers
    │   → kubectl scale deployment event-ingestion -n prod --replicas=+3
    │   → Note: can't exceed partition count, scaling beyond that does nothing
    │
    ├── Lag on specific partitions only?
    │   → Likely poison pill — message consumer can't process
    │   → Check consumer logs for repeated errors on same offset
    │   → Skip the message (requires manual offset reset — involve senior engineer)
    │
    └── Lag growing despite scaling?
        → Upstream is producing faster than we can consume
        → Check producer rate in Grafana
        → Escalate to data engineering team
```

---

## Scale Out Consumers

```bash
# Temporary scale out — update HPA minReplicas via PR for permanent fix
kubectl scale deployment event-ingestion -n prod --replicas=10

# Watch lag recovery
watch -n 10 'kafka-consumer-groups.sh --bootstrap-server <broker>:9092 --describe --group event-ingestion'
```

Max replicas = number of Kafka partitions for this topic. Scaling beyond doesn't help.

---

## Escalation

| Condition | Action |
|---|---|
| Lag > 500K | Page data engineering team |
| Lag not recovering after scale out | War room |
| Customer campaigns visibly delayed | Customer comms, check with lead first |

---

## After Recovery

1. Note peak lag and recovery time for PIR
2. If scale out was needed, raise a PR to update HPA minReplicas permanently
3. Check if this correlates with a traffic spike — do we need more base capacity?
