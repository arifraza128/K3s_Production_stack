# ADR 002: Bitnami Sealed Secrets vs HashiCorp Vault

- **Status:** Accepted
- **Date:** 2026-11-07

## Context
GitOps requires storing all cluster state in Git, but committing plaintext Kubernetes `Secret` manifests violates security guardrails (`gitleaks`). We evaluated Bitnami Sealed Secrets vs self-hosted HashiCorp Vault on a 2GB RAM `t4g.small` node.

## Decision
Use **Bitnami Sealed Secrets** (`v0.27.2`) with automated S3 master key backup (`backup-sealed-secrets-key.sh`).

## Consequences
- **Pros:**
  - Lightweight controller (`~30Mi` RAM) compared to HashiCorp Vault (`250Mi+` RAM + storage backend + unseal operational burden).
  - Asymmetric encryption via `kubeseal` allows safe storage of `SealedSecret` CRDs directly in Git.
- **Cons:**
  - Requires backing up the cluster private key in `kube-system` to survive full node rebuilds (verified in Phase 8 DR Drill #2 & #3).

