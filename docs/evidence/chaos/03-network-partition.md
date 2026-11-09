---
experiment: "03-network-partition"
hypothesis: "Applying a deny-all NetworkPolicy isolates test-api traffic immediately; deleting the policy restores connectivity in < 60s."
injected_at: "not yet measured"
recovered_at: "not yet measured"
recovery_seconds: "not yet measured"
result: "not yet measured"
dashboard_screenshot: "not yet measured"
---

# Chaos Experiment 03: Network Partition (`NetworkPolicy` Isolation)

- **Hypothesis:** Applying a deny-all `NetworkPolicy` targeting `app: test-api` drops traffic immediately; removing the policy restores reachability in `< 60 s`.
- **Steady State:** `GET /work` returns `200 OK`.
- **Injection Method:** `kubectl apply/delete networkpolicy chaos-isolate-test-api -n default`
- **Observation:** `not yet measured`
- **Recovery Seconds:** `not yet measured`
- **Result:** `not yet measured`
- **Dashboard Screenshot:** `not yet measured`
- **Follow-ups:** Run `make chaos` against active K3s cluster to record live timestamps.
