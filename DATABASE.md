# DATABASE.md — Phoenix Platform

> Phoenix does **not** design an application schema. The only database is PostgreSQL for Gitea (schema owned by Gitea). This doc defines the data lifecycle: backup, restore, verification, and the evidence data model.

## 1. Technology

PostgreSQL (single instance, StatefulSet + PVC, pinned version) serving Gitea only. Test API is stateless.

---

## 2. Ownership & Access

| Principal | Access |
| :--- | :--- |
| Gitea | Own DB/user only |
| `pg-dump` CronJob | Read-only role (`pg_dump` needs SELECT) |
| Humans | `kubectl exec` / port-forward; no public exposure |

**NetworkPolicy:** only Gitea pods and the backup job may reach `Postgres:5432`.

---

## 3. Sensitive Data

Credentials in sealed secrets. Backups encrypted at rest (S3 SSE) and bucket is private + versioned. No real personal data stored in this demo.

---

## 4. Backup Strategy

| Layer | Tool | Frequency | Target | Retention |
| :--- | :--- | :--- | :--- | :--- |
| K8s resources + PVC (Velero) | Velero | daily | `S3 phoenix-backups/velero/` | 14 d |
| Logical DB | `pg_dump -Fc` CronJob | every 6 h ⚠ choose | `S3 phoenix-backups/pgdump/` | 14 d + weekly 8 |
| Sealed Secrets key | script | on change | `S3 phoenix-backups/keys/` (encrypted) | versioned |

**Targets (to be validated by drills, not asserted):** RPO <= backup interval; RTO measured in scorecard.

---

## 5. Restore & Verification

1. Provision fresh cluster (platform stack).
2. Restore `sealed-secrets` key -> ArgoCD syncs workloads.
3. `velero restore` (resources/PVCs) or `pg_restore` into fresh Postgres.
4. Verify: Gitea `/api/healthz` OK; row/repo count matches pre-drill snapshot; login works.
5. Record result in evidence.

**Stretch (FR-17):** weekly CronJob restores latest dump into a throwaway Postgres, compares counts, pushes `backup_restore_success` (0/1) + `backup_restore_duration_seconds` to Pushgateway; alert if 0 or stale.

---

## 6. Evidence Data Model (files in Git)

`docs/evidence/dr-drill/<date>-<scenario>.json`

```json
{
  "date": "YYYY-MM-DD",
  "scenario": "full-destroy | db-corruption | backup-corruption",
  "start_ts": "ISO-8601",
  "end_ts": "ISO-8601",
  "rto_seconds": 0,
  "rpo_seconds": 0,
  "data_loss": "none | description",
  "steps": [{"name": "", "seconds": 0, "status": "pass|fail"}],
  "result": "PASS | FAIL",
  "notes": "",
  "links": {"logs": "", "screenshots": []}
}
```

`docs/evidence/chaos/NN-<name>.md` frontmatter: `experiment`, `hypothesis`, `injected_at`, `recovered_at`, `recovery_seconds`, `result`, `dashboard_screenshot`. `scorecard.md` is generated from the JSON files (script), never hand-edited numbers.

---

## 7. Migration & Seed

Gitea runs its own migrations. Seed: one demo org/repo created by a documented script so row-count verification has a baseline.

---

## 8. Rules

- Never run restore over a live DB without a fresh dump first.
- Never test restore against production data store directly — use a throwaway.

