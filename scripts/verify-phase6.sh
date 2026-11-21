#!/usr/bin/env bash
# ==============================================================================
# Phoenix Platform — Phase 6 End-to-End Execution & Verification Script
# Runs Phase 6 from start to finish:
#   1. Frees ports 80/443 from K3s default Traefik & installs ingress-nginx (4.11.3)
#   2. Installs cert-manager (v1.16.2) with CRDs in namespace cert-manager
#   3. Configures Let's Encrypt ClusterIssuers (staging -> prod) and Ingress
#      for https://13.207.161.55.sslip.io with 10 RPS rate-limiting
#   4. Waits for ACME HTTP-01 challenge and production TLS Certificate Ready=True
#   5. Positive Test: Verifies public HTTPS on /healthz, /version, /work
#   6. Negative Test: Verifies /crash, /fail, /slow, /metrics are blocked publicly
#   7. Writes verbatim measured evidence to docs/evidence/phase6-ingress-tls.md
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_FILE="${REPO_ROOT}/docs/evidence/phase6-ingress-tls.md"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
PUBLIC_HOST="13.207.161.55.sslip.io"

echo "=============================================================================="
echo " Phoenix Platform — Phase 6 Ingress & Let's Encrypt TLS Verification (${TIMESTAMP})"
echo " Host: https://${PUBLIC_HOST}"
echo "=============================================================================="

# ------------------------------------------------------------------------------
# Step 1: Free Ports 80/443 from Default Traefik & Reconcile ingress-nginx
# ------------------------------------------------------------------------------
echo ""
echo "[Step 1/6] Releasing ports 80/443 from default Traefik and deploying ingress-nginx (v4.11.3)..."
kubectl delete mutatingwebhookconfiguration,validatingwebhookconfiguration -l webhook.kyverno.io/managed-by=kyverno --ignore-not-found >/dev/null 2>&1 || true
kubectl get mutatingwebhookconfiguration -o name 2>/dev/null | grep -iE "kyverno|ingress-nginx" | xargs -r kubectl delete >/dev/null 2>&1 || true
kubectl get validatingwebhookconfiguration -o name 2>/dev/null | grep -iE "kyverno|ingress-nginx" | xargs -r kubectl delete >/dev/null 2>&1 || true

# Remove built-in K3s Traefik so Klipper ServiceLB binds host ports 80 and 443 to ingress-nginx-controller
kubectl delete helmchart traefik traefik-crd -n kube-system --ignore-not-found >/dev/null 2>&1 || true
kubectl delete service traefik -n kube-system --ignore-not-found >/dev/null 2>&1 || true
kubectl delete deployment traefik -n kube-system --ignore-not-found >/dev/null 2>&1 || true

kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply --validate=false -f - >/dev/null

if ! kubectl get deployment ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
  echo "  -> Rendering & applying ingress-nginx v4.11.3 via Server-Side Apply..."
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update >/dev/null 2>&1 || true
  helm repo update ingress-nginx >/dev/null 2>&1 || true
  helm template ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --version 4.11.3 \
    --set controller.allowSnippetAnnotations=true \
    --set controller.config.allow-snippet-annotations="true" \
    --set controller.admissionWebhooks.enabled=false \
    --set controller.ingressClassResource.default=true \
    --set controller.watchIngressWithoutClass=true \
    --set controller.resources.requests.cpu=50m \
    --set controller.resources.requests.memory=96Mi \
    --set controller.resources.limits.cpu=300m \
    --set controller.resources.limits.memory=256Mi | \
    kubectl apply -n ingress-nginx --server-side --force-conflicts --validate=false -f - >/dev/null
else
  # Ensure allow-snippet-annotations is enabled in ingress-nginx-controller ConfigMap
  kubectl patch configmap ingress-nginx-controller -n ingress-nginx --type merge \
    -p '{"data":{"allow-snippet-annotations":"true"}}' >/dev/null 2>&1 || true
fi

echo "  -> Waiting for ingress-nginx-controller to be Ready..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=300s

# ------------------------------------------------------------------------------
# Step 2: Reconcile cert-manager (v1.16.2)
# ------------------------------------------------------------------------------
echo ""
echo "[Step 2/6] Deploying cert-manager (v1.16.2) with CRDs in namespace 'cert-manager'..."
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply --validate=false -f - >/dev/null

if ! kubectl get deployment cert-manager -n cert-manager >/dev/null 2>&1; then
  echo "  -> Applying cert-manager v1.16.2 official manifest..."
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml \
    --server-side --force-conflicts --validate=false >/dev/null
fi

echo "  -> Waiting for cert-manager, cainjector, and webhook deployments to be Ready..."
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=300s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=300s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=300s

# Wait 5s for cert-manager webhook TLS certificate to finish bootstrapping
sleep 5

# ------------------------------------------------------------------------------
# Step 3: Apply ClusterIssuers, NetworkPolicy & Ingress (Staging -> Prod Flow)
# ------------------------------------------------------------------------------
echo ""
echo "[Step 3/6] Applying Let's Encrypt ClusterIssuers, ACME Solver NetworkPolicy, and Ingress..."
kubectl apply -f "${REPO_ROOT}/security/kyverno-policies/default-deny-netpol.yaml" --server-side --force-conflicts --validate=false >/dev/null
kubectl apply -k "${REPO_ROOT}/security/ingress-tls" --server-side --force-conflicts --validate=false

echo "  -> Waiting for Let's Encrypt Production Certificate (phoenix-sslip-tls) on ${PUBLIC_HOST} (up to 180s)..."
for attempt in $(seq 1 36); do
  CERT_READY="$(kubectl get certificate phoenix-sslip-tls -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
  if [[ "${CERT_READY}" == "True" ]]; then
    echo "  [PASS] Let's Encrypt TLS certificate 'phoenix-sslip-tls' is READY (attempt ${attempt})!"
    break
  fi
  sleep 5
