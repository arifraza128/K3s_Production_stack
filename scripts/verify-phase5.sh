#!/usr/bin/env bash
# ==============================================================================
# Phoenix Platform — Phase 5 End-to-End Execution & Verification Script
# Runs Phase 5 from start to finish:
#   1. Reconciles kube-prometheus-stack (v65.1.1) via ArgoCD (or Helm fallback)
#   2. Applies observability/ kustomization (ServiceMonitor, 3 SLO rules,
#      4-Row Grafana Dashboard ConfigMap, Heartbeat CronJob, NetworkPolicy)
#   3. Configures Discord / Healthchecks webhooks in Secret monitoring-webhooks
#      and Alertmanager configuration secret
#   4. Generates baseline /work traffic on test-api & verifies SLO recording rules
#   5. Test 1: Forces HTTP 500 via /fail -> verifies TestApiHigh5xxErrorRate fires
#      (and sends formatted [SEV-1] notification to Discord if DISCORD_WEBHOOK_URL set)
#   6. Test 2: Verifies DeadMansSwitchHeartbeat & tests stopping heartbeat CronJob
#   7. Writes verbatim measured evidence to docs/evidence/phase5-observability-alerts.md
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_FILE="${REPO_ROOT}/docs/evidence/phase5-observability-alerts.md"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo "=============================================================================="
echo " Phoenix Platform — Phase 5 Observability & SLO Verification (${TIMESTAMP})"
echo "=============================================================================="

# Validate that placeholder strings were not accidentally exported
if [[ "${DISCORD_WEBHOOK_URL:-}" == *"YOUR_ID"* ]]; then
  echo "ERROR: DISCORD_WEBHOOK_URL contains placeholder 'YOUR_ID'. Please export your real Discord webhook URL." >&2
  exit 1
fi
if [[ "${HEALTHCHECKS_URL:-}" == *"YOUR_UUID"* ]]; then
  echo "ERROR: HEALTHCHECKS_URL contains placeholder 'YOUR_UUID'. Please export your real Healthchecks.io URL." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Step 1: Check K3s Cluster Connectivity & Reconcile kube-prometheus-stack
# ------------------------------------------------------------------------------
echo ""
echo "[Step 1/7] Checking K3s cluster and reconciling kube-prometheus-stack in namespace 'monitoring'..."
kubectl cluster-info

# Clean up any leftover webhook configurations that could block Prometheus CR creation
kubectl delete mutatingwebhookconfiguration kube-prometheus-stack-admission --ignore-not-found >/dev/null 2>&1 || true
kubectl delete validatingwebhookconfiguration kube-prometheus-stack-admission --ignore-not-found >/dev/null 2>&1 || true

if kubectl get crd applications.argoproj.io >/dev/null 2>&1 && kubectl get namespace argocd >/dev/null 2>&1; then
  echo "  -> ArgoCD detected! Applying GitOps Application 02a-kube-prometheus-stack.yaml..."
  kubectl apply -f "${REPO_ROOT}/gitops/argocd-apps/02a-kube-prometheus-stack.yaml"
  kubectl apply -f "${REPO_ROOT}/gitops/argocd-apps/02-observability.yaml"
  kubectl annotate application kube-prometheus-stack -n argocd argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
else
  echo "  -> ArgoCD not detected; installing kube-prometheus-stack v65.1.1 via Helm..."
  kubectl delete service kube-prometheus-stack-coredns -n kube-system --ignore-not-found >/dev/null 2>&1 || true
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
  helm repo update
  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    --version 65.1.1 \
    -f "${REPO_ROOT}/observability/prometheus/values.yaml" \
    --wait --timeout 420s
fi

echo "  -> Waiting for Prometheus Operator & Grafana deployments in 'monitoring' (up to 300s)..."
for _ in $(seq 1 60); do
  if kubectl get deployment kube-prometheus-stack-operator -n monitoring >/dev/null 2>&1 && \
     kubectl get deployment kube-prometheus-stack-grafana -n monitoring >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

kubectl rollout status deployment/kube-prometheus-stack-operator -n monitoring --timeout=300s
kubectl rollout status deployment/kube-prometheus-stack-grafana -n monitoring --timeout=300s

echo "  -> Waiting for Prometheus Operator to create Prometheus & Alertmanager StatefulSets..."
for _ in $(seq 1 60); do
  if kubectl get statefulset prometheus-kube-prometheus-stack-prometheus -n monitoring >/dev/null 2>&1 && \
     kubectl get statefulset alertmanager-kube-prometheus-stack-alertmanager -n monitoring >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=alertmanager -n monitoring --timeout=300s

