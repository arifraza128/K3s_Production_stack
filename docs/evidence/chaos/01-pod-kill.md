---
experiment: "01-pod-kill"
hypothesis: "With 2 replicas of test-api, force-deleting 1 pod maintains service availability and Kubernetes recovers the replacement pod in < 60s."
injected_at: "not yet measured"
recovered_at: "not yet measured"
recovery_seconds: "not yet measured"
result: "not yet measured"
dashboard_screenshot: "not yet measured"
---

# Chaos Experiment 01: Pod Kill (`test-api`)

- **Hypothesis:** With `replicas: 2`, force-deleting one `test-api` pod maintains continuous HTTP 200 responses on `/work` while the ReplicaSet controller schedules a replacement in `< 60 s`.
- **Steady State:** 2/2 `test-api` pods `Ready`; `/work` returning HTTP `200`.
- **Injection Method:** `kubectl delete pod -n default -l app=test-api --grace-period=0 --force`
- **Observation:** `not yet measured` (populated automatically when `bash chaos/scripts/chaos.sh` runs on cluster)
- **Recovery Seconds:** `not yet measured`
- **Result:** `not yet measured`
- **Dashboard Screenshot:** `not yet measured`
- **Follow-ups:** Run `make chaos` against active K3s cluster to record live timestamps.
