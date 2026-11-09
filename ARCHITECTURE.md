# ARCHITECTURE.md — Phoenix Platform

> Source of truth for HOW it is built. Simplest reliable design first; stretch items clearly separated.

## 1. Principles

1. **Everything in Git;** the cluster is disposable, the repo + S3 backups are not.
2. **Persistent things** (state bucket, backup bucket, Elastic IP, budget) **are separate from destroyable things** (compute). This is what makes DR drills safe.
3. **Measure, then claim.**
4. **Fewest moving parts** that still demonstrate the three pillars: **Self-healing · Recoverable · Documented.**

---

## 2. Tech Stack & Reasoning

| Concern | Choice | Why (alternatives -> ADR) |
| :--- | :--- | :--- |
| IaC | Terraform | Industry standard; destroy/apply drills are the point |
| Compute | EC2 ARM (`t4g.medium`, ⚠ see PRD A1) | Cheap, ARM64 shows multi-arch builds |
| Kubernetes | k3s (pinned) | Low overhead single node; ADR-001 vs EKS |
| Bootstrap | cloud-init | No Ansible overhead for single node |
| GitOps | ArgoCD, App-of-Apps | ADR-003 vs Flux |
| Manifests | Kustomize | ADR-004 vs Helm (Helm only for third-party charts via Argo) |
| CI | GitHub Actions | Free for public repos |
| Supply chain | Trivy, Syft, Cosign (keyless/OIDC), Kyverno | Sign in CI, verify at admission |
| Secrets | Sealed Secrets | ADR-002 vs Vault |
| Observability | Prometheus, Grafana, Alertmanager->Discord | MVP; Loki = stretch |
| Chaos | `chaos.sh` (kubectl-based) MVP; Chaos Mesh stretch | Start light; add CRDs once memory allows |
| Backup | Velero + `pg_dump` CronJob -> S3 | ADR-005 (S3 vs B2) |
| Ingress/TLS | ingress-nginx, cert-manager, `sslip.io` on Elastic IP | Free domain, stable across rebuilds |
| External uptime | Healthchecks.io | Detects "whole server down" which in-cluster alerting can't |

---

## 3. Terraform Layout — Two Stacks (critical)

```text
terraform/
├── bootstrap/          # NEVER destroyed by drills
│   ├── S3 bucket: tf-state (versioned) + locking
│   ├── S3 bucket: phoenix-backups (versioned, lifecycle, encryption)
│   ├── Elastic IP (stable sslip.io hostname)
│   ├── AWS Budget + alert
│   └── IAM policy: backup-bucket read/write
└── platform/           # destroyed + recreated in DR drills
    ├── VPC/subnet/security group (443/80 only; no 22, no 6443 public)
    ├── EC2 + instance profile (SSM Session Manager for access)
    ├── EIP association
    └── cloud-init (k3s + argocd bootstrap)
```

---

## 4. Runtime Architecture

```text
Dev ──push──▶ GitHub ──Actions──▶ GHCR (signed images) ──▶ manifest bump commit
                ▲                                                  │
                └──────────────── ArgoCD (in cluster) polls ◀──────┘

EC2 (k3s)
├─ argocd ns      : ArgoCD, root-app
├─ apps ns        : test-api, gitea, postgres
├─ security       : kyverno, sealed-secrets, netpols
├─ monitoring     : prometheus, grafana, alertmanager
├─ ingress        : ingress-nginx, cert-manager
└─ backup         : velero, pg-dump cronjob
     │
     ├──▶ S3 phoenix-backups
     ├──▶ Discord (alerts)
     └──▶ Healthchecks.io (heartbeat)
```

---

## 5. Repo & Folder Structure

