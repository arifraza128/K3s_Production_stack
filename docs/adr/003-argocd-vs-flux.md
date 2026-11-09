# ADR 003: ArgoCD vs FluxCD for GitOps Control Plane

- **Status:** Accepted
- **Date:** 2026-11-07

## Context
Phase 3 requires a declarative GitOps engine supporting the **Application-of-Applications** pattern, automated drift remediation (`selfHeal`), and resource pruning (`prune`).

## Decision
Use **ArgoCD** (`gitops/root-app.yaml` managing `gitops/argocd-apps/`).

## Consequences
- **Pros:**
  - Rich visual topology UI and immediate sync-status visibility (`Synced` / `Healthy`) for portfolio verification.
  - Native support for both Kustomize directories (`security/`, `observability/`, `apps/`, `backup/`) and upstream Helm charts (`gitea-app.yaml`).
  - Demonstrated `14s` self-heal recovery when `Deployment/gitea` was manually deleted.
- **Cons:**
  - Slightly higher memory footprint (`~300Mi` across `argocd-server`, `repo-server`, and `application-controller`) than FluxCD.

