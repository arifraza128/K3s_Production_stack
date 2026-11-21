# Phase 8 Blameless Postmortem — DR Drill #2 (`backup-corruption` / Missing Sealed Secrets Key)

## 1. Summary

During **DR Drill #2 (`2026-11-21-backup-corruption.json`)**, we executed a planned failure scenario simulating a corrupted database dump archive and an unbacked-up Sealed Secrets master key (`sealedsecrets.bitnami.com/sealed-secrets-key`) during cluster disaster recovery. The pre-restore integrity verification gate detected the corrupted payload in `0s`, aborted the destructive restore (`Result: FAIL`), and prevented overwriting live state. Following remediation in **DR Drill #3 (`2026-11-21-db-corruption.json`)**, full service and secret recovery succeeded with a measured **RTO of `15s`** and **RPO of `1s`**.

---

## 2. Impact

- **Severity:** Planned DR Drill Failure (`SEV-2` simulation)
- **User / Workload Impact:** Restore step halted safely by pre-restore integrity gate (`gzip -t` + master key check); zero live data overwritten.
- **Evidence File:** [`2026-11-21-backup-corruption.json`](2026-11-21-backup-corruption.json)

---

## 3. Timeline (UTC — `2026-11-21`)

| Timestamp (UTC) | Event |
| :--- | :--- |
| `15:50:03Z` | **DR Drill #1 (`full-destroy`)** completed successfully (`RTO=11s`, `RPO=1s`, `PASS`). |
| `15:50:15Z` | **DR Drill #2 (`backup-corruption`)** initiated; synthetic corrupted backup header injected. |
| `15:50:17Z` | Pre-restore integrity verification detected invalid archive header / missing key and aborted restore (`Result=FAIL`, `RPO=2s`). |
| `15:50:17Z` | **DR Drill #3 (`db-corruption`)** initiated using backed-up Sealed Secrets master key (`/tmp/sealed-secrets-master-key-*.yaml`) and validated `pg_dump` CronJob. |
| `15:50:33Z` | **DR Drill #3** verified `HTTP 200` on `https://13.207.161.55.sslip.io/work` (`RTO=15s`, `RPO=1s`, `PASS`). |

---

## 4. Root Cause

1. **Asymmetric Key Dependency:** Bitnami Sealed Secrets encrypts `SealedSecret` manifests in Git against the cluster's active private key in `kube-system`. If a K3s node is destroyed and rebuilt without restoring the `sealed-secrets-key` Secret prior to workload sync, the new controller generates a new keypair and fails with `no key could decrypt secret`.
2. **Unverified Dump Risk:** Running `pg_restore` or `psql` directly from an unvalidated backup file risks truncating a database before discovering archive corruption.

---

## 5. What Went Well / What Went Badly

- **What Went Well (✅):**
  - Pre-restore archive integrity check (`gzip -t`) caught the corrupted payload immediately (`0s`) before touching PostgreSQL (`DATABASE.md` §8 rule: *"Never run restore over a live DB without a fresh dump first"*).
  - [backup-sealed-secrets-key.sh](../../../security/sealed-secrets/backup-sealed-secrets-key.sh) exported the active master key cleanly (`RPO=1s`).
- **What Went Badly (❌):**
  - Prior to automating key export inside the DR runbook, key backup was a manual step that could be forgotten after key rotation.

---

## 6. Action Items (Blameless)

| ID | Action Item | Owner | Status |
| :--- | :--- | :--- | :--- |
| **AI-1** | Automate Sealed Secrets master key export in [backup-sealed-secrets-key.sh](../../../security/sealed-secrets/backup-sealed-secrets-key.sh) and `make backup-keys`. | Platform Owner | **Completed** |
| **AI-2** | Enforce pre-restore integrity check in [dr-drill.sh](../../../scripts/dr-drill.sh) before any destructive restore step. | Platform Owner | **Completed** |
| **AI-3** | Document mandatory key-restore ordering in [runbook.md](../../runbook.md) §1 Step 3. | Platform Owner | **Completed** |
