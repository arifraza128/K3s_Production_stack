# Phoenix Platform — K3s Production Stack

> A production-grade, security-hardened **K3s Kubernetes Platform** on AWS ARM64 (`ap-south-1`), managed end-to-end via **ArgoCD GitOps**, **Cosign + Kyverno Supply-Chain Security**, **Prometheus/Grafana SLO Alerting**, **Chaos Engineering**, and **Velero/S3 Disaster Recovery**.

---

## 1. Architecture Overview

```mermaid
flowchart TD
    User["External Traffic"] -->|HTTPS 443<br/>13.207.161.55.sslip.io| Ingress["ingress-nginx + cert-manager"]
    GH["GitHub Actions CI<br/>(Trivy + Syft SBOM + Cosign)"] -->|GitOps Sync| ArgoCD["ArgoCD (App-of-Apps)"]
    GH -->|Signed Image + SBOM| GHCR["GHCR Container Registry"]

    subgraph AWS ["AWS ap-south-1 — Ubuntu 22.04 ARM64 (t4g.small) K3s Cluster"]
        Ingress -->|/api/* (blocks /crash)| TestAPI["test-api (2 Replicas, Non-Root)"]
        Ingress -->|NodePort / Ingress| Gitea["Gitea + PostgreSQL (5Gi PVC)"]
        Ingress -->|/grafana| Grafana["Grafana SLO Dashboards"]

        ArgoCD -->|01-security.yaml| Sec["Security Layer<br/>Kyverno + Sealed Secrets + NetPol"]
        ArgoCD -->|02-observability.yaml| Obs["Observability Layer<br/>Prometheus + Alertmanager + Grafana"]
        ArgoCD -->|03-workloads.yaml & gitea-app.yaml| Workloads["Workloads Layer<br/>Gitea + test-api"]
        ArgoCD -->|04-backup.yaml| Backup["Backup Layer<br/>Velero + pg_dump CronJob"]
    end

    Obs -->|5xx Burn Alert| Discord["Discord Webhook"]
    Obs -->|DeadMansSwitch| HC["Healthchecks.io Heartbeat"]
    Backup -->|Encrypted Snapshots| S3["AWS S3 (ap-south-1)"]
```

---

## 2. Phase Implementation & Evidence Matrix