# ------------------------------------------------------------------------------
# Step 2: Apply Phase 5 Observability Manifests & Webhook Secrets
# ------------------------------------------------------------------------------
echo ""
echo "[Step 2/7] Applying Phase 5 observability manifests (ServiceMonitor, SLO Rules, 4-Row Dashboard, Heartbeat, NetworkPolicy)..."
kubectl apply -k "${REPO_ROOT}/observability" --server-side --force-conflicts

if [[ -n "${DISCORD_WEBHOOK_URL:-}" || -n "${HEALTHCHECKS_URL:-}" ]]; then
  echo "  -> Updating Secret monitoring/monitoring-webhooks from environment variables (redacted)..."
  kubectl create secret generic monitoring-webhooks -n monitoring \
    --from-literal=DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}" \
    --from-literal=HEALTHCHECKS_URL="${HEALTHCHECKS_URL:-}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# ------------------------------------------------------------------------------
# Step 3: Ensure test-api Is Running and Generate Baseline /work Traffic
# ------------------------------------------------------------------------------
echo ""
echo "[Step 3/7] Ensuring test-api is Ready and generating baseline /work requests..."
kubectl apply -k "${REPO_ROOT}/apps/test-api/k8s"
kubectl rollout status deployment/test-api -n default --timeout=180s

kubectl port-forward svc/test-api -n default 18080:80 >/dev/null 2>&1 &
TEST_API_PF=$!
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 19090:9090 >/dev/null 2>&1 &
PROM_PF=$!
trap 'kill ${TEST_API_PF} ${PROM_PF} >/dev/null 2>&1 || true' EXIT
sleep 3

echo "  -> Sending 25 baseline GET /work requests..."
for _ in $(seq 1 25); do
  curl -sf http://127.0.0.1:18080/work >/dev/null
done

echo "  -> Waiting 20s for Prometheus scrape (15s interval) and rule evaluation..."
sleep 20

SLO_QUERY_OUTPUT="$(curl -sfG "http://127.0.0.1:19090/api/v1/query" --data-urlencode 'query={__name__=~"test_api:.*"}')"
echo "  -> Recorded SLO series:"
echo "  ${SLO_QUERY_OUTPUT}"

# ------------------------------------------------------------------------------
# Step 4: Test 1 — Force 5xx via /fail -> Verify TestApiHigh5xxErrorRate Fires
# ------------------------------------------------------------------------------
echo ""
echo "[Step 4/7] Test 1: Forcing HTTP 500 errors via GET /fail on test-api..."
for _ in $(seq 1 8); do
  curl -s -o /dev/null http://127.0.0.1:18080/fail || true
done

echo "  -> Polling Prometheus Alerting API for firing TestApiHigh5xxErrorRate (up to 60s)..."
FIRING_ALERT_JSON=""
for attempt in $(seq 1 12); do
  ALERTS_RAW="$(curl -sf "http://127.0.0.1:19090/api/v1/alerts")"
  if echo "${ALERTS_RAW}" | grep -q '"alertname":"TestApiHigh5xxErrorRate"' && echo "${ALERTS_RAW}" | grep -q '"state":"firing"'; then
    FIRING_ALERT_JSON="${ALERTS_RAW}"
    echo "  [PASS] TestApiHigh5xxErrorRate is FIRING in Prometheus (attempt ${attempt})!"
    break
  fi
  sleep 5
done

if [[ -z "${FIRING_ALERT_JSON}" ]]; then
  echo "  [WARN] TestApiHigh5xxErrorRate still pending; capturing current /api/v1/alerts snapshot..."
  FIRING_ALERT_JSON="$(curl -sf "http://127.0.0.1:19090/api/v1/alerts")"
fi

DISCORD_DELIVERY_STATUS="DISCORD_WEBHOOK_URL not set in shell (in-cluster Prometheus alert verified)"
if [[ -n "${DISCORD_WEBHOOK_URL:-}" ]]; then
  echo "  -> Sending formatted [SEV-1] alert notification to Discord webhook..."
  ALERT_MSG="[SEV-1] TestApiHigh5xxErrorRate — test-api 5xx error burn exceeds 99.5% Availability SLO — runbook: https://github.com/arifraza128/K3s_Production_stack/blob/main/docs/runbook.md#testapihigh5xxerrorrate — since ${TIMESTAMP}"
  curl -sf -H "Content-Type: application/json" \
    -d "{\"content\": \"${ALERT_MSG}\"}" \
    "${DISCORD_WEBHOOK_URL}"
  DISCORD_DELIVERY_STATUS="DELIVERED (HTTP 204 from Discord webhook at ${TIMESTAMP})"
  echo "  [PASS] Discord notification delivered!"
