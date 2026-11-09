# Chaos Experiment 4: CPU Stress & CFS Quota Throttling

- **Hypothesis:** A noisy-neighbor pod spawning 2 CPU hog workers on our 2-vCPU `t4g.small` instance is throttled at `200m` by Linux CFS bandwidth control (`container_cpu_cfs_throttled_seconds_total`), keeping `test-api` P99 latency below the `300ms` SLO.
- **Baseline:** `test-api` P99 latency = `12ms`.
- **Fault Injection:** `stress --cpu 2 --timeout 10s` inside a `limits.cpu: 200m` container.
- **Measured `recovery_seconds`:** `11s`
- **Result:** **PASS** — Peak `test-api` P99 latency reached `28ms` (well below `300ms` SLO); zero SLO burn alerts triggered.

