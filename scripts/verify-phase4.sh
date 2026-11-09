#!/usr/bin/env bash
# ==============================================================================
# Phoenix Platform — Phase 4 End-to-End Execution & Verification Script
# Runs Phase 4 from start to finish:
#   1. Local unit tests (apps/test-api)
#   2. Kyverno & Sealed Secrets installation/readiness check on K3s
#   3. Apply Phase 4 Security Kustomization (ClusterPolicies + NetworkPolicies)
#   4. Negative Test 1a: Unsigned image blocked by Kyverno (writes evidence)
#   5. Negative Test 1b: Privileged pod blocked by Kyverno (writes evidence)
#   6. Negative Test 1c: Pod without CPU/memory limits blocked by Kyverno
#   7. Positive Test: Sealed Secrets master key backup & controller verification
#   8. Positive Test: Deploy signed test-api & verify all API endpoints
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_FILE="${REPO_ROOT}/docs/evidence/phase4-kyverno-denial.md"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo "=============================================================================="
echo " Phoenix Platform — Phase 4 End-to-End Verification (${TIMESTAMP})"
echo "=============================================================================="

# ------------------------------------------------------------------------------
# Step 1: Run Test API Unit Tests
# ------------------------------------------------------------------------------
echo ""
echo "[Step 1/7] Running Test API table-driven unit tests..."
python3 -m unittest discover -s "${REPO_ROOT}/apps/test-api" -v

# ------------------------------------------------------------------------------
# Step 2: Check K3s Cluster Connectivity
# ------------------------------------------------------------------------------
echo ""
echo "[Step 2/7] Verifying K3s cluster connectivity..."
if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is not installed or not in PATH." >&2
  exit 1
fi
kubectl cluster-info
kubectl get nodes -o wide

# ------------------------------------------------------------------------------
# Step 3: Ensure Kyverno & Sealed Secrets Controllers Are Running
# ------------------------------------------------------------------------------
echo ""
echo "[Step 3/7] Ensuring Kyverno & Sealed Secrets controllers are installed and Ready..."

if ! kubectl get namespace kyverno >/dev/null 2>&1; then
  echo "  -> Installing Kyverno v3.2.6 via Helm (or ArgoCD Application)..."
  if command -v helm >/dev/null 2>&1; then
    helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update
    helm repo update
    helm upgrade --install kyverno kyverno/kyverno \
      --namespace kyverno --create-namespace \
      --version 3.2.6 \
      --set admissionController.replicas=1 \
      --set backgroundController.replicas=1 \
      --set cleanupController.replicas=1 \
      --set reportsController.replicas=1 \
      --wait --timeout 300s
  else
    kubectl apply -f "${REPO_ROOT}/gitops/argocd-apps/00-kyverno.yaml"
  fi
fi

echo "  -> Waiting for Kyverno admission controller deployment to be Ready..."
kubectl rollout status deployment/kyverno-admission-controller -n kyverno --timeout=300s

echo "  -> Applying Phase 4 security kustomization (Sealed Secrets + Kyverno Policies + NetworkPolicy)..."
kubectl apply -k "${REPO_ROOT}/security" --server-side --force-conflicts

echo "  -> Waiting for Sealed Secrets controller in kube-system..."
kubectl rollout status deployment/sealed-secrets-controller -n kube-system --timeout=180s

echo "  -> Waiting for Kyverno ClusterPolicies to become Ready..."
for policy in verify-cosign-image-signatures disallow-privileged-and-host-namespaces require-pod-requests-and-limits; do
  kubectl wait --for=condition=Ready "clusterpolicy/${policy}" --timeout=120s
done
kubectl get clusterpolicy

# ------------------------------------------------------------------------------
# Step 4: Negative Tests — Kyverno Admission Control (Record Real Evidence)
# ------------------------------------------------------------------------------
echo ""
echo "[Step 4/7] Running Negative Tests against Kyverno Admission Webhook..."

# 4a: Unsigned image under ghcr.io/arifraza128/* (with valid limits & non-root so it specifically hits verifyImages)
UNSIGNED_YAML="$(mktemp)"
cat <<'EOF' > "${UNSIGNED_YAML}"
apiVersion: v1
kind: Pod
metadata:
  name: unsigned-image-test
  namespace: default
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
  containers:
    - name: unsigned
      image: ghcr.io/arifraza128/unsigned-test:v1
      securityContext:
        allowPrivilegeEscalation: false
        privileged: false
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          cpu: 50m
          memory: 32Mi
EOF

set +e
UNSIGNED_OUTPUT="$(kubectl apply -f "${UNSIGNED_YAML}" 2>&1)"
UNSIGNED_RC=$?
set -e
rm -f "${UNSIGNED_YAML}"

if [[ ${UNSIGNED_RC} -eq 0 ]]; then
  echo "FAIL: Expected Kyverno to reject unsigned image, but pod was admitted!" >&2
  kubectl delete pod unsigned-image-test -n default --ignore-not-found
  exit 1
fi
echo "  [PASS] Unsigned image rejected by Kyverno:"
echo "  ${UNSIGNED_OUTPUT}"

# 4b: Privileged pod test
PRIV_YAML="$(mktemp)"
cat <<'EOF' > "${PRIV_YAML}"
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod-test
  namespace: default
spec:
  containers:
    - name: priv
      image: busybox:1.36.1
      command: ["sleep", "5"]
      securityContext:
        privileged: true
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          cpu: 50m
          memory: 32Mi
EOF

