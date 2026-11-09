# AGENTS.md — Rules for Coding Agents (Phoenix Platform)

> Read `PRD.md`, `ARCHITECTURE.md`, `DATABASE.md`, `API.md`, `DESIGN.md` before changing anything. These are the source of truth. If they conflict with a request, stop and ask.

## 1. Golden Rules

1. **Inspect before editing.** Read existing files, reuse patterns.
2. **Smallest correct change.** No unrelated refactors, renames, or "cleanups".
3. **Never fabricate evidence.** No invented RTO/recovery/uptime numbers — ever. If not measured, write `"not yet measured"`.
4. **Never commit secrets** (AWS keys, webhooks, passwords, kubeconfig, sealed-secrets private key). Use sealed secrets / Actions secrets / env.
5. **Git is the only way to change the cluster** after Phase 3. No manual `kubectl apply`/`edit` except inside documented chaos/drill scripts or debugging (and revert it).
6. **Ask when blocked** by real ambiguity; don't silently change requirements.

---

## 2. Infrastructure (Terraform)

- Two stacks only: `bootstrap` (persistent) and `platform` (destroyable). Never put the backup bucket, state bucket, or Elastic IP in `platform`.
- Remote state + locking. Run `fmt`, `validate`, `plan` and show the plan summary before `apply`.
- Pin provider and module versions. Tag all resources `project=phoenix`.
- Never run `destroy` on `bootstrap`. `platform` destroy only in DR drills or when explicitly asked.
- Least-privilege IAM; no wildcard `*:*`.

---

## 3. Kubernetes / GitOps

- Pin image digests/tags and chart versions; no `latest`.
- Every workload: resource requests+limits, readiness+liveness probes, non-root, read-only rootfs where possible.
- Kustomize for own apps; Helm only for third-party charts via Argo `Application`.
- New app = new file in `gitops/argocd-apps/`. Namespace-scoped RBAC.
- `NetworkPolicy` required for every new namespace.

---

## 4. CI/CD

- Pipeline order fixed: test -> build -> Trivy -> SBOM -> sign -> push -> manifest bump.
- Never disable or `continue-on-error` the security scan to make CI green. Fix or document an exception with expiry in an ADR.
- Pin third-party Actions to commit SHAs.

---

## 5. Scripts

- Bash: `set -euo pipefail`, quoted variables, timeouts on every wait, non-zero exit on failure.
- Chaos/DR scripts write evidence files in the formats from `DATABASE.md`/`DESIGN.md`, including FAIL cases.

---

## 6. Application Code (Test API)

- Follow `API.md` exactly. Chaos endpoints behind `CHAOS_ENDPOINTS_ENABLED`.
- Typed, small functions, table-driven tests, no new dependencies without justification.
- Structured errors per `API.md`; never log secrets.

---

## 7. Dependencies

Prefer standard library / existing tools. Every new tool or chart needs: reason, memory cost, and an ADR if it replaces a decision.

---

## 8. Documentation

- Update docs in the same change as behavior.
- Decisions with trade-offs -> ADR. Incidents -> postmortem. Operational steps -> runbook.
- README numbers must link to evidence files.

---

## 9. Testing & Verification

- "Done" means verified: show command + output (e.g., `kubectl get`, `argocd app list`, test output).
- Don't weaken tests, policies, or alerts to pass. Investigate root cause.

---

## 10. Git Discipline

- Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `infra:`).
- One logical change per commit/PR. No force-push to `main`.
- Final report per task: files changed, commands run, results, open risks, items needing approval.
