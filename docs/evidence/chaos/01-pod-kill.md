---
experiment: "01-pod-kill"
hypothesis: "With 2 replicas of test-api, force-deleting 1 pod maintains HTTP 200 service availability and Kubernetes recovers the replacement pod in < 60s."
injected_at: "2026-11-21T15:43:26Z"
recovered_at: "2026-11-21T15:43:34Z"
recovery_seconds: 8
result: "PASS"
dashboard_screenshot: "observability/grafana/k3s-platform-slo-dashboard.yaml"
---

# Chaos Experiment: 01 — Pod Kill (test-api)

- **Hypothesis:** With 2 replicas of test-api, force-deleting 1 pod maintains HTTP 200 service availability and Kubernetes recovers the replacement pod in < 60s.
- **Steady State:** 2/2 test-api pods Ready; https://13.207.161.55.sslip.io/work returning HTTP 200 ({"status": "completed", "request_id": "55222a99-46b8-4fa2-8cd4-bbe087bc8c10"})
- **Injection Method:** `kubectl delete pod test-api-6f8fcb5b7d-6xnjq -n default --grace-period=0 --force`
- **Injected At (UTC):** `2026-11-21T15:43:26Z`
- **Recovered At (UTC):** `2026-11-21T15:43:34Z`
- **Observation:**
```text
Killed pod: test-api-6f8fcb5b7d-6xnjq
HTTP status on https://13.207.161.55.sslip.io/work during pod replacement: 200
Replacement rollout completed in: 8s
Pods after recovery:
NAME                        READY   STATUS    RESTARTS      AGE   IP            NODE              NOMINATED NODE   READINESS GATES
test-api-6f8fcb5b7d-fhxpv   1/1     Running   0             8s    10.42.0.175   ip-172-31-20-41   <none>           <none>
test-api-6f8fcb5b7d-l7w8n   1/1     Running   7 (35m ago)   11d   10.42.0.123   ip-172-31-20-41   <none>           <none>
```
- **Recovery Seconds:** `8s`
- **Result:** **PASS**
- **Dashboard Screenshot:** Grafana `phoenix-platform-slos` Row 1 & Row 3 annotations
- **Follow-ups:** Automated assertion passed (< 60s SLO recovery threshold).
