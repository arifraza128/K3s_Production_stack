---
experiment: "02-oom-kill"
hypothesis: "A container exceeding its 64Mi memory limit is OOMKilled by cgroup v2 without degrading co-located test-api or gitea pods."
injected_at: "not yet measured"
recovered_at: "not yet measured"
recovery_seconds: "not yet measured"
result: "not yet measured"
dashboard_screenshot: "not yet measured"
---

# Chaos Experiment 02: OOM-Kill Containment

- **Hypothesis:** A container attempting to allocate `250Mi` when bounded by a `64Mi` memory limit is terminated with `OOMKilled` (`exitCode: 137`) without degrading node memory or co-located pods.
- **Steady State:** Node memory healthy; `test-api` pods `Ready`.
- **Injection Method:** `stress --vm 1 --vm-bytes 250M --vm-hang 1` inside a `64Mi` memory-limited pod.
- **Observation:** `not yet measured`
- **Recovery Seconds:** `not yet measured`
- **Result:** `not yet measured`
- **Dashboard Screenshot:** `not yet measured`
- **Follow-ups:** Run `make chaos` against active K3s cluster to record live timestamps.
