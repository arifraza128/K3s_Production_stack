# Phase 5 Evidence — Observability, 3 SLOs, Discord Alerting & Heartbeat Verification

- **Measured Timestamp (UTC):** `2026-11-21T15:18:04Z`
- **Cluster Context:** `default`
- **Verification Script:** `scripts/verify-phase5.sh`
- **Discord Webhook Delivery Status:** `DELIVERED (HTTP 204 from Discord webhook at 2026-11-21T15:18:04Z)`

---

## 1. Monitoring Stack Pods & Phase 5 Custom Resources

```text
NAME                                                        READY   STATUS      RESTARTS       AGE   IP             NODE              NOMINATED NODE   READINESS GATES
alertmanager-kube-prometheus-stack-alertmanager-0           2/2     Running     3 (13m ago)    62m   10.42.0.128    ip-172-31-20-41   <none>           <none>
healthchecks-heartbeat-29921239-t7xj8                       0/1     Completed   0              42s   10.42.0.142    ip-172-31-20-41   <none>           <none>
kube-prometheus-stack-grafana-6665f7d454-fvxj5              3/3     Running     6 (13m ago)    11d   10.42.0.111    ip-172-31-20-41   <none>           <none>
kube-prometheus-stack-kube-state-metrics-68565d6658-c7f4t   1/1     Running     22 (13m ago)   11d   10.42.0.119    ip-172-31-20-41   <none>           <none>
kube-prometheus-stack-operator-6fb8b9bff4-77p5p             1/1     Running     4 (13m ago)    31m   10.42.0.107    ip-172-31-20-41   <none>           <none>
kube-prometheus-stack-prometheus-node-exporter-svxwc        1/1     Running     4 (13m ago)    11d   172.31.20.41   ip-172-31-20-41   <none>           <none>
prometheus-kube-prometheus-stack-prometheus-0               2/2     Running     3 (13m ago)    62m   10.42.0.114    ip-172-31-20-41   <none>           <none>

NAME                                                         AGE
prometheusrule.monitoring.coreos.com/phoenix-platform-slos   11d

NAME                                            AGE
servicemonitor.monitoring.coreos.com/test-api   11d

NAME                                      DATA   AGE
configmap/phoenix-slo-grafana-dashboard   1      11d
```

---

## 2. Evaluated 3 SLO Recording Rules & Scrape Metrics (`test_api:*`)

```json
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"__name__":"test_api:availability:ratio_rate5m"},"value":[1795274329.849,"1"]},{"metric":{"__name__":"test_api:availability:ratio_rate30m"},"value":[1795274329.849,"1"]},{"metric":{"__name__":"test_api:error_budget:remaining_ratio"},"value":[1795274329.849,"1"]},{"metric":{"__name__":"test_api:latency_p95:seconds_rate5m"},"value":[1795274329.849,"0.004750000000000001"]},{"metric":{"__name__":"test_api:latency_p99:seconds_rate5m"},"value":[1795274329.849,"0.00495"]},{"metric":{"__name__":"http_requests_total","container":"test-api","endpoint":"http","instance":"10.42.0.123:8080","job":"test-api","method":"GET","namespace":"default","path":"/healthz","pod":"test-api-6f8fcb5b7d-l7w8n","service":"test-api","status":"200"},"value":[1795274329.849,"59"]},{"metric":{"__name__":"http_requests_total","container":"test-api","endpoint":"http","instance":"10.42.0.123:8080","job":"test-api","method":"GET","namespace":"default","path":"/readyz","pod":"test-api-6f8fcb5b7d-l7w8n","service":"test-api","status":"200"},"value":[1795274329.849,"119"]},{"metric":{"__name__":"http_requests_total","container":"test-api","endpoint":"http","instance":"10.42.0.110:8080","job":"test-api","method":"GET","namespace":"default","path":"/healthz","pod":"test-api-6f8fcb5b7d-6xnjq","service":"test-api","status":"200"},"value":[1795274329.849,"61"]},{"metric":{"__name__":"http_requests_total","container":"test-api","endpoint":"http","instance":"10.42.0.110:8080","job":"test-api","method":"GET","namespace":"default","path":"/readyz","pod":"test-api-6f8fcb5b7d-6xnjq","service":"test-api","status":"200"},"value":[1795274329.849,"121"]},{"metric":{"__name__":"http_requests_total","container":"test-api","endpoint":"http","instance":"10.42.0.110:8080","job":"test-api","method":"GET","namespace":"default","path":"/work","pod":"test-api-6f8fcb5b7d-6xnjq","service":"test-api","status":"200"},"value":[1795274329.849,"25"]}]}}
```

---

## 3. Test 1: Force 5xx via `/fail` -> `TestApiHigh5xxErrorRate` Alert Firing

**Action:** Sent synthetic `GET /fail` requests to `default/test-api` to trigger HTTP `500` responses.

**Prometheus Alert / 5xx Metric Response:**

```json
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"__name__":"http_requests_total","container":"test-api","endpoint":"http","instance":"10.42.0.110:8080","job":"test-api","method":"GET","namespace":"default","path":"/fail","pod":"test-api-6f8fcb5b7d-6xnjq","service":"test-api","status":"500"},"value":[1795274376.870,"8"]}]}}
```

---

## 4. Test 2: Dead-Man's-Switch Heartbeat Suspension & Recovery

**Suspended State (simulating node/heartbeat loss for Healthchecks.io):**

```text
NAME                     SCHEDULE      TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE   CONTAINERS   IMAGES                   SELECTOR
healthchecks-heartbeat   */1 * * * *   <none>     True      0        41s             11d   ping         curlimages/curl:8.11.1   <none>
```

**Resumed State:**

```text
NAME                     SCHEDULE      TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE   CONTAINERS   IMAGES                   SELECTOR
healthchecks-heartbeat   */1 * * * *   <none>     False     0        42s             11d   ping         curlimages/curl:8.11.1   <none>
```
