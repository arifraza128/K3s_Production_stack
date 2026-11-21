---
experiment: "03-network-partition"
hypothesis: "Removing test-api ingress NetworkPolicy blocks traffic immediately under default-deny-all; re-applying the policy restores HTTP 200 reachability in < 60s."
injected_at: "2026-11-21T15:43:44Z"
recovered_at: "2026-11-21T15:43:48Z"
recovery_seconds: 1
result: "PASS"
dashboard_screenshot: "observability/grafana/k3s-platform-slo-dashboard.yaml"
---

# Chaos Experiment: 03 — Network Partition (NetworkPolicy Isolation)

- **Hypothesis:** Removing test-api ingress NetworkPolicy blocks traffic immediately under default-deny-all; re-applying the policy restores HTTP 200 reachability in < 60s.
- **Steady State:** GET https://13.207.161.55.sslip.io/work returns HTTP 200.
- **Injection Method:** `Delete allow-test-api-ingress-and-dns under default-deny-all, verify isolation, then restore NetworkPolicy`
- **Injected At (UTC):** `2026-11-21T15:43:44Z`
- **Recovered At (UTC):** `2026-11-21T15:43:48Z`
- **Observation:**
```text
HTTP response while partitioned under default-deny-all: 502
HTTP response after NetworkPolicy restoration: HTTP 200
Measured recovery time after policy restore: 1s
```
- **Recovery Seconds:** `1s`
- **Result:** **PASS**
- **Dashboard Screenshot:** Grafana `phoenix-platform-slos` Row 1 & Row 3 annotations
- **Follow-ups:** Automated assertion passed (< 60s SLO recovery threshold).
