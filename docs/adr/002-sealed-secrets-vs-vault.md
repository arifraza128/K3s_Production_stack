# ADR 002: Bitnami Sealed Secrets vs HashiCorp Vault

- **Status:** Accepted
- **Date:** 2026-11-07
- **Evidence Link:** [`docs/evidence/dr-drill/postmortem.md`](../evidence/dr-drill/postmortem.md) · [`security/sealed-secrets/backup-sealed-secrets-key.sh`](../../security/sealed-secrets/backup-sealed-secrets-key.sh)

## Context
GitOps requires storing all cluster configuration declaratively in Git, while [`AGENTS.md`](../../AGENTS.md) Golden Rule #4 prohibits committing plaintext secrets (webhooks, database passwords, tokens).

## Decision
Use **Bitnami Sealed Secrets (`v0.27.2`)** in `kube-system` paired with automated off-cluster master key backup ([`backup-sealed-secrets-key.sh`](../../security/sealed-secrets/backup-sealed-secrets-key.sh)) to AWS S3 (`--sse AES256`).

## Alternatives Considered
1. **Self-Hosted HashiCorp Vault:** Requires `250 MiB+` RAM, raft storage PVCs, and manual/KMS unsealing after node reboots.
2. **External Secrets Operator (ESO) + AWS Secrets Manager:** Adds `$0.40/secret/month` ongoing AWS charges and extra IAM policies.
3. **SOPS + Age:** Requires custom Kustomize decrypt plugins inside the ArgoCD `repo-server` image.

## Consequences
- ✅ **Ultra-lightweight (`~25 MiB` RAM):** Fits comfortably within our single-node memory budget.
- ✅ **Safe in public Git:** `SealedSecret` CRDs are asymmetrically encrypted to the cluster key.
- ❌ **Key loss breaks DR:** If the cluster private key in `kube-system` is lost during a node wipe, existing `SealedSecret` manifests cannot be decrypted — proven in DR Drill #2 and mitigated by mandatory key backup ([`postmortem.md`](../evidence/dr-drill/postmortem.md)).