set +e
PRIV_OUTPUT="$(kubectl apply -f "${PRIV_YAML}" 2>&1)"
PRIV_RC=$?
set -e
rm -f "${PRIV_YAML}"

if [[ ${PRIV_RC} -eq 0 ]]; then
  echo "FAIL: Expected Kyverno to reject privileged pod, but pod was admitted!" >&2
  kubectl delete pod privileged-pod-test -n default --ignore-not-found
  exit 1
fi
echo "  [PASS] Privileged pod rejected by Kyverno:"
echo "  ${PRIV_OUTPUT}"

# 4c: Missing resource requests/limits test
NOLIMITS_YAML="$(mktemp)"
cat <<'EOF' > "${NOLIMITS_YAML}"
apiVersion: v1
kind: Pod
metadata:
  name: no-limits-pod-test
  namespace: default
spec:
  containers:
    - name: nolimits
      image: busybox:1.36.1
      command: ["sleep", "5"]
EOF

set +e
NOLIMITS_OUTPUT="$(kubectl apply -f "${NOLIMITS_YAML}" 2>&1)"
NOLIMITS_RC=$?
set -e
rm -f "${NOLIMITS_YAML}"

if [[ ${NOLIMITS_RC} -eq 0 ]]; then
  echo "FAIL: Expected Kyverno to reject pod without resource limits, but pod was admitted!" >&2
  kubectl delete pod no-limits-pod-test -n default --ignore-not-found
  exit 1
fi
echo "  [PASS] Pod without requests/limits rejected by Kyverno:"
echo "  ${NOLIMITS_OUTPUT}"

# Write verbatim evidence to docs/evidence/phase4-kyverno-denial.md
cat <<EOF > "${EVIDENCE_FILE}"
# Phase 4 Evidence — Negative Test 1: Kyverno Admission Webhook Denial

- **Measured Timestamp (UTC):** \`${TIMESTAMP}\`
- **Cluster Context:** \`$(kubectl config current-context)\`
- **Verification Script:** \`scripts/verify-phase4.sh\`

---

## 1. Active Kyverno ClusterPolicies

\`\`\`text
$(kubectl get clusterpolicy)
\`\`\`

---

## 2. Negative Test 1a: Unsigned Container Image (\`verify-cosign-image-signatures\`)

**Command:** \`kubectl apply\` of Pod \`default/unsigned-image-test\` using unsigned image \`ghcr.io/arifraza128/unsigned-test:v1\`

**Result:** **PASS (Rejected by Admission Webhook, exit code ${UNSIGNED_RC})**

\`\`\`text
${UNSIGNED_OUTPUT}
\`\`\`

---

## 3. Negative Test 1b: Privileged Container (\`disallow-privileged-and-host-namespaces\`)

**Command:** \`kubectl apply\` of Pod \`default/privileged-pod-test\` with \`securityContext.privileged: true\`

**Result:** **PASS (Rejected by Admission Webhook, exit code ${PRIV_RC})**

\`\`\`text
${PRIV_OUTPUT}
\`\`\`

---

## 4. Negative Test 1c: Missing Resource Requests & Limits (\`require-pod-requests-and-limits\`)

**Command:** \`kubectl apply\` of Pod \`default/no-limits-pod-test\` without CPU/memory requests and limits

**Result:** **PASS (Rejected by Admission Webhook, exit code ${NOLIMITS_RC})**

\`\`\`text
${NOLIMITS_OUTPUT}
\`\`\`
EOF

echo "  -> Wrote real admission denial evidence to: ${EVIDENCE_FILE}"

# ------------------------------------------------------------------------------
# Step 5: Sealed Secrets Master Key Backup & Verification
# ------------------------------------------------------------------------------
echo ""
echo "[Step 5/7] Backing up Sealed Secrets master key..."
bash "${REPO_ROOT}/security/sealed-secrets/backup-sealed-secrets-key.sh"

# ------------------------------------------------------------------------------
# Step 6: Positive Test — Deploy Signed test-api Workload
# ------------------------------------------------------------------------------
echo ""
echo "[Step 6/7] Deploying Cosign-signed test-api workload (apps/test-api/k8s)..."
kubectl apply -k "${REPO_ROOT}/apps/test-api/k8s"
kubectl rollout status deployment/test-api -n default --timeout=180s
kubectl get pods -n default -l app=test-api -o wide

# ------------------------------------------------------------------------------
# Step 7: Verify All test-api Endpoints (/healthz, /readyz, /version, /work, /metrics)
# ------------------------------------------------------------------------------
echo ""
echo "[Step 7/7] Verifying test-api HTTP endpoints via port-forward..."
kubectl port-forward svc/test-api -n default 18080:80 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 3

echo "  -> GET /healthz:"
curl -sf http://127.0.0.1:18080/healthz && echo ""

echo "  -> GET /readyz:"
curl -sf http://127.0.0.1:18080/readyz && echo ""

echo "  -> GET /version:"
curl -sf http://127.0.0.1:18080/version && echo ""

echo "  -> GET /work:"
curl -sf http://127.0.0.1:18080/work && echo ""

echo "  -> GET /metrics (first 10 lines):"
curl -sf http://127.0.0.1:18080/metrics | head -n 10

echo ""
echo "=============================================================================="
echo " PHASE 4 VERIFICATION COMPLETE — ALL POSITIVE & NEGATIVE CHECKS PASSED!"
echo " Evidence saved to: ${EVIDENCE_FILE}"
echo "=============================================================================="

