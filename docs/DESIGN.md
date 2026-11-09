# DESIGN.md — Phoenix Platform (K3s Production Stack)

## 1. System Architecture

```mermaid
flowchart TD
    User["External User / Operator"] -->|HTTPS 443<br/>13.207.161.55.sslip.io| Ingress["ingress-nginx + cert-manager"]
    GitHub["GitHub Repo + Actions CI<br/>(Trivy + Syft SBOM + Cosign)"] -->|GitOps Pull| ArgoCD["ArgoCD (App-of-Apps)"]
    GitHub -->|Signed Image| GHCR["GHCR Container Registry"]

    subgraph K3s ["AWS EC2 ARM64 (ap-south-1) — K3s Cluster"]
        Ingress -->|/api/* (blocks /crash)| TestAPI["test-api (2 Replicas)"]
        Ingress -->|/gitea| Gitea["Gitea + PostgreSQL (5Gi PVC)"]
        Ingress -->|/grafana| Grafana["Grafana Dashboards"]

        ArgoCD -->|Reconciles| Security["Security Layer<br/>Kyverno + Sealed Secrets + NetPol"]
        ArgoCD -->|Reconciles| Obs["Observability Layer<br/>Prometheus + Alertmanager + Grafana"]
        ArgoCD -->|Reconciles| Apps["Workloads Layer<br/>Gitea + test-api"]
        ArgoCD -->|Reconciles| Backup["Backup Layer<br/>Velero + pg_dump CronJob"]

        Security -.->|verifyImages Cosign| GHCR
        Obs -->|Scrapes /metrics| TestAPI
    end

    Obs -->|5xx SLO Alert| Discord["Discord Webhook"]
    Obs -->|DeadMansSwitch| HC["Healthchecks.io Heartbeat"]
    Backup -->|Encrypted Backups| S3["AWS S3 Bucket (ap-south-1)"]
```

## 2. Core Design Principles
1. **Immutable Infrastructure & GitOps Control Plane:** All cluster workloads are reconciled declaratively by ArgoCD from `gitops/argocd-apps/` with `selfHeal: true` and `prune: true`.
2. **Zero-Trust Supply Chain:** Every container image built in CI is scanned by Trivy (`HIGH`/`CRITICAL` gate), cataloged with a Syft CycloneDX SBOM, and signed keyless via Sigstore Cosign. Kyverno's `verifyImages` policy blocks unsigned images at admission.
3. **Defense-in-Depth Networking:** Default-deny `NetworkPolicies` isolate namespaces, while `ingress-nginx` enforces TLS via `cert-manager` (`sslip.io`), rate limits (`10 RPS`), and blocks administrative endpoints (`/crash`).
4. **Actionable Observability (3 SLOs):**
   - **SLO 1 — Availability:** `>= 99.5%` non-5xx responses over a 5m/30d window.
   - **SLO 2 — Latency:** `P99 < 300ms` for `/api/*` requests.
   - **SLO 3 — Platform Heartbeat:** Continuous `DeadMansSwitch` ping to Healthchecks.io to detect monitoring pipeline blackouts.
5. **Verified Disaster Recovery:** Automated Velero cluster snapshots + `pg_dump` database backups to S3, validated via timed `dr-drill.sh` runs measuring actual RTO and RPO.

