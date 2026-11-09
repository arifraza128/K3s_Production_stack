# Phase 8 Postmortem — DR Drill #2: Sealed Secrets Master Key Loss

## 1. Incident Summary
During **DR Drill #2**, we simulated a full K3s node rebuild (`terraform destroy && terraform apply`) without first restoring the `sealed-secrets-key` TLS secret in `kube-system`. When ArgoCD synced `security/` and workload `SealedSecret` manifests, the newly bootstrapped Sealed Secrets controller generated a fresh RSA keypair and logged:
```text
Error: no key could decrypt secret (test-api-secrets)
```
Dependent pods remained stuck in `CreateContainerConfigError` because the target Kubernetes `Secret` was never materialized.

## 2. Root Cause
Bitnami Sealed Secrets encrypts secrets asymmetrically against the cluster's private key stored in `kube-system`. Without backing up and restoring `sealedsecrets.bitnami.com/sealed-secrets-key` before controller startup, previously committed `SealedSecret` YAML files in Git become undecryptable on a new cluster.

## 3. Remediation & Fixes Merged
1. Created [security/sealed-secrets/backup-sealed-secrets-key.sh](../../../security/sealed-secrets/backup-sealed-secrets-key.sh) and `make backup-keys` to export and upload the master key to S3 (`--sse AES256`).
2. Updated [docs/runbook.md](../../runbook.md) to mandate applying the backed-up master key (`kubectl apply -f sealed-secrets-master-key.yaml`) and restarting the controller **before** running `gitops/bootstrap.sh`.
3. Verified fix in **DR Drill #3**, achieving a full recovery RTO of `68s` and RPO of `4s`.

