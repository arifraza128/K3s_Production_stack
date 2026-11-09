# Phase 8 Evidence — Disaster Recovery (DR) Drill Scorecard

## Target Objectives
- **Target RTO (Recovery Time Objective):** `< 300s` (5 minutes)
- **Target RPO (Recovery Point Objective):** `< 21600s` (6-hour `pg_dump` schedule) / `< 15s` (on-demand snapshot)

## Measured Drill Runs (`>= 3` Drills)

| Drill # | Scenario | SealedSecrets Key | PostgreSQL Restore | Measured RTO | Measured RPO | Result |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Drill 1** | Namespace workload loss (`gitea` + `test-api`) | Intact (`kube-system`) | PVC retained + ArgoCD self-heal | `19s` | `0s` | **PASS** |
| **Drill 2 (Planned Failure)** | Full cluster reset **without** `sealed-secrets-key` backup | Missing (New key generated) | `SealedSecret` failed to decrypt DB password (`Err: no key could decrypt`) | `N/A` (Aborted at `142s`) | `N/A` | **FAIL (Planned)** |
| **Drill 3 (Post-Fix)** | Full restore using `backup-sealed-secrets-key.sh` + `pg_dump` | Restored prior to ArgoCD sync | Restored `gitea-db.sql.gz` cleanly | `68s` | `4s` | **PASS** |

