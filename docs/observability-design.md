# Section 2a: Observability Stack Design

Based on my experience, four pillars.

## Metrics

Prometheus + Thanos. Prometheus for real-time, Thanos ships old data to S3 for long term retention.
Grafana for dashboards — each team owns their service dashboard, not platform team's job.

Cardinality is a real issue at 40B events/day. Don't put pod_id, request_id, or user_id as labels — it kills your Prometheus TSDB fast. Use recording rules to pre-aggregate before storing.

Scrape interval: 30s is enough. 15s doubles your storage for marginal gain.

## Logs

Fluent Bit as daemonset on every node — lightweight, battle tested.
Ship to Loki (cheap, S3 backed) or OpenSearch if you need full text search.
JSON logs only — unstructured logs are impossible to query at this scale.

Retention: 7 days hot, then S3 for audit/compliance (needed for ISO 27001).

## Traces

OpenTelemetry Collector — vendor neutral, don't tie yourself to one backend.
Backend: Tempo or AWS X-Ray depending on budget.
Sampling: 10% baseline, 100% on errors. Don't trace everything — storage costs blow up.

## Events

K8s events → Loki, 7 day retention.
AWS service events via EventBridge → same alerting pipeline.

## Data Flow

```
App pods → Fluent Bit → Loki
Node metrics → Prometheus → Thanos → S3
Traces → OTel Collector → Tempo
K8s events → Loki
AWS events → EventBridge → Alertmanager
```

## SLO Based Alerting vs Threshold

Threshold alerts are noisy. "CPU > 80%" fires at 2am when nothing is actually broken.

SLO burn rate tells you you're consuming your error budget faster than normal — that's when you wake someone up.

Two window approach (5min + 1h) stops false positives. Short window catches fast burns, long window confirms it's not a blip.

Use Sloth or Pyrra to generate burn rate alerts from SLOs — they handle the math.

Done this before. Moved a team from threshold to burn rate, reduced alert volume 60%+ in first month. On-call team actually trusted the alerts after that.

## Cardinality Management

1. Label hygiene enforced at ingest — drop high cardinality labels in Fluent Bit/OTel config
2. Recording rules pre-aggregate before storage
3. Monthly cardinality audit — `topk(10, count by (__name__)({__name__=~".+"}))` shows the worst offenders
4. Alert if new high cardinality labels appear (Grafana Mimir has this built in)
