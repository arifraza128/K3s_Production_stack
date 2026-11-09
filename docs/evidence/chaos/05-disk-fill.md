# Chaos Experiment 5: Disk Fill / Ephemeral Storage Pressure

- **Hypothesis:** Writing `60Mi` to `/tmp` inside a container with `limits.ephemeral-storage: 50Mi` triggers kubelet eviction or write termination before the 30GB `gp3` root volume experiences `DiskPressure`.
- **Baseline:** Root volume free space `24.1 GiB`; Node condition `DiskPressure=False`.
- **Fault Injection:** `dd if=/dev/zero of=/tmp/fill bs=1M count=60` in a `50Mi` ephemeral-storage bounded pod.
- **Measured `recovery_seconds`:** `8s`
- **Result:** **PASS** — Ephemeral storage quota contained the write burst and cleaned up on pod termination in `8s`; Node `DiskPressure` remained `False`.

