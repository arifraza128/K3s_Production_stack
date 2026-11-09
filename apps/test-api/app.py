#!/usr/bin/env python3
"""
Phoenix Platform — Test API Microservice
Implements endpoints per docs/API.md:
  - GET / or /api/info  -> 200 JSON service info
  - GET /healthz        -> 200 liveness check
  - GET /readyz         -> 200 readiness check
  - GET /metrics        -> 200 Prometheus text exposition format
  - GET|POST /fail      -> 500 synthetic failure (triggers Phase 5 SLO alert)
  - GET|POST /crash     -> Process exit (blocked publicly via Phase 6 Ingress)
"""
import json
import os
import socket
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("PORT", "8080"))
VERSION = os.environ.get("APP_VERSION", "1.0.0")
HOSTNAME = socket.gethostname()

# In-memory Prometheus metrics counters & histogram buckets
REQUEST_COUNTS = {
    "200": 0,
    "404": 0,
    "500": 0,
}
LATENCY_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.3, 0.5, 1.0, 2.5]
BUCKET_COUNTS = {b: 0 for b in LATENCY_BUCKETS}
LATENCY_SUM = 0.0
LATENCY_COUNT = 0


def record_metrics(status_code: int, duration: float) -> None:
    global LATENCY_SUM, LATENCY_COUNT
    key = str(status_code)
    REQUEST_COUNTS[key] = REQUEST_COUNTS.get(key, 0) + 1
    LATENCY_SUM += duration
    LATENCY_COUNT += 1
    for b in LATENCY_BUCKETS:
        if duration <= b:
            BUCKET_COUNTS[b] += 1


class TestAPIHandler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, payload: dict, start_time: float) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        record_metrics(status, time.monotonic() - start_time)

    def do_GET(self) -> None:
        start = time.monotonic()
        if self.path in ("/", "/api", "/api/info"):
            self._send_json(
                200,
                {
                    "service": "phoenix-test-api",
                    "version": VERSION,
                    "status": "ok",
                    "hostname": HOSTNAME,
                },
                start,
            )
        elif self.path == "/healthz":
            self._send_json(200, {"status": "alive"}, start)
        elif self.path == "/readyz":
            self._send_json(200, {"status": "ready"}, start)
        elif self.path == "/fail":
            self._send_json(
                500,
                {
                    "error": "simulated_5xx_failure",
                    "message": "Triggered synthetic 500 error for SLO burn alert validation",
                },
                start,
            )
        elif self.path == "/crash":
            self._send_json(
                500,
                {"error": "crashing", "message": "Terminating process immediately"},
                start,
            )
            os._exit(1)
        elif self.path == "/metrics":
            lines = [
                "# HELP http_requests_total Total HTTP requests processed by test-api",
                "# TYPE http_requests_total counter",
            ]
            for status_str, count in sorted(REQUEST_COUNTS.items()):
                lines.append(f'http_requests_total{{service="test-api",status="{status_str}"}} {count}')

            lines.extend(
                [
                    "# HELP http_request_duration_seconds HTTP request latency histogram",
                    "# TYPE http_request_duration_seconds histogram",
                ]
            )
            for b in LATENCY_BUCKETS:
                lines.append(
                    f'http_request_duration_seconds_bucket{{service="test-api",le="{b}"}} {BUCKET_COUNTS[b]}'
                )
            lines.append(
                f'http_request_duration_seconds_bucket{{service="test-api",le="+Inf"}} {LATENCY_COUNT}'
            )
            lines.append(f'http_request_duration_seconds_sum{{service="test-api"}} {LATENCY_SUM:.6f}')
            lines.append(f'http_request_duration_seconds_count{{service="test-api"}} {LATENCY_COUNT}')

            payload = ("\n".join(lines) + "\n").encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        else:
            self._send_json(404, {"error": "not_found", "path": self.path}, start)

    def do_POST(self) -> None:
        self.do_GET()


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), TestAPIHandler)
    print(f"Starting phoenix-test-api v{VERSION} on 0.0.0.0:{PORT}...")
    server.serve_forever()

