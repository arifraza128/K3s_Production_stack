# ADR 003: ArgoCD vs FluxCD for GitOps Control Plane

- **Status:** Accepted
- **Date:** 2026-11-07
- **Evidence Link:** [`docs/evidence/gitops-selfheal.md`](../evidence/gitops-selfheal.md) · [`gitops/root-app.yaml`](../../gitops/root-app.yaml)

## Context
Phase 3 requires a GitOps control plane that pulls from our GitHub repository (per [`PRD.md`](../../PRD.md) §12 A3, avoiding circular dependency on in-cluster Gitea), reconciles both Kustomize directories and third-party Helm charts, and enforces `selfHeal: true` and `prune: true`.

## Decision
Use **ArgoCD** with the **Application-of-Applications** pattern ([`gitops/root-app.yaml`](../../gitops/root-app.yaml) watching `gitops/argocd-apps/`).

## Alternatives Considered
1. **FluxCD v2:** Lower memory footprint, but lacks a built-in visual topology UI for portfolio reviewers to inspect sync waves and application health at a glance.
2. **Push-based CI (`kubectl apply` from GitHub Actions):** Requires exposing port `6443` and cluster admin credentials to external CI runners, violating [`ARCHITECTURE.md`](../../ARCHITECTURE.md) §11 security boundaries.

## Consequences
- ✅ **Measured self-healing:** Restores deleted deployments in `8s` and reverts manual replica drift (`3 -> 2`) in `3s` ([`gitops-selfheal.md`](../evidence/gitops-selfheal.md)).
- ✅ **Ordered sync waves:** Coordinates CRDs (`00-kyverno`, `02a-kube-prometheus-stack`, `05b-cert-manager`) ahead of dependent policies and rules.
- ❌ **Memory overhead during Helm rendering:** `argocd-repo-server` spikes RAM when rendering large charts like `kube-prometheus-stack`, mitigated by sizing to `t4g.medium` + `4 GiB` swapfile.
