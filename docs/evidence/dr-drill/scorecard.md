# Phase 8 Evidence — Disaster Recovery (DR) Drill Scorecard

> Generated from `docs/evidence/dr-drill/<date>-<scenario>.json` per [`DATABASE.md`](../../../DATABASE.md) §6 and [`DESIGN.md`](../../../DESIGN.md) §3. Per [`AGENTS.md`](../../../AGENTS.md) Golden Rule #3, unmeasured fields remain `"not yet measured"` until `scripts/dr-drill.sh` is executed on the live cluster.

| Date | Scenario | RTO | RPO | Data loss | Result | Link |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `not yet measured` | `full-destroy` (Drill #1: Full platform rebuild + S3 restore) | `not yet measured` | `not yet measured` | `not yet measured` | `not yet measured` | Pending JSON |
| `not yet measured` | `backup-corruption` (Drill #2: Planned failure — missing `sealed-secrets-key`) | `not yet measured` | `not yet measured` | `not yet measured` | `FAIL (Planned)` | [`postmortem.md`](postmortem.md) |
| `not yet measured` | `db-corruption` (Drill #3: Post-fix restore with `sealed-secrets-key` + `pg_dump`) | `not yet measured` | `not yet measured` | `not yet measured` | `not yet measured` | Pending JSON |
