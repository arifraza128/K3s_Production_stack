# Chaos Experiment 3: Network Partition (`NetworkPolicy` Isolation)

- **Hypothesis:** Applying a deny-all `NetworkPolicy` targeting `app: test-api` immediately drops ingress/egress packets; deleting the partition policy restores service reachability in `< 10s`.
- **Baseline:** `GET /api/info` returns `200 OK` (`11ms`).
- **Fault Injection:** `kubectl apply -f chaos-isolate-test-api.yaml` (5s hold) followed by `kubectl delete netpol chaos-isolate-test-api`.
- **Measured `recovery_seconds`:** `6s`
- **Result:** **PASS** — CNI enforced packet drop immediately and restored routing within `1s` after policy removal (`6s` total window).

