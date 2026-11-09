---
experiment: "04-cpu-stress"
hypothesis: "CFS CPU limits (200m) throttle a noisy neighbor pod while test-api /work P95 latency stays < 300ms."
injected_at: "not yet measured"
recovered_at: "not yet measured"
recovery_seconds: "not yet measured"
result: "not yet measured"
dashboard_screenshot: "not yet measured"
---

# Chaos Experiment 04: CPU Stress & CFS Quota Throttling

- **Hypothesis:** A noisy-neighbor pod spawning 2 CPU workers is throttled at `200m` by Linux CFS bandwidth control, keeping `test-api` `/work` P95 latency `< 300 ms`.
- **Steady State:** `test-api` `/work` P95 `< 300 ms`.
- **Injection Method:** `stress --cpu 2 --timeout 10s` inside a `limits.cpu: 200m` container.
- **Observation:** `not yet measured`
- **Recovery Seconds:** `not yet measured`
- **Result:** `not yet measured`
- **Dashboard Screenshot:** `not yet measured`
- **Follow-ups:** Run `make chaos` against active K3s cluster to record live timestamps.
