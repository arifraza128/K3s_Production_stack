# IMPLEMENTATION_PLAN.md — Phoenix Platform

> Ordered phases. Each phase small enough to verify independently. "Prompt #" refers to the numbered prompts in Important Vibecoding Prompts.pdf. Rule: do not start phase N+1 until phase N completion criteria are evidenced (command output or screenshot saved).

## Phase 0 — Repo, Docs, Guardrails (before any cloud spend)
- **Goal:** Safe foundation.
- **Tasks:** create repo `phoenix-platform`; add the 8 docs; `.gitignore` (`tfstate`, `*.pem`, `kubeconfig`, `.env`); `.env.example`; pre-commit with `gitleaks`; AWS account MFA + billing budget alert (Day 1).
- **Prompts:** #6 (`AGENTS.md` already done), #8 (project setup: `Makefile`, lint, pre-commit).
- **Done when:** `gitleaks` passes; budget alert email received in test; docs committed.

## Phase 1 — Terraform bootstrap + platform + k3s
- **Goal:** `terraform apply` -> `kubectl get nodes` Ready.
- **Tasks:** `bootstrap/` (state bucket, backup bucket, EIP, budget, IAM policy); `platform/` (SG 80/443 only, EC2 `t4g.small`/`t4g.medium`, instance profile + SSM, EIP assoc); `cloud-init` installs pinned k3s.
- **Files:** `terraform/**`, `cloud-init/`, `Makefile`.
- **Prompt:** #9 with task "Phase 1 — see IMPLEMENTATION_PLAN.md"; #18 later.
- **Tests:** `terraform validate`, `plan` clean, second `apply` = no changes.
- **Done when:** node Ready via SSM; destroy+apply of `platform` leaves `bootstrap` + same public IP intact. Save output to `docs/evidence/`.

## Phase 2 — Stateful workload (manual, learning only)
- **Goal:** Gitea + Postgres running with PVCs; understand manifests.
- **Tasks:** write Kustomize/Helm base for Gitea/Postgres with resources/probes; apply manually once (last manual apply).
- **Done when:** Gitea login works via port-forward/NodePort; PVCs bound.

## Phase 3 — GitOps (App-of-Apps)
- **Goal:** Git is the control plane.
- **Tasks:** install ArgoCD via bootstrap; `root-app.yaml` pointing to GitHub `gitops/argocd-apps/`; apps: `gitea`, `test-api`, `monitoring`, `security`, `ingress`; `selfHeal` + `prune`.
- **Prompt:** #9.
- **Tests:** delete Gitea Deployment by hand -> restored; manual drift edit -> reverted.
- **Done when:** screenshot + timed result in `docs/evidence/gitops-selfheal.md`.

## Phase 4 — Test API + CI/CD + Supply-chain security
- **Goal:** Signed images only.
- **Tasks:** Test API per `API.md`; GitHub Actions pipeline; Trivy fail on `HIGH`/`CRITICAL`; Syft SBOM; Cosign keyless; Kyverno `verifyImages` policy; Sealed Secrets (+ key backup script); default-deny `NetworkPolicies`.
- **Prompts:** #9, #13 (GHCR/Cosign integration), #16 (security audit later).
- **Tests:** unsigned image deploy rejected (save Kyverno denial log); vulnerable base image fails CI; sealed secret decrypts.
- **Done when:** evidence files for both negative tests exist.

## Phase 5 — Observability
- **Goal:** SLOs + alerts work end to end.
- **Tasks:** Prometheus, Grafana dashboards per `DESIGN.md`, 3 SLOs, Alertmanager -> Discord, Healthchecks heartbeat.
- **Prompt:** #19.
- **Tests:** force 5xx via `/fail` -> alert reaches Discord; stop heartbeat -> external alert.
- **Done when:** both alerts demonstrated + screenshots.

## Phase 6 — Ingress + TLS
- **Goal:** HTTPS on `<eip>.sslip.io`.
- **Tasks:** `ingress-nginx`, `cert-manager` (staging issuer first, then prod), rate limits, only intended paths public.
- **Done when:** valid cert in browser; `/crash` not reachable publicly (test with `curl`, save output).

## Phase 7 — Reliability Proof (chaos)
- **Goal:** >=5 measured experiments.
- **Tasks:** `chaos/scripts/chaos.sh` with experiments: `pod-kill`, `OOM-kill`, `network partition` (`netpol`), `CPU stress`, `disk fill`/`PVC pressure`. Each: hypothesis -> baseline -> inject -> measure recovery -> write evidence (FAIL honestly). Chaos Mesh only if memory headroom (stretch).
- **Prompts:** #9, #14.
- **Done when:** 5 evidence files with real `recovery_seconds` + Grafana annotation screenshots.

## Phase 8 — Backup + DR Drill
- **Goal:** Measured RTO/RPO.
- **Tasks:** Velero + `pg_dump` CronJob -> S3; `sealed-secrets` key backup; `scripts/dr-drill.sh` (timed steps -> JSON evidence); run >=3 drills incl. one planned failure (e.g., missing key or corrupted dump) -> postmortem; scorecard generator.
- **Prompts:** #10, #19 (backup verification), #15 (debugging failures).
- **Done when:** scorecard with >=3 real rows; postmortem committed; fixes merged.

## Phase 9 — Docs, Audit, Portfolio
- **Tasks:** 5 ADRs (`001 k3s vs EKS`, `002 Sealed Secrets vs Vault`, `003 ArgoCD vs Flux`, `004 Kustomize vs Helm`, `005 S3 vs B2`); `runbook.md`; `cost.md` with actual bill; `README.md` per `DESIGN.md`; 2–3 min Loom walkthrough; blog post.
- **Prompts:** #17 (code review), #16 (security audit), #20 (final audit -> verdict).
- **Done when:** audit verdict `READY` / `READY WITH WARNINGS`; every README number links to evidence.

## Stretch (only after Phase 9)
Loki, Chaos Mesh CRDs, Pushgateway restore automation (FR-17), k6 load test (FR-18).

