# API.md — Phoenix Platform Test API Specification

## Overview
The `test-api` service is a lightweight, instrumented Python HTTP microservice designed to validate:
- **Phase 4:** Supply-chain security (Trivy scan, Syft SBOM, Cosign keyless signature verification via Kyverno, non-root execution, read-only root filesystem).
- **Phase 5:** Prometheus metrics scraping, SLO recording rules, and synthetic 5xx alerting to Discord.
- **Phase 6:** Ingress path filtering (public `/api/*` vs blocked internal `/crash`).
- **Phase 7:** Chaos engineering resilience (`pod-kill`, `oom-kill`, `network-partition`, `cpu-stress`).

---

## Endpoints

### 1. `GET /` or `GET /api/info`
Returns service metadata, build version, hostname, and status.
- **Response (`200 OK`):**
  ```json
  {
    "service": "phoenix-test-api",
    "version": "1.0.0",
    "status": "ok",
    "hostname": "test-api-7c8d9f6b4-x9k2p"
  }
  ```

### 2. `GET /healthz`
Kubernetes `livenessProbe` endpoint.
- **Response (`200 OK`):** `{"status": "alive"}`

### 3. `GET /readyz`
Kubernetes `readinessProbe` endpoint.
- **Response (`200 OK`):** `{"status": "ready"}`

### 4. `GET /metrics`
Prometheus text exposition format endpoint (`text/plain; version=0.0.4`).
Exposes:
- `http_requests_total{method, path, status}` (Counter)
- `http_request_duration_seconds_bucket{le, path}` (Histogram for P99 SLO)

### 5. `POST /fail` or `GET /fail`
Synthetic failure endpoint for **Phase 5 Alertmanager / Discord testing**.
Increments the `status="500"` counter and returns HTTP `500 Internal Server Error`.
- **Response (`500 Internal Server Error`):**
  ```json
  {
    "error": "simulated_5xx_failure",
    "message": "Triggered synthetic 500 error for SLO burn alert validation"
  }
  ```

### 6. `POST /crash` or `GET /crash`
Internal diagnostic endpoint that simulates process termination (`os._exit(1)`).
- **Phase 6 Security Requirement:** Must be **blocked publicly** (`403 Forbidden` / `404 Not Found`) at the `ingress-nginx` layer so external callers on `<eip>.sslip.io/crash` cannot terminate the pod.

