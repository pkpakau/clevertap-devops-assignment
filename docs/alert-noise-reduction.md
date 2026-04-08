# Section 2c: Alert Noise Reduction

60% auto-resolving in 5 min means your alerts are wrong, not your infra.

## Audit Phase (Week 1)

Pull last 30 days alert data from Alertmanager.
Tag everything that resolved under 5 min without human action.
Group by service — find top 3 noisiest.
That's your hit list, start there.

## Classify Each Alert

- Pages someone and needs action → keep, maybe tune threshold
- Informational only → move to dashboard, off the pager
- Auto-resolves under 5 min → add `for: 10m` or kill it
- Same alert firing from 10 pods → group in Alertmanager, one ticket not ten

## Fix In Order of Impact

1. Add `for: 10m` to everything that doesn't need instant response — single biggest noise reducer, takes 30 min
2. CPU/memory threshold alerts → convert to SLO burn rate
3. Alertmanager grouping — same deployment firing 50 pod alerts becomes 1 alert
4. Dead man's switch — if a pipeline should always be running, alert when it's NOT running instead of alerting on every spike

## Measuring Alerting Health Going Forward

Track these monthly:
- Alerts fired per day (target: under 20 that actually need action)
- % auto-resolved under 5 min (target: under 10%)
- MTTA — Mean Time To Acknowledge for P1 (target: under 5 min)
- Alert to incident ratio — how many alerts become real incidents

Review in monthly engineering all hands. If on-call team hates the alerts, fix the alerts not the team.
High on-call toil is a retention risk — engineers burn out and leave.
