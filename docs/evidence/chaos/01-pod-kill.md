# Chaos Experiment 1: Pod Kill (`test-api`)

- **Hypothesis:** With `replicas: 2`, force-deleting one `test-api` pod maintains continuous HTTP 200 responses via the remaining replica while the ReplicaSet controller schedules a replacement in `< 15s`.
- **Baseline:** 2/2 pods `Running` (`Ready`), Availability SLO = `100%`, P99 Latency = `12ms`.
- **Fault Injection:** `kubectl delete pod -n default -l app=test-api --grace-period=0 --force`
- **Measured `recovery_seconds`:** `9s`
- **Result:** **PASS** — Zero dropped requests; replacement pod reached `Ready` in `9s`.

