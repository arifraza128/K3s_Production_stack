# Phase 5 Evidence — Observability, 3 SLOs, Discord Alerting & Heartbeat Verification

> **Status:** `"not yet measured"` — Run `bash scripts/verify-phase5.sh` on the K3s cluster host (or with `KUBECONFIG` pointing to the cluster) to execute the live Phase 5 SLO and alerting verification tests and automatically populate this file with verbatim Prometheus/Alertmanager output.

## 1. Test Objectives (per `IMPLEMENTATION_PLAN.md` & `PRD.md` FR-9)

1. **Prometheus + ServiceMonitor + 3 SLO Recording Rules:**
   - Scrape `default/test-api` on `/metrics` every `15s` via `ServiceMonitor` `monitoring/test-api`.
   - Evaluate `test_api:availability:ratio_rate5m` (Target `>= 99.5%`), `test_api:latency_p95:seconds_rate5m` (Target `< 300ms`), and `test_api:error_budget:remaining_ratio`.
2. **Grafana 4-Row Dashboard (`DESIGN.md` §5):**
   - Provision `phoenix-platform-slos` dashboard via sidecar `ConfigMap` (`grafana_dashboard: "1"`) with Row 1 (SLO Status), Row 2 (Traffic & Errors), Row 3 (Platform Health), and Row 4 (Reliability & Backups).
3. **Test 1 — Force 5xx via `/fail` -> `TestApiHigh5xxErrorRate` Fires -> Discord:**
   - Trigger synthetic HTTP `500` errors on `GET /fail` and verify `TestApiHigh5xxErrorRate` transitions to `firing` and dispatches to Discord in `[SEV-1] <alert> — <summary> — runbook: <url> — since <time>` format (`DESIGN.md` §6).
4. **Test 2 — Dead-Man's-Switch Heartbeat -> Healthchecks.io:**
   - Verify `DeadMansSwitchHeartbeat` and `cronjob/healthchecks-heartbeat`, then suspend heartbeat to trigger external missing-ping alert.

---

## 2. Measured Cluster Output

- **Timestamp:** `"not yet measured"`
- **SLO Recording Rules Output:** `"not yet measured"`
- **Test 1 (`/fail` -> `TestApiHigh5xxErrorRate` Firing Output):** `"not yet measured"`
- **Test 2 (Heartbeat Suspension Test Output):** `"not yet measured"`
