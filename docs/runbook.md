# Operational Runbook — Phoenix Platform (K3s Production Stack)

## 1. Full Cluster Rebuild (Phoenix Recovery)

When an EC2 node in `ap-south-1` is lost or replaced:

```bash
# 1. Provision replacement EC2 node & attach Elastic IP (13.207.161.55)
make apply

# 2. Wait for cloud-init K3s bootstrap
kubectl get nodes -o wide

# 3. CRITICAL: Restore Sealed Secrets master key BEFORE ArgoCD syncs workloads
kubectl apply -f /tmp/sealed-secrets-master-key-latest.yaml

# 4. Bootstrap ArgoCD and deploy Root Application (App-of-Apps)
make bootstrap-gitops

# 5. Restore Gitea PostgreSQL database dump (if PVC was recreated)
make dr-drill
```

---

## 2. Incident Response Playbooks (`Symptom -> Likely cause -> Verify -> Fix -> Link to alert`)

### `TestApiHigh5xxErrorRate` {#testapihigh5xxerrorrate}
- **Symptom:** `[SEV-1] TestApiHigh5xxErrorRate` fires in Discord; Grafana Row 1 Availability drops below `99.5%`.
- **Likely cause:** Synthetic `/fail` chaos injection (`CHAOS_ENDPOINTS_ENABLED=true`) or application regression in `default/test-api`.
- **Verify:**
  ```bash
  kubectl logs -n default -l app=test-api --tail=100
  kubectl get events -n default --sort-by='.lastTimestamp'
  ```
- **Fix:** If caused by a bad deployment, revert the commit on `main` (`git revert HEAD && git push`); ArgoCD self-heals within `15s`. If caused by `/fail` chaos testing, stop the chaos client and wait `2m` for the rate window to clear.
- **Link to alert:** `observability/prometheus/slo-rules.yaml` (`TestApiHigh5xxErrorRate`)

---

### `TestApiHighLatencyP95` {#testapihighlatencyp95}
- **Symptom:** `[SEV-2] TestApiHighLatencyP95` fires in Discord; Grafana Row 1 Latency p95 exceeds `300 ms`.
- **Likely cause:** CPU throttling on `default/test-api` (CPU limit `200m`), node CPU pressure on `t4g.medium`, or `/slow?ms=N` synthetic latency injection.
- **Verify:**
  ```bash
  kubectl top pods -n default
  kubectl top nodes
  ```
- **Fix:** Stop `/slow` chaos traffic or adjust CPU requests/limits in `apps/test-api/k8s/deployment.yaml` via Git PR.
- **Link to alert:** `observability/prometheus/slo-rules.yaml` (`TestApiHighLatencyP95`)

---

### `PhoenixBackupJobFailed` {#phoenixbackupjobfailed}
- **Symptom:** `[SEV-1] PhoenixBackupJobFailed` fires in Discord; Grafana Row 4 shows backup age exceeding threshold.
- **Likely cause:** PostgreSQL `gitea-postgres` unreachable, S3 IAM instance profile permission error, or missing `gitea-db-secret`.
- **Verify:**
  ```bash
  kubectl get jobs,pods -n backup
  kubectl logs -n backup -l job-name --tail=100
  ```
- **Fix:** Verify `gitea-postgres` is Ready in namespace `gitea` and re-trigger a manual test job (`kubectl create job --from=cronjob/gitea-postgres-s3-backup manual-backup-test -n backup`).
- **Link to alert:** `observability/prometheus/slo-rules.yaml` (`PhoenixBackupJobFailed`)

---

### Scrape Target Troubleshooting (Grafana "No data") {#scrape-target-troubleshooting}
- **Symptom:** Grafana SLO panels display `"No data (check ServiceMonitor test-api)"`.
- **Likely cause:** `ServiceMonitor` `monitoring/test-api` not yet applied, `default/test-api` pods not Ready, or `NetworkPolicy` blocking ingress from namespace `monitoring` to `default/test-api:8080`.
- **Verify:**
  ```bash
  kubectl get servicemonitor -n monitoring test-api
  kubectl get pods -n default -l app=test-api
  kubectl get networkpolicy -n default allow-test-api-ingress-and-dns
  ```
- **Fix:** Apply `kubectl apply -k observability --server-side` and generate traffic (`curl http://127.0.0.1:18080/work`).

---

### Kyverno Blocks Pod Creation (`verify-cosign-image-signatures`)
- **Symptom:** `admission webhook "mutate.kyverno.svc-fail" denied the request: image signature verification failed`.
- **Likely cause:** Container image under `ghcr.io/arifraza128/*` was pushed manually without GitHub Actions Cosign keyless OIDC signing, or GHCR package visibility is private.
- **Verify:**
  ```bash
  kubectl get clusterpolicy verify-cosign-image-signatures
  ```
- **Fix:** Ensure the image is built and signed by `.github/workflows/ci-supply-chain.yaml` and the GHCR package visibility is set to Public.

---

### Let's Encrypt TLS Certificate Stuck in `Pending`
- **Symptom:** `Certificate` in `Pending` state; browser receives self-signed Ingress Controller certificate.
- **Likely cause:** Port `80` blocked by security group or Let's Encrypt production rate limit hit during repeated DR drills.
- **Verify:**
  ```bash
  kubectl describe challenge -A
  kubectl get certificate -A
  ```
- **Fix:** Use `letsencrypt-staging` first during drills (`security/ingress-tls/cluster-issuers.yaml`), then switch to `letsencrypt-prod` once HTTP-01 challenge succeeds on `13.207.161.55.sslip.io`.
