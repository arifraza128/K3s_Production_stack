# Phase 6 Evidence — Ingress-NGINX, Let's Encrypt TLS (`13.207.161.55.sslip.io`) & Public Path Lockdown

> **Status:** `"not yet measured"` — Run `bash scripts/verify-phase6.sh` on the K3s cluster host (or with `KUBECONFIG` pointing to the cluster) to execute the live Phase 6 HTTPS and security boundary verification tests and automatically populate this file with verbatim `curl` and `kubectl` output.

## 1. Test Objectives (per `IMPLEMENTATION_PLAN.md` Phase 6 & `PRD.md` FR-10)

1. **`ingress-nginx` + `cert-manager` on `13.207.161.55.sslip.io`:**
   - Replace K3s default Traefik on host ports `80`/`443` with `ingress-nginx` (`v4.11.3`).
   - Issue ACME HTTP-01 TLS certificate via `cert-manager` (`v1.16.2`) using `letsencrypt-staging` first, followed by `letsencrypt-prod` (`Certificate/phoenix-sslip-tls` `Ready=True`).
2. **Rate Limiting & Intended Public Paths Only (`API.md` §1, §5 & `ARCHITECTURE.md` §11):**
   - Enforce `nginx.ingress.kubernetes.io/limit-rps: "10"`.
   - Expose **only** `/healthz`, `/version`, and `/work` publicly (`HTTP 200`).
3. **Negative Security Boundary Test (`/crash`, `/fail`, `/slow`, `/metrics` Blocked Publicly):**
   - Verify `POST https://13.207.161.55.sslip.io/crash`, `GET /fail`, `GET /slow`, and `GET /metrics` are rejected (`HTTP 403` / `404`) at the public ingress edge.

---

## 2. Measured Cluster & Public HTTPS Output

- **Timestamp:** `"not yet measured"`
- **Let's Encrypt Certificate Status:** `"not yet measured"`
- **Public HTTPS Allowed Endpoints (`/healthz`, `/version`, `/work`):** `"not yet measured"`
- **Public HTTPS Blocked Endpoints (`POST /crash`, `GET /fail`, `GET /slow`, `GET /metrics`):** `"not yet measured"`
