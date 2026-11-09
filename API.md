# API.md — Phoenix Platform

> Defines the interfaces: the Test API (chaos target) and the platform's external integrations. Only required endpoints.

## 1. Test API

Small Go (or Node/Python) service, stateless, exposes Prometheus metrics. Purpose: a controllable target for SLOs and chaos.

| Method | Path | Purpose | Exposure |
| :--- | :--- | :--- | :--- |
| `GET` | `/healthz` | Liveness. 200 if process is up | cluster + public |
| `GET` | `/readyz` | Readiness. 200 only when ready to serve | cluster |
| `GET` | `/version` | Build info (git sha, image digest) | public |
| `GET` | `/work` | Normal request with small realistic latency; SLO target path | public |
| `GET` | `/metrics` | Prometheus metrics | cluster only |
| `GET` | `/slow?ms=N` | Sleep N ms (max cap, e.g. 5000) | **internal only** |
| `GET` | `/fail` | Returns 500 | **internal only** |
| `POST` | `/crash` | Exits process (simulates crash) | **internal only** |

**Safety rule:** `/slow`, `/fail`, `/crash` are enabled only when `CHAOS_ENDPOINTS_ENABLED=true`, and are excluded from the public Ingress; NetworkPolicy allows them only from the chaos namespace/runner. (Otherwise anyone on the internet can crash your demo.)

### Error format (all non-2xx JSON)

```json
{"error": {"code": "string", "message": "string", "request_id": "uuid"}}
```

### Metrics (names are contract)

- `http_requests_total{path,method,status}`
- `http_request_duration_seconds_bucket{path}`
- `app_build_info{version,sha}`

---

## 2. SLOs (defined on `/work`)

| SLO | Target (initial, tune after baseline) | SLI |
| :--- | :--- | :--- |
| **Availability** | 99.5% over 30 d | non-5xx / total |
| **Latency** | 95% of requests < 300 ms | histogram bucket |
| **Recovery** | pod recovers < 60 s after kill | chaos evidence (not Prometheus) |

Alerts use multi-window burn rate; avoid noisy single-spike alerts.

---

## 3. Platform Integrations

| Integration | Direction | Auth | Failure handling |
| :--- | :--- | :--- | :--- |
| GitHub -> ArgoCD | pull | read-only deploy key/HTTPS | ArgoCD retries; OutOfSync alert |
| GitHub Actions -> GHCR | push | `GITHUB_TOKEN` | job fails, nothing deployed |
| Cosign signing | CI | GitHub OIDC (keyless) | unsigned image can't be admitted |
| Kyverno -> registry | verify | public Rekor/Fulcio identity match | deny admission |
| Alertmanager -> Discord | webhook | secret URL (sealed) | on failure, Healthchecks heartbeat still catches total outage |
| Cluster -> Healthchecks.io | ping every N min | secret URL | missing ping = external alert |
| Velero / pg-dump -> S3 | push | instance role | backup-failed alert |
| cert-manager -> Let's Encrypt | ACME | HTTP-01 | use **staging issuer** during drills to avoid rate limits |

---

## 4. Webhooks

Alertmanager payload -> Discord. No inbound public webhooks in MVP (smaller attack surface).

---

## 5. Rate Limiting

`ingress-nginx` `limit-rps` on public Test API paths.

---

## 6. Environment Variables

| Var | Where | Secret? |
| :--- | :--- | :--- |
| `CHAOS_ENDPOINTS_ENABLED` | Test API | no |
| `PORT` | Test API | no |
| `DISCORD_WEBHOOK_URL` | Alertmanager | **yes (sealed)** |
| `HEALTHCHECKS_URL` | heartbeat CronJob | **yes (sealed)** |
| `AWS_REGION`, bucket names | backup jobs | no |

---

## 7. Privacy & Logging

Never log tokens/webhook URLs. Request logs: method, path, status, duration, `request_id` only.

