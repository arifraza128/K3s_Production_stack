# PRD.md — Phoenix Platform

> Source of truth for WHAT we build and WHY. Status: DRAFT v1 (needs owner approval on items marked ⚠ DECISION).

## 1. Problem, Value Proposition, Target Users

**Problem.** Most DevOps portfolio projects are tool lists ("k3s + ArgoCD + Prometheus"). A reviewer cannot tell whether the system actually works under failure, so the project carries no hiring signal.

**Value proposition.** Phoenix is a small but real GitOps platform whose reliability claims are **backed by evidence**: chaos experiments with measured recovery times, a full disaster-recovery drill with measured RTO/RPO, and written decision records (ADRs).

**Tagline.** *A self-healing GitOps platform that proves its reliability through chaos engineering and DR drills — not just claims it.*

### Target users (personas)

| Persona | Goal | Success looks like |
| :--- | :--- | :--- |
| **Reviewer** (hiring manager / senior engineer) | Judge depth in <2 minutes, then dig in | Finds numbers, evidence, ADRs from README without asking |
| **Owner** (the candidate, platform admin) | Build, operate, and defend every decision in interview | Can rebuild from zero and explain trade-offs |
| **Visitor** (random GitHub reader) | Learn the pattern | Can follow the README and reproduce |

---

## 2. Core User Journeys

1. **Reviewer skim:** opens repo -> reads tagline + measured results -> clicks Evidence -> opens one chaos report and the DR scorecard -> opens one ADR.
2. **Owner ships a change:** `git push` -> CI builds, scans, signs -> manifest bumped -> ArgoCD syncs -> change visible in cluster. No manual `kubectl apply`.
3. **Owner runs chaos:** runs `chaos.sh <experiment>` -> fault injected -> recovery time measured -> evidence file written -> dashboard shows the dip and recovery.
4. **Owner runs DR drill:** `make dr-drill` (or documented steps) -> destroy compute -> rebuild -> restore data -> verify -> RTO/RPO recorded in scorecard.
5. **Owner gets alerted:** SLO burn or service-down -> Discord alert -> runbook link -> fix.

---

## 3. User Stories (abridged)

- As a Reviewer, I want measured results at the top of the README so I can judge quickly.
- As an Owner, I want the whole platform created from Terraform + Git so that rebuilds are boring.
- As an Owner, I want unsigned or vulnerable images blocked so that supply-chain claims are provable.
- As an Owner, I want a chaos script that asserts recovery time so that "self-healing" is a measurement.
- As an Owner, I want backups restore-tested so that "we have backups" means something.

---

## 4. Features & Functional Requirements

| ID | Requirement | Priority |
| :--- | :--- | :--- |
| **FR-1** | Terraform provisions network, EC2 (ARM), Elastic IP, IAM role, S3 backup bucket, budget alert. | MVP |
| **FR-2** | cloud-init installs pinned k3s and hands off to ArgoCD bootstrap with zero manual steps. | MVP |
| **FR-3** | ArgoCD App-of-Apps (source: **GitHub repo**) deploys all workloads; `selfHeal` + `prune` enabled. | MVP |
| **FR-4** | Workloads: **Test API** (chaos target) and **Gitea + PostgreSQL** (stateful workload). | MVP |
| **FR-5** | CI (GitHub Actions): test -> build ARM64 -> Trivy (fail HIGH/CRITICAL) -> SBOM -> Cosign sign -> push GHCR -> bump manifest. | MVP |
| **FR-6** | Kyverno policy rejects unsigned images from our registry namespace. | MVP |
| **FR-7** | Secrets stored encrypted in Git (Sealed Secrets); controller key backed up off-cluster. | MVP |
| **FR-8** | NetworkPolicies: default-deny + explicit allows. | MVP |
| **FR-9** | Prometheus + Grafana with **3 SLOs** on Test API; Alertmanager -> Discord. | MVP |
| **FR-10** | Ingress-nginx + cert-manager, HTTPS via `sslip.io` on a stable Elastic IP. | MVP |
| **FR-11** | Chaos experiments (>=5) scripted with assertions; evidence written per run. | MVP |
| **FR-12** | Backups: Velero (K8s resources) + `pg_dump` CronJob -> S3. | MVP |
| **FR-13** | DR drill procedure + scorecard (>=3 drills, >=1 honest failure + postmortem). | MVP |
| **FR-14** | Docs: README, 5 ADRs, runbook, postmortem, `cost.md`. | MVP |
| **FR-15** | Loki centralized logs. | Stretch |
| **FR-16** | Chaos Mesh CRDs (instead of / in addition to kubectl scripts). | Stretch |
| **FR-17** | Automated weekly restore verification -> Pushgateway metric. | Stretch |
| **FR-18** | k6 load test with published p95. | Stretch |

