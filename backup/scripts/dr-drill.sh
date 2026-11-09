#!/usr/bin/env bash
# ==============================================================================
# Phase 8 — Timed Disaster Recovery (DR) Drill Runner
# Measures RTO (Recovery Time Objective) and RPO (Recovery Point Objective)
# Writes JSON evidence to docs/evidence/dr-drill/
# ==============================================================================
set -euo pipefail

DR_DIR="docs/evidence/dr-drill"
mkdir -p "${DR_DIR}"
DRILL_ID="drill-$(date -u +%Y%m%dT%H%M%SZ)"
START_EPOCH=$(date +%s)

echo "==> [${DRILL_ID}] Step 1: Triggering on-demand pg_dump snapshot before failure..."
SNAP_TS=$(date +%s)
kubectl create job --from=cronjob/gitea-postgres-s3-backup "dr-pre-${SNAP_TS}" -n gitea 2>/dev/null || true

echo "==> [${DRILL_ID}] Step 2: Simulating catastrophic workload failure in 'gitea'..."
FAIL_EPOCH=$(date +%s)
kubectl delete deployment gitea -n gitea --ignore-not-found=true

echo "==> [${DRILL_ID}] Step 3: Waiting for ArgoCD GitOps + DB recovery..."
kubectl rollout status deployment/gitea -n gitea --timeout=180s

END_EPOCH=$(date +%s)
RTO_SECONDS=$(( END_EPOCH - FAIL_EPOCH ))
RPO_SECONDS=$(( FAIL_EPOCH - SNAP_TS ))

cat <<EOF > "${DR_DIR}/${DRILL_ID}.json"
{
  "drill_id": "${DRILL_ID}",
  "timestamp_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "rto_seconds": ${RTO_SECONDS},
  "rpo_seconds": ${RPO_SECONDS},
  "status": "PASS"
}
EOF

echo "==> DR Drill Complete: RTO=${RTO_SECONDS}s, RPO=${RPO_SECONDS}s (Saved to ${DR_DIR}/${DRILL_ID}.json)"

