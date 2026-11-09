# Chaos Experiment 2: OOM-Kill Containment

- **Hypothesis:** A container attempting to allocate `250Mi` when bounded by a `64Mi` cgroup v2 memory limit (enforced by Kyverno `require-pod-requests-and-limits`) is terminated with `OOMKilled` (`exitCode: 137`) without degrading node memory or co-located pods.
- **Baseline:** Node memory utilization `48%`; `test-api` pods healthy.
- **Fault Injection:** `stress --vm 1 --vm-bytes 250M --vm-hang 1` inside a `64Mi` memory-limited pod.
- **Measured `recovery_seconds`:** `4s`
- **Result:** **PASS (`OOMKilled`)** — Kernel OOM killer isolated and terminated the offending container in `4s` with zero impact on `test-api` or `gitea`.

