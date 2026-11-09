---
experiment: "05-disk-fill"
hypothesis: "Writing 60Mi into a 50Mi ephemeral-storage bounded container triggers eviction/cleanup without exhausting node rootfs."
injected_at: "not yet measured"
recovered_at: "not yet measured"
recovery_seconds: "not yet measured"
result: "not yet measured"
dashboard_screenshot: "not yet measured"
---

# Chaos Experiment 05: Disk Fill / Ephemeral Storage Pressure

- **Hypothesis:** Writing `60Mi` to `/tmp` inside a container with `limits.ephemeral-storage: 50Mi` triggers kubelet eviction or write termination before the 30GB `gp3` root volume experiences `DiskPressure`.
- **Steady State:** Node `DiskPressure=False`.
- **Injection Method:** `dd if=/dev/zero of=/tmp/fill bs=1M count=60` in a `50Mi` ephemeral-storage bounded pod.
- **Observation:** `not yet measured`
- **Recovery Seconds:** `not yet measured`
- **Result:** `not yet measured`
- **Dashboard Screenshot:** `not yet measured`
- **Follow-ups:** Run `make chaos` against active K3s cluster to record live timestamps.
