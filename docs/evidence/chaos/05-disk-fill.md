---
experiment: "05-disk-fill"
hypothesis: "Writing 45Mi into a 30Mi ephemeral-storage bounded container cleans up without triggering Node DiskPressure on the 30GB gp3 volume."
injected_at: "2026-11-21T15:43:53Z"
recovered_at: "2026-11-21T15:43:59Z"
recovery_seconds: 6
result: "PASS"
dashboard_screenshot: "observability/grafana/k3s-platform-slo-dashboard.yaml"
---

# Chaos Experiment: 05 — Disk Fill / Ephemeral Storage Limit Enforcement

- **Hypothesis:** Writing 45Mi into a 30Mi ephemeral-storage bounded container cleans up without triggering Node DiskPressure on the 30GB gp3 volume.
- **Steady State:** Node DiskPressure=False; test-api Ready.
- **Injection Method:** `dd if=/dev/zero of=/tmp/fill bs=1M count=45 (ephemeral-storage limit: 30Mi)`
- **Injected At (UTC):** `2026-11-21T15:43:53Z`
- **Recovered At (UTC):** `2026-11-21T15:43:59Z`
- **Observation:**
```text
Pod Output:
45+0 records in
45+0 records out
47185920 bytes (45.0MB) copied, 0.478837 seconds, 94.0MB/s
-rw-r--r--    1 10001    root       45.0M Nov 21 15:43 /tmp/fill
Node DiskPressure condition after test: False
Recovery & cleanup seconds: 6s
```
- **Recovery Seconds:** `6s`
- **Result:** **PASS**
- **Dashboard Screenshot:** Grafana `phoenix-platform-slos` Row 1 & Row 3 annotations
- **Follow-ups:** Automated assertion passed (< 60s SLO recovery threshold).
