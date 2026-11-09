# Phase 4 Evidence — Negative Test 1: Kyverno Admission Webhook Denial

> **Status:** `"not yet measured"` — Run `bash scripts/verify-phase4.sh` on the K3s cluster host (or with `KUBECONFIG` pointing to the cluster) to execute the live admission control negative tests and automatically populate this file with verbatim `kubectl` output.

## 1. Test Objective

Verify that **Kyverno** enforces all three Phase 4 `ClusterPolicy` rules in `Enforce` mode:
1. `verify-cosign-image-signatures` — Rejects any container image under `ghcr.io/arifraza128/*` that is not signed via GitHub Actions keyless Cosign OIDC.
2. `disallow-privileged-and-host-namespaces` — Rejects any pod requesting `privileged: true`, `hostNetwork: true`, `hostPID: true`, or `hostIPC: true`.
3. `require-pod-requests-and-limits` — Rejects any pod missing CPU/memory `requests` or `limits`.

## 2. Measured Cluster Output

- **Timestamp:** `"not yet measured"`
- **Unsigned Image Admission Result:** `"not yet measured"`
- **Privileged Pod Admission Result:** `"not yet measured"`
- **Missing Limits Admission Result:** `"not yet measured"`
