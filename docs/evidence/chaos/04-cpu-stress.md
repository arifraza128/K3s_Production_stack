---
experiment: "04-cpu-stress"
hypothesis: "CFS CPU limits (200m) throttle a 2-worker CPU-bound noisy neighbor pod while test-api /work latency remains responsive."
injected_at: "2026-11-21T15:43:48Z"
recovered_at: "2026-11-21T15:43:52Z"
recovery_seconds: 4
result: "PASS"
dashboard_screenshot: "observability/grafana/k3s-platform-slo-dashboard.yaml"
---

# Chaos Experiment: 04 — CPU Stress & CFS Quota Throttling

- **Hypothesis:** CFS CPU limits (200m) throttle a 2-worker CPU-bound noisy neighbor pod while test-api /work latency remains responsive.
- **Steady State:** test-api /work P95 latency < 300ms.
- **Injection Method:** `2 busy-loop workers inside limits.cpu=200m pod while probing https://13.207.161.55.sslip.io/work`
- **Injected At (UTC):** `2026-11-21T15:43:48Z`
- **Recovered At (UTC):** `2026-11-21T15:43:52Z`
- **Observation:**
```text
Sample 1: 123ms (HTTP 200)
Sample 2: 119ms (HTTP 200)
Sample 3: 120ms (HTTP 200)
Sample 4: 121ms (HTTP 200)
Sample 5: 108ms (HTTP 200)Peak observed latency under CPU stress: 123ms
Experiment duration & cleanup: 4s
```
- **Recovery Seconds:** `4s`
- **Result:** **PASS**
- **Dashboard Screenshot:** Grafana `phoenix-platform-slos` Row 1 & Row 3 annotations
- **Follow-ups:** Automated assertion passed (< 60s SLO recovery threshold).