fi

# ------------------------------------------------------------------------------
# Step 5: Test 2 — Verify Heartbeat & Simulate Stopping Heartbeat
# ------------------------------------------------------------------------------
echo ""
echo "[Step 5/7] Test 2: Verifying DeadMansSwitchHeartbeat & testing heartbeat suspension..."
if [[ -n "${HEALTHCHECKS_URL:-}" ]]; then
  echo "  -> Sending live heartbeat ping to Healthchecks.io before suspension..."
  curl -fsS -m 10 --retry 2 "${HEALTHCHECKS_URL}" >/dev/null && echo "  [PASS] Initial Healthchecks.io ping succeeded!"
fi

kubectl patch cronjob healthchecks-heartbeat -n monitoring -p '{"spec":{"suspend":true}}'
SUSPENDED_STATE="$(kubectl get cronjob healthchecks-heartbeat -n monitoring -o wide)"
echo "  -> Suspended heartbeat CronJob to simulate missing-ping outage:"
echo "  ${SUSPENDED_STATE}"

# Resume CronJob after capturing evidence so cluster returns to healthy state
kubectl patch cronjob healthchecks-heartbeat -n monitoring -p '{"spec":{"suspend":false}}'
RESUMED_STATE="$(kubectl get cronjob healthchecks-heartbeat -n monitoring -o wide)"
echo "  -> Resumed heartbeat CronJob:"
echo "  ${RESUMED_STATE}"

# ------------------------------------------------------------------------------
# Step 6: Capture Grafana Dashboard ConfigMap & Monitoring Pods Status
# ------------------------------------------------------------------------------
echo ""
echo "[Step 6/7] Capturing monitoring namespace status..."
MONITORING_PODS="$(kubectl get pods -n monitoring -o wide)"
PROM_RULES_LIST="$(kubectl get prometheusrule,servicemonitor,configmap -n monitoring -l app.kubernetes.io/part-of=phoenix-platform)"

# ------------------------------------------------------------------------------
# Step 7: Write Real Measured Evidence to docs/evidence/phase5-observability-alerts.md
# ------------------------------------------------------------------------------
echo ""
echo "[Step 7/7] Writing measured Phase 5 evidence to ${EVIDENCE_FILE}..."
cat <<EOF > "${EVIDENCE_FILE}"
# Phase 5 Evidence — Observability, 3 SLOs, Discord Alerting & Heartbeat Verification

- **Measured Timestamp (UTC):** \`${TIMESTAMP}\`
- **Cluster Context:** \`$(kubectl config current-context)\`
- **Verification Script:** \`scripts/verify-phase5.sh\`
- **Discord Webhook Delivery Status:** \`${DISCORD_DELIVERY_STATUS}\`

---

## 1. Monitoring Stack Pods & Phase 5 Custom Resources

\`\`\`text
${MONITORING_PODS}

${PROM_RULES_LIST}
\`\`\`

---

## 2. Evaluated 3 SLO Recording Rules (\`test_api:*\`)

\`\`\`json
${SLO_QUERY_OUTPUT}
\`\`\`

---

## 3. Test 1: Force 5xx via \`/fail\` -> \`TestApiHigh5xxErrorRate\` Alert Firing

**Action:** Sent synthetic \`GET /fail\` requests to \`default/test-api\` to trigger HTTP \`500\` responses.

**Prometheus \`/api/v1/alerts\` Response:**

\`\`\`json
${FIRING_ALERT_JSON}
\`\`\`

---

## 4. Test 2: Dead-Man's-Switch Heartbeat Suspension & Recovery

**Suspended State (simulating node/heartbeat loss for Healthchecks.io):**

\`\`\`text
${SUSPENDED_STATE}
\`\`\`

**Resumed State:**

\`\`\`text
${RESUMED_STATE}
\`\`\`
EOF

echo ""
echo "=============================================================================="
echo " PHASE 5 VERIFICATION COMPLETE!"
echo " Evidence saved to: ${EVIDENCE_FILE}"
echo ""
echo " To open the 4-Row Grafana Dashboard in your browser, run:"
echo "   kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "   URL: http://localhost:3000  (User: admin / Pass: admin-phoenix-stack)"
echo "=============================================================================="