```text
phoenix-platform/
├── README.md  AGENTS.md  PRD.md  DESIGN.md  ARCHITECTURE.md  DATABASE.md  API.md  IMPLEMENTATION_PLAN.md
├── terraform/{bootstrap,platform}/
├── cloud-init/
├── gitops/
│   ├── root-app.yaml
│   └── argocd-apps/*.yaml
├── apps/{test-api,gitea}/              # kustomize base + overlays/prod
├── .github/workflows/
├── security/{kyverno,sealed-secrets,network-policies}/
├── observability/{prometheus,grafana,alertmanager}/
├── chaos/{scripts,experiments}/
├── backup/{velero,pg-dump}/
├── scripts/                            # drill + helper scripts
├── Makefile
└── docs/{adr,evidence/{chaos,dr-drill},runbook.md,postmortem.md,cost.md,screenshots/}
```

---

## 6. Data Flow (change -> running)

1. Push to `main` in `apps/test-api/**`.
2. CI: unit tests -> buildx ARM64 -> Trivy (fail on HIGH/CRITICAL) -> Syft SBOM -> Cosign sign -> push GHCR.
3. CI commits new image digest to `apps/test-api/overlays/prod/kustomization.yaml`.
4. ArgoCD detects, syncs. Kyverno verifies signature at admission. Probes gate rollout.

---

## 7. Authentication / Authorization

- **AWS:** SSO + MFA for human; instance role least-privilege (bucket prefix only).
- **Cluster access:** via SSM port-forward / SSM session; kubeconfig never public.
- **ArgoCD/Grafana** admin passwords from sealed secrets; UIs not publicly exposed (port-forward) except where deliberately shown.
- **CI -> GHCR** via `GITHUB_TOKEN`; Cosign keyless via GitHub OIDC (no long-lived signing key).

---

## 8. Secrets Strategy

- **Sealed Secrets in Git.** The controller's private key is **backed up to S3 (encrypted) outside the cluster** — otherwise after `terraform destroy` no sealed secret can be decrypted and DR fails. This is a tested step in the DR drill.
- Never commit: AWS keys, Discord webhook, DB passwords, kubeconfig.

---

## 9. Environment Configuration

`.env.example` documents (never real values): `AWS_REGION`, `TF_VAR_*`, `DISCORD_WEBHOOK_URL` (sealed), `HEALTHCHECKS_URL` (sealed), `GHCR_ORG`. Real values: GitHub Actions secrets / sealed secrets / local shell only.

---

## 10. Error Handling

- **Terraform:** remote state + locking; plan reviewed before apply.
- **Scripts:** `set -euo pipefail`; timeouts; non-zero exit on failure; evidence file records FAIL honestly.
- **Kubernetes:** readiness/liveness probes, resource requests/limits on every workload, PodDisruptionBudgets where meaningful.

---

## 11. Security Boundaries

Public internet -> 80/443 only -> ingress-nginx -> services. NetworkPolicies default-deny per namespace; explicit allows (ingress->app, app->db, prometheus->targets, velero->S3 egress). Test API `/crash` and `/fail` are **not routable via public ingress**.

---

## 12. Resource Budget (guidance, verify with `kubectl top`)

| Component | Rough RAM |
| :--- | :--- |
| k3s control plane | 500–700 MB |
| ArgoCD | 300–500 MB |
| Prometheus + Grafana + Alertmanager | 600–900 MB |
| Gitea + Postgres | 300–500 MB |
| Kyverno + cert-manager + ingress + sealed-secrets | 400–600 MB |
| **Total** | **~2.1–3.2 GB** -> needs 4 GB node; Loki/Chaos Mesh only if headroom |

---

## 13. Testing & Deployment

- Unit tests for Test API; `terraform validate`/`fmt`, `kubeconform` on manifests, `kyverno test` for policies in CI.
- Deployment = Git merge. DR drill = full redeploy test.

---

## 14. MVP vs Future

**Future:** Loki, Chaos Mesh CRDs, Pushgateway restore automation, k6 load tests, multi-node, B2 secondary backup, Argo Rollouts.