---

## 5. Non-Functional Requirements

- **Reproducibility:** fresh AWS account + secrets -> working platform with documented commands only.
- **Honesty:** every number in docs links to an evidence file. No placeholder metrics ever published.
- **Security:** no secrets in Git (plaintext); least-privilege IAM; no public SSH or k3s API.
- **Cost:** hard budget alert at ⚠ DECISION (see §12). Compute can be destroyed between sessions.
- **Maintainability:** all versions pinned; every cluster change flows through Git.
- **Observability:** every workload has metrics or health probes.

---

## 6. Pages / Screens (this is an infra product; "screens" = surfaces)

| Surface | Audience | Purpose |
| :--- | :--- | :--- |
| GitHub README | Reviewer | Story, results, architecture, evidence links |
| `docs/` (ADRs, evidence, runbook, postmortem, cost) | Reviewer/Owner | Proof and decisions |
| ArgoCD UI | Owner | Sync/health of apps (screenshot in evidence) |
| Grafana | Owner/Reviewer | SLO + chaos dashboards |
| Gitea | Owner | Demo stateful app |
| Discord channel | Owner | Alerts |

---

## 7. Roles & Permissions

| Role | Access |
| :--- | :--- |
| Owner | AWS admin (via SSO/MFA), repo admin, Grafana/ArgoCD admin |
| CI bot | Push to GHCR, commit to `gitops` manifests path only, OIDC to AWS **not needed** for MVP |
| Instance role | Read/write ONLY the backup bucket prefix |
| Public | Read-only repo; Test API/Gitea public endpoints only where explicitly exposed |

---

## 8. Data Requirements

- Gitea metadata + repos in PostgreSQL (PVC) and Gitea data PVC.
- Backups in S3 (versioned, lifecycle >=30 days). Details in `DATABASE.md`.
- Evidence artifacts (markdown + JSON) in Git. Schema in `DATABASE.md`.

---

## 9. Integrations

GitHub (+Actions, GHCR), AWS (EC2, S3, IAM, Budgets), Discord webhook, Healthchecks.io, Let's Encrypt, `sslip.io`. Optional: Backblaze B2.

---

## 10. Loading / Empty / Error States (operational equivalents)

| State | Expected behavior |
| :--- | :--- |
| Dashboard has no data | Panels show "No data" + note linking to scrape-target troubleshooting in runbook |
| ArgoCD OutOfSync/Degraded | Alert after 5 min; runbook entry |
| Backup job failed | Alert; drill scorecard marks backup health red |
| Cert pending | Ingress serves clear 503/self-signed; runbook step for staging->prod issuer |
| Chaos script timeout | Exit non-zero, evidence file marked FAIL, never silently pass |

---

## 11. MVP Scope, Out of Scope, Success Criteria

**MVP: FR-1 -> FR-14.** **Out of scope:** multi-node HA, service mesh, Vault, EKS, multi-region, real users/SLAs, custom UI.

**Success criteria (all must be evidenced):**
1. `terraform apply` + one bootstrap command -> healthy cluster, no manual steps.
2. Deleting an ArgoCD-managed resource by hand -> restored automatically (screenshot + time).
3. Unsigned image deploy -> rejected by Kyverno (log in evidence).
4. >=5 chaos experiments with measured recovery in `docs/evidence/chaos/`.
5. >=3 DR drills in scorecard; RTO/RPO are **measured values**, >=1 failure documented.
6. 5 ADRs, runbook, postmortem, `cost.md` complete.

---

## 12. Assumptions & Decisions Needing Approval

| # | Item | Status |
| :--- | :--- | :--- |
| **A1** | **Instance size.** Original plan said `t4g.small` (2 GB). The planned stack (k3s + ArgoCD + Gitea + Postgres + Prometheus + Grafana + Kyverno + cert-manager + ingress) will not reliably fit in 2 GB. Recommend **`t4g.medium` (4 GB)** and treat Loki/Chaos Mesh as stretch. | ⚠ DECISION |
| **A2** | **"$0/month" claim.** AWS free-tier rules changed for newer accounts and t4g promos expire. Do NOT claim $0 until verified on your own billing. Publish actual cost in `cost.md`. | ⚠ DECISION |
| **A3** | **GitOps source = GitHub**, not in-cluster Gitea. (If Gitea hosts the repo ArgoCD reads, a cluster wipe kills the source of truth and DR becomes circular.) Gitea stays as a demo stateful workload. | ⚠ DECISION |
| **A4** | Region `ap-south-1`. | Assumed |
| **A5** | Public repo; no real personal data anywhere. | Assumed |
| **A6** | Run the instance only during build/drill sessions to control cost. | Assumed |

