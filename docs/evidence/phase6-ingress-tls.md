# Phase 6 Evidence — Ingress-NGINX, Let's Encrypt TLS (`13.207.161.55.sslip.io`) & Public Path Lockdown

- **Measured Timestamp (UTC):** `2026-11-21T15:35:58Z`
- **Public HTTPS Domain:** `https://13.207.161.55.sslip.io`
- **Verification Script:** `scripts/verify-phase6.sh`

---

## 1. ClusterIssuers, Certificate & Ingress Status

```text
NAME                                                READY   STATUS                                                 AGE
clusterissuer.cert-manager.io/letsencrypt-prod      True    The ACME account was registered with the ACME server   54s
clusterissuer.cert-manager.io/letsencrypt-staging   True    The ACME account was registered with the ACME server   54s

NAME                                            READY   SECRET              ISSUER             STATUS                                          AGE
certificate.cert-manager.io/phoenix-sslip-tls   True    phoenix-sslip-tls   letsencrypt-prod   Certificate is up to date and has not expired   54s

NAME                                               CLASS   HOSTS                    ADDRESS        PORTS     AGE
ingress.networking.k8s.io/phoenix-public-ingress   nginx   13.207.161.55.sslip.io   172.31.20.41   80, 443   55s
```

---

## 2. X.509 TLS Certificate Verification (`openssl s_client`)

```text
subject=CN=13.207.161.55.sslip.io
issuer=C=US, O=Let's Encrypt, CN=YR1
notBefore=Nov 21 14:39:16 2026 GMT
notAfter=Feb 19 14:39:15 2027 GMT
```

---

## 3. Positive Test: Publicly Routable Endpoints (`/healthz`, `/version`, `/work`)

```text
GET https://13.207.161.55.sslip.io/healthz
{"status": "ok"}
HTTP_STATUS:200

GET https://13.207.161.55.sslip.io/version
{"version": "1.0.0", "sha": "7c2dd7e", "image_digest": "sha256:pinned"}
HTTP_STATUS:200

GET https://13.207.161.55.sslip.io/work
{"status": "completed", "request_id": "e2543882-a861-4cf1-a652-cb17071f949a"}
HTTP_STATUS:200
```

---

## 4. Negative Test: Public Ingress Blocks Chaos & Internal Endpoints (`/crash`, `/fail`, `/slow`, `/metrics`)

```text
POST https://13.207.161.55.sslip.io/crash
{"error":{"code":"FORBIDDEN","message":"Internal endpoint not routable via public ingress","request_id":"ingress-deny"}}

HTTP_STATUS:403

GET https://13.207.161.55.sslip.io/fail
{"error":{"code":"FORBIDDEN","message":"Internal endpoint not routable via public ingress","request_id":"ingress-deny"}}

HTTP_STATUS:403

GET https://13.207.161.55.sslip.io/slow?ms=500
{"error":{"code":"FORBIDDEN","message":"Internal endpoint not routable via public ingress","request_id":"ingress-deny"}}

HTTP_STATUS:403

GET https://13.207.161.55.sslip.io/metrics
{"error":{"code":"FORBIDDEN","message":"Internal endpoint not routable via public ingress","request_id":"ingress-deny"}}

HTTP_STATUS:403
```