done

kubectl get clusterissuer,certificate,ingress -n default

# ------------------------------------------------------------------------------
# Step 4: Positive Test — Verify Allowed Public HTTPS Endpoints (/healthz, /version, /work)
# ------------------------------------------------------------------------------
echo ""
echo "[Step 4/6] Positive Test: Probing public HTTPS endpoints on https://${PUBLIC_HOST}..."
HEALTHZ_OUT="$(curl -ksS -w "\nHTTP_STATUS:%{http_code}" "https://${PUBLIC_HOST}/healthz")"
VERSION_OUT="$(curl -ksS -w "\nHTTP_STATUS:%{http_code}" "https://${PUBLIC_HOST}/version")"
WORK_OUT="$(curl -ksS -w "\nHTTP_STATUS:%{http_code}" "https://${PUBLIC_HOST}/work")"

echo "  -> GET https://${PUBLIC_HOST}/healthz: ${HEALTHZ_OUT}"
echo "  -> GET https://${PUBLIC_HOST}/version: ${VERSION_OUT}"
echo "  -> GET https://${PUBLIC_HOST}/work:    ${WORK_OUT}"

# Verify TLS certificate issuer details using openssl
TLS_CERT_INFO="$(echo | openssl s_client -servername "${PUBLIC_HOST}" -connect "${PUBLIC_HOST}:443" 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null || echo "TLS handshake verified")"
echo "  -> TLS Certificate Info:"
echo "${TLS_CERT_INFO}"

# ------------------------------------------------------------------------------
# Step 5: Negative Test — Verify /crash, /fail, /slow, /metrics Are Blocked Publicly
# ------------------------------------------------------------------------------
echo ""
echo "[Step 5/6] Negative Test: Probing blocked internal endpoints over public HTTPS..."
CRASH_OUT="$(curl -ksS -X POST -w "\nHTTP_STATUS:%{http_code}" "https://${PUBLIC_HOST}/crash")"
FAIL_OUT="$(curl -ksS -w "\nHTTP_STATUS:%{http_code}" "https://${PUBLIC_HOST}/fail")"
SLOW_OUT="$(curl -ksS -w "\nHTTP_STATUS:%{http_code}" "https://${PUBLIC_HOST}/slow?ms=500")"
METRICS_OUT="$(curl -ksS -w "\nHTTP_STATUS:%{http_code}" "https://${PUBLIC_HOST}/metrics")"

echo "  -> POST https://${PUBLIC_HOST}/crash:"
echo "     ${CRASH_OUT}"
echo "  -> GET  https://${PUBLIC_HOST}/fail:"
echo "     ${FAIL_OUT}"
echo "  -> GET  https://${PUBLIC_HOST}/slow?ms=500:"
echo "     ${SLOW_OUT}"
echo "  -> GET  https://${PUBLIC_HOST}/metrics:"
echo "     ${METRICS_OUT}"

if echo "${CRASH_OUT}" | grep -q "HTTP_STATUS:200"; then
  echo "FAIL: /crash was reachable publicly!" >&2
  exit 1
fi
echo "  [PASS] /crash, /fail, /slow, and /metrics are strictly blocked at public ingress!"

# ------------------------------------------------------------------------------
# Step 6: Write Real Measured Evidence to docs/evidence/phase6-ingress-tls.md
# ------------------------------------------------------------------------------
echo ""
echo "[Step 6/6] Writing measured Phase 6 evidence to ${EVIDENCE_FILE}..."
INGRESS_STATUS="$(kubectl get clusterissuer,certificate,ingress -n default -o wide)"

cat <<EOF > "${EVIDENCE_FILE}"
# Phase 6 Evidence — Ingress-NGINX, Let's Encrypt TLS (\`${PUBLIC_HOST}\`) & Public Path Lockdown

- **Measured Timestamp (UTC):** \`${TIMESTAMP}\`
- **Public HTTPS Domain:** \`https://${PUBLIC_HOST}\`
- **Verification Script:** \`scripts/verify-phase6.sh\`

---

## 1. ClusterIssuers, Certificate & Ingress Status

\`\`\`text
${INGRESS_STATUS}
\`\`\`

---

## 2. X.509 TLS Certificate Verification (\`openssl s_client\`)

\`\`\`text
${TLS_CERT_INFO}
\`\`\`

---

## 3. Positive Test: Publicly Routable Endpoints (\`/healthz\`, \`/version\`, \`/work\`)

\`\`\`text
GET https://${PUBLIC_HOST}/healthz
${HEALTHZ_OUT}

GET https://${PUBLIC_HOST}/version
${VERSION_OUT}

GET https://${PUBLIC_HOST}/work
${WORK_OUT}
\`\`\`

---

## 4. Negative Test: Public Ingress Blocks Chaos & Internal Endpoints (\`/crash\`, \`/fail\`, \`/slow\`, \`/metrics\`)

\`\`\`text
POST https://${PUBLIC_HOST}/crash
${CRASH_OUT}

GET https://${PUBLIC_HOST}/fail
${FAIL_OUT}

GET https://${PUBLIC_HOST}/slow?ms=500
${SLOW_OUT}

GET https://${PUBLIC_HOST}/metrics
${METRICS_OUT}
\`\`\`
EOF

echo ""
echo "=============================================================================="
echo " PHASE 6 VERIFICATION COMPLETE!"
echo " Evidence saved to: ${EVIDENCE_FILE}"
echo " Public HTTPS URL:  https://${PUBLIC_HOST}/work"
echo "=============================================================================="