| Phase | Scope | Key Artifacts | Measured Metric / Outcome | Evidence Link |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 0** | Repo, Docs & Guardrails | [`.gitignore`](.gitignore), [`.env.example`](.env.example), [`Makefile`](Makefile), [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) | Secret protection + AWS Budget Alert (`$10`) | [`docs/cost.md`](docs/cost.md) |
| **Phase 1** | Terraform AWS + Cloud-Init K3s | [`terraform/main.tf`](terraform/main.tf), [`cloud-init/k3s-install.yaml`](cloud-init/k3s-install.yaml) | Node `Ready` on `t4g.small` (`13.207.161.55`) | [`screenshots/`](screenshots/) |
| **Phase 2** | Stateful Workload (Gitea + PG) | [`apps/gitea/values.yaml`](apps/gitea/values.yaml) | `5Gi` PVC bound; HTTP `30080` / SSH `30022` | [`apps/gitea/values.yaml`](apps/gitea/values.yaml) |
| **Phase 3** | GitOps (ArgoCD App-of-Apps) | [`gitops/root-app.yaml`](gitops/root-app.yaml), [`gitops/argocd-apps/`](gitops/argocd-apps/) | Self-heal recovery in [`14s`](docs/evidence/gitops-selfheal.md); drift revert in [`6s`](docs/evidence/gitops-selfheal.md) | [`docs/evidence/gitops-selfheal.md`](docs/evidence/gitops-selfheal.md) |
| **Phase 4** | Test API + Supply-Chain Security | [`.github/workflows/ci-supply-chain.yaml`](.github/workflows/ci-supply-chain.yaml), [`security/kyverno-policies/`](security/kyverno-policies/) | Trivy `HIGH/CRITICAL` gate, Syft SBOM, Cosign keyless `verifyImages`, Sealed Secrets | [`docs/API.md`](docs/API.md) |
| **Phase 5** | Observability & 3 SLOs | [`observability/prometheus/slo-rules.yaml`](observability/prometheus/slo-rules.yaml), [`observability/grafana/`](observability/grafana/) | Availability `>=99.5%`, P99 `<300ms`, Discord + Healthchecks alerts | [`observability/`](observability/) |
| **Phase 6** | Ingress + Let's Encrypt TLS | [`security/ingress-tls/`](security/ingress-tls/) | HTTPS on `13.207.161.55.sslip.io`, `10 RPS` rate limit, `/crash` blocked (`403`) | [`security/ingress-tls/ingress-routes.yaml`](security/ingress-tls/ingress-routes.yaml) |
| **Phase 7** | Reliability Proof (5 Chaos Runs) | [`chaos/scripts/chaos.sh`](chaos/scripts/chaos.sh), [`chaos/chaos-mesh-experiments/`](chaos/chaos-mesh-experiments/) | Pod-kill [`9s`](docs/evidence/chaos/01-pod-kill.md), OOM [`4s`](docs/evidence/chaos/02-oom-kill.md), NetPol [`6s`](docs/evidence/chaos/03-network-partition.md), CPU [`11s`](docs/evidence/chaos/04-cpu-stress.md), Disk [`8s`](docs/evidence/chaos/05-disk-fill.md) | [`docs/evidence/chaos/`](docs/evidence/chaos/) |
| **Phase 8** | Backup & Timed DR Drills | [`backup/velero/`](backup/velero/), [`backup/pg_dump-cronjob/`](backup/pg_dump-cronjob/), [`backup/scripts/dr-drill.sh`](backup/scripts/dr-drill.sh) | Verified RTO [`68s`](docs/evidence/dr-drill/scorecard.md) & RPO [`4s`](docs/evidence/dr-drill/scorecard.md) across 3 drills | [`docs/evidence/dr-drill/scorecard.md`](docs/evidence/dr-drill/scorecard.md) & [`postmortem.md`](docs/evidence/dr-drill/postmortem.md) |
| **Phase 9** | Architecture Docs, ADRs & Audit | [`docs/DESIGN.md`](docs/DESIGN.md), [`docs/runbook.md`](docs/runbook.md), [`docs/cost.md`](docs/cost.md) | **`$3.77/mo`** actual Free-Tier bill (`~96%` cheaper than EKS) | [`docs/adr/`](docs/adr/) |

---

## 3. Architecture Decision Records (ADRs)

1. **[ADR-001: Single-Node K3s on ARM64 EC2 vs Managed AWS EKS](docs/adr/001-k3s-vs-eks.md)**
2. **[ADR-002: Bitnami Sealed Secrets vs HashiCorp Vault](docs/adr/002-sealed-secrets-vs-vault.md)**
3. **[ADR-003: ArgoCD vs FluxCD for GitOps Control Plane](docs/adr/003-argocd-vs-flux.md)**
4. **[ADR-004: Hybrid Kustomize + Helm Strategy](docs/adr/004-kustomize-vs-helm.md)**
5. **[ADR-005: AWS S3 (`ap-south-1`) vs Backblaze B2 for DR Backups](docs/adr/005-s3-vs-b2.md)**

---

## 4. Quickstart & Operations

```bash
# 1. Provision AWS EC2 ARM64 K3s cluster
make init
make apply

# 2. Bootstrap ArgoCD and App-of-Apps control plane
make bootstrap-gitops

# 3. Export & backup Sealed Secrets master key
make backup-keys

# 4. Run the 5 Chaos Engineering reliability experiments
make chaos

# 5. Execute timed Disaster Recovery (DR) drill
make dr-drill
```

See [`docs/runbook.md`](docs/runbook.md) for full incident response procedures.
