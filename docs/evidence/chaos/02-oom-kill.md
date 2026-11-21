---
experiment: "02-oom-kill"
hypothesis: "A container exceeding its 48Mi memory limit by allocating 200Mi is immediately OOMKilled (exitCode 137) by cgroup v2 without degrading co-located test-api pods."
injected_at: "2026-11-21T15:43:36Z"
recovered_at: "2026-11-21T15:43:44Z"
recovery_seconds: 8
result: "PASS"
dashboard_screenshot: "observability/grafana/k3s-platform-slo-dashboard.yaml"
---

# Chaos Experiment: 02 — OOM-Kill Containment

- **Hypothesis:** A container exceeding its 48Mi memory limit by allocating 200Mi is immediately OOMKilled (exitCode 137) by cgroup v2 without degrading co-located test-api pods.
- **Steady State:** Node memory healthy; test-api pods Ready (2/2).
- **Injection Method:** `python3 -c 'x = bytearray(200 * 1024 * 1024)' inside limits.memory=48Mi pod`
- **Injected At (UTC):** `2026-11-21T15:43:36Z`
- **Recovered At (UTC):** `2026-11-21T15:43:44Z`
- **Observation:**
```text
Container Terminated Reason: OOMKilled (Exit Code: 137)
Co-located test-api public HTTPS status during/after OOM: HTTP 200
Containment & cleanup time: 8s
```
- **Recovery Seconds:** `8s`
- **Result:** **PASS**
- **Dashboard Screenshot:** Grafana `phoenix-platform-slos` Row 1 & Row 3 annotations
- **Follow-ups:** Automated assertion passed (< 60s SLO recovery threshold).
