# Phoenix Platform

> *A self-healing GitOps platform that proves its reliability through chaos engineering and DR drills — not just claims it.*

[![CI Supply-Chain](https://github.com/arifraza128/K3s_Production_stack/actions/workflows/ci-supply-chain.yaml/badge.svg)](https://github.com/arifraza128/K3s_Production_stack/actions/workflows/ci-supply-chain.yaml)
[![Trivy Security Gate](https://img.shields.io/badge/Trivy-HIGH%2FCRITICAL%20Gate-blue)](.github/workflows/ci-supply-chain.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 1. Measured Results Table

> Per [`AGENTS.md`](AGENTS.md) Golden Rule #3 & [`DESIGN.md`](DESIGN.md) §2: Only values backed by committed live-run evidence are shown; pending runs are explicitly marked `"not yet measured"`.

| Pillar / Test | Target | Measured Value | Status | Evidence Link |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1: K3s ARM64 Node Bootstrap** | `kubectl get nodes` Ready | Verified on `13.207.161.55` | PASS | [`screenshots/`](screenshots/) |
| **Phase 3: ArgoCD Self-Heal (`gitea` delete)** | `< 60 s` | `not yet measured` | Pending live run | [`docs/evidence/gitops-selfheal.md`](docs/evidence/gitops-selfheal.md) |
| **Phase 4: Unsigned Image Rejection** | Denied at admission | `not yet measured` | Policy ready | [`security/kyverno-policies/verify-images.yaml`](security/kyverno-policies/verify-images.yaml) |
| **Phase 5: Availability SLO (`/work`)** | `>= 99.5%` (30d) | `not yet measured` | Rules ready | [`observability/prometheus/slo-rules.yaml`](observability/prometheus/slo-rules.yaml) |
| **Phase 5: Latency P95 SLO (`/work`)** | `< 300 ms` | `not yet measured` | Rules ready | [`observability/prometheus/slo-rules.yaml`](observability/prometheus/slo-rules.yaml) |
| **Phase 7: Chaos #1 — Pod Kill** | `< 60 s` recovery | `not yet measured` | Script ready | [`docs/evidence/chaos/01-pod-kill.md`](docs/evidence/chaos/01-pod-kill.md) |
| **Phase 7: Chaos #2 — OOM-Kill** | Container isolated | `not yet measured` | Script ready | [`docs/evidence/chaos/02-oom-kill.md`](docs/evidence/chaos/02-oom-kill.md) |
| **Phase 7: Chaos #3 — Network Partition** | `< 60 s` recovery | `not yet measured` | Script ready | [`docs/evidence/chaos/03-network-partition.md`](docs/evidence/chaos/03-network-partition.md) |
| **Phase 7: Chaos #4 — CPU Stress** | P95 `< 300 ms` | `not yet measured` | Script ready | [`docs/evidence/chaos/04-cpu-stress.md`](docs/evidence/chaos/04-cpu-stress.md) |
| **Phase 7: Chaos #5 — Disk / PVC Pressure** | Node healthy | `not yet measured` | Script ready | [`docs/evidence/chaos/05-disk-fill.md`](docs/evidence/chaos/05-disk-fill.md) |
| **Phase 8: Full DR Drill (RTO / RPO)** | Measured in scorecard | `not yet measured` | Script ready | [`docs/evidence/dr-drill/scorecard.md`](docs/evidence/dr-drill/scorecard.md) |

---

## 2. Architecture Diagram

```mermaid
flowchart TD
    Dev["Developer git push"] -->|triggers| CI["GitHub Actions CI<br/>Trivy + Syft SBOM + Cosign"]
    CI -->|pushes signed image| GHCR["GHCR Registry"]
    CI -->|bumps digest| Repo["GitHub Repo (Source of Truth)"]
    Repo <--|polls & reconciles| ArgoCD["ArgoCD (App-of-Apps)"]

    subgraph Persistent ["Persistent Stack (terraform/bootstrap)"]
        EIP["Elastic IP (13.207.161.55.sslip.io)"]
        S3["AWS S3 phoenix-backups (Encrypted + Versioned)"]
    end

    subgraph Destroyable ["Destroyable Compute Stack (terraform/platform — EC2 ARM64 k3s)"]
        EIP -->|routes 80/443| Ingress["ingress-nginx + cert-manager"]
        Ingress -->|/work, /version, /healthz| Apps["Workloads: Test API + Gitea/Postgres"]
        ArgoCD -->|syncs| Apps
        Sec["Security: Kyverno + SealedSecrets + NetPol"] -->|verifies Cosign sig| GHCR
        Obs["Observability: Prometheus + Grafana + Alertmanager"] -->|scrapes| Apps
        Backup["Backup: Velero + pg_dump CronJob"] -->|uploads| S3
    end

    Obs -->|alerts| Discord["Discord + Healthchecks.io"]
```

---

## 3. Three Pillars & Proof

1. **Self-Healing (GitOps + Chaos Engineering):**
   - Declarative ArgoCD App-of-Apps ([`gitops/root-app.yaml`](gitops/root-app.yaml)) with `selfHeal: true` and `prune: true`.
   - Automated 5-experiment chaos suite ([`chaos/scripts/chaos.sh`](chaos/scripts/chaos.sh)) writing frontmatter-validated reports to [`docs/evidence/chaos/`](docs/evidence/chaos/).
2. **Recoverable (Two-Stack Terraform + S3 DR Drills):**
   - Persistent state/backups/EIP ([`terraform/bootstrap/`](terraform/bootstrap/)) decoupled from disposable compute ([`terraform/platform/`](terraform/platform/)).
   - Timed DR drill runner ([`backup/scripts/dr-drill.sh`](backup/scripts/dr-drill.sh)) recording JSON evidence and generating [`docs/evidence/dr-drill/scorecard.md`](docs/evidence/dr-drill/scorecard.md).
3. **Documented (Specification Pack + 5 ADRs + Runbook):**
   - Full specification pack in root: [`PRD.md`](PRD.md), [`ARCHITECTURE.md`](ARCHITECTURE.md), [`DATABASE.md`](DATABASE.md), [`API.md`](API.md), [`DESIGN.md`](DESIGN.md), [`AGENTS.md`](AGENTS.md), [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).

---

## 4. Quick Start

```bash
# 1. Provision persistent bootstrap stack (S3 buckets, EIP, Budget, IAM)
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply

# 2. Provision destroyable platform stack (EC2 ARM64 + K3s cloud-init)
make init
make apply

# 3. Bootstrap ArgoCD App-of-Apps control plane
make bootstrap-gitops

# 4. Run Test API unit tests
python -m unittest discover -s apps/test-api -v

# 5. Execute chaos suite & DR drill (on live cluster)
make chaos
make dr-drill
```

---

## 5. Evidence Index · ADR Index · Runbook · Cost

- **Specification Pack:** [`PRD.md`](PRD.md) · [`ARCHITECTURE.md`](ARCHITECTURE.md) · [`DATABASE.md`](DATABASE.md) · [`API.md`](API.md) · [`DESIGN.md`](DESIGN.md) · [`AGENTS.md`](AGENTS.md) · [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md)
- **Architecture Decision Records (ADRs):**
  - [`001-k3s-vs-eks.md`](docs/adr/001-k3s-vs-eks.md)
  - [`002-sealed-secrets-vs-vault.md`](docs/adr/002-sealed-secrets-vs-vault.md)
  - [`003-argocd-vs-flux.md`](docs/adr/003-argocd-vs-flux.md)
  - [`004-kustomize-vs-helm.md`](docs/adr/004-kustomize-vs-helm.md)
  - [`005-s3-vs-b2.md`](docs/adr/005-s3-vs-b2.md)
- **Operations & Cost:** [`docs/runbook.md`](docs/runbook.md) · [`docs/cost.md`](docs/cost.md) · [`docs/evidence/dr-drill/postmortem.md`](docs/evidence/dr-drill/postmortem.md)
- **Evidence Directory:** [`screenshots/`](screenshots/) · [`docs/evidence/gitops-selfheal.md`](docs/evidence/gitops-selfheal.md) · [`docs/evidence/chaos/`](docs/evidence/chaos/) · [`docs/evidence/dr-drill/scorecard.md`](docs/evidence/dr-drill/scorecard.md)

---

## 6. Limitations & What I'd Do Next

- **Single-Node Control Plane:** K3s runs on a single ARM64 EC2 instance to stay within budget (`<$20/mo`). Next step: 3-node embedded etcd HA across availability zones.
- **Stretch Items (Post-Phase 9):** Loki centralized logging (`FR-15`), Chaos Mesh CRDs (`FR-16`), weekly automated throwaway Postgres restore verification to Pushgateway (`FR-17`), and `k6` load testing (`FR-18`).
