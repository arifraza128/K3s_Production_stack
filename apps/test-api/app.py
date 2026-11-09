#!/usr/bin/env python3
"""
Phoenix Platform — Test API Microservice (Strictly compliant with API.md)
Endpoints:
  - GET  /healthz    -> Liveness (200 if process is up)
  - GET  /readyz     -> Readiness (200 only when ready to serve)
  - GET  /version    -> Build info (version, git sha, image digest)
  - GET  /work       -> Normal request with small realistic latency; SLO target path
  - GET  /metrics    -> Prometheus metrics (http_requests_total, http_request_duration_seconds_bucket, app_build_info)
  - GET  /slow?ms=N  -> Sleep N ms (max cap 5000), requires CHAOS_ENDPOINTS_ENABLED=true
  - GET  /fail       -> Returns 500, requires CHAOS_ENDPOINTS_ENABLED=true
  - POST /crash      -> Exits process, requires CHAOS_ENDPOINTS_ENABLED=true
"""
import json
import os
import random
import time
import urllib.parse
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Dict, Tuple

PORT: int = int(os.environ.get("PORT", "8080"))
APP_VERSION: str = os.environ.get("APP_VERSION", "1.0.0")
GIT_SHA: str = os.environ.get("GIT_SHA", "dfd25e5")
IMAGE_DIGEST: str = os.environ.get("IMAGE_DIGEST", "sha256:pinned")
CHAOS_ENDPOINTS_ENABLED: bool = (
    os.environ.get("CHAOS_ENDPOINTS_ENABLED", "false").lower() == "true"
)

LATENCY_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 2.5, 5.0]

REQUEST_COUNTS: Dict[Tuple[str, str, str], int] = {}
BUCKET_COUNTS: Dict[Tuple[str, float], int] = {}
LATENCY_SUM: Dict[str, float] = {}
LATENCY_COUNT: Dict[str, int] = {}


def record_request_metric(path: str, method: str, status: int, duration: float) -> None:
    key = (path, method, str(status))
    REQUEST_COUNTS[key] = REQUEST_COUNTS.get(key, 0) + 1
    LATENCY_SUM[path] = LATENCY_SUM.get(path, 0.0) + duration
    LATENCY_COUNT[path] = LATENCY_COUNT.get(path, 0) + 1
    for bound in LATENCY_BUCKETS:
        if duration <= bound:
            bkey = (path, bound)
            BUCKET_COUNTS[bkey] = BUCKET_COUNTS.get(bkey, 0) + 1


def make_error_payload(code: str, message: str, request_id: str) -> dict:
    return {
        "error": {
            "code": code,
            "message": message,
            "request_id": request_id,
        }
    }


def render_prometheus_metrics() -> str:
    lines = [
        "# HELP app_build_info Build metadata for test-api",
        "# TYPE app_build_info gauge",
        f'app_build_info{{version="{APP_VERSION}",sha="{GIT_SHA}"}} 1',
        "# HELP http_requests_total Total HTTP requests by path, method, and status",
        "# TYPE http_requests_total counter",
    ]
    for (path, method, status), count in sorted(REQUEST_COUNTS.items()):
        lines.append(
            f'http_requests_total{{path="{path}",method="{method}",status="{status}"}} {count}'
        )

    lines.extend(
        [
            "# HELP http_request_duration_seconds HTTP request latency histogram by path",
            "# TYPE http_request_duration_seconds histogram",
        ]
    )
    for path in sorted(LATENCY_COUNT.keys()):
        for bound in LATENCY_BUCKETS:
            cnt = BUCKET_COUNTS.get((path, bound), 0)
            lines.append(
                f'http_request_duration_seconds_bucket{{path="{path}",le="{bound}"}} {cnt}'
            )
        total_cnt = LATENCY_COUNT[path]
        total_sum = LATENCY_SUM[path]
        lines.append(
            f'http_request_duration_seconds_bucket{{path="{path}",le="+Inf"}} {total_cnt}'
        )
        lines.append(f'http_request_duration_seconds_sum{{path="{path}"}} {total_sum:.6f}')
        lines.append(f'http_request_duration_seconds_count{{path="{path}"}} {total_cnt}')

    return "\n".join(lines) + "\n"


def dispatch_request(method: str, full_path: str) -> Tuple[int, str, bytes, bool]:
    """Pure request dispatcher returning (status, content_type, body, should_crash)."""
    start = time.monotonic()
    request_id = str(uuid.uuid4())
    parsed = urllib.parse.urlparse(full_path)
    route_path = parsed.path

    def _json_resp(status: int, payload: dict, should_crash: bool = False) -> Tuple[int, str, bytes, bool]:
        duration = time.monotonic() - start
        record_request_metric(route_path, method, status, duration)
        print(
            json.dumps(
                {
                    "method": method,
                    "path": route_path,
                    "status": status,
                    "duration_ms": round(duration * 1000, 2),
                    "request_id": request_id,
                }
            ),
            flush=True,
        )
        return status, "application/json", json.dumps(payload).encode("utf-8"), should_crash

    if method == "GET":
        if route_path == "/healthz":
            return _json_resp(200, {"status": "ok"})
        if route_path == "/readyz":
            return _json_resp(200, {"status": "ready"})
        if route_path == "/version":
            return _json_resp(
                200,
                {
                    "version": APP_VERSION,
                    "sha": GIT_SHA,
                    "image_digest": IMAGE_DIGEST,
                },
            )
        if route_path == "/work":
            time.sleep(random.uniform(0.005, 0.025))
            return _json_resp(200, {"status": "completed", "request_id": request_id})
        if route_path == "/metrics":
            body = render_prometheus_metrics().encode("utf-8")
            return 200, "text/plain; version=0.0.4", body, False
        if route_path == "/slow":
            if not CHAOS_ENDPOINTS_ENABLED:
                return _json_resp(
                    403,
                    make_error_payload(
                        "CHAOS_DISABLED",
                        "Chaos endpoints are disabled unless CHAOS_ENDPOINTS_ENABLED=true",
                        request_id,
                    ),
                )
            qs = urllib.parse.parse_qs(parsed.query)
            try:
                ms = int(qs.get("ms", ["100"])[0])
            except ValueError:
                ms = 100
            ms = max(0, min(ms, 5000))
            time.sleep(ms / 1000.0)
            return _json_resp(
                200,
                {"status": "slow_completed", "slept_ms": ms, "request_id": request_id},
            )
        if route_path == "/fail":
            if not CHAOS_ENDPOINTS_ENABLED:
                return _json_resp(
                    403,
                    make_error_payload(
                        "CHAOS_DISABLED",
                        "Chaos endpoints are disabled unless CHAOS_ENDPOINTS_ENABLED=true",
                        request_id,
                    ),
                )
            return _json_resp(
                500,
                make_error_payload(
                    "SIMULATED_FAILURE",
                    "Synthetic 500 response triggered via /fail",
                    request_id,
                ),
            )
        return _json_resp(
            404,
            make_error_payload("NOT_FOUND", f"Path {route_path} not found", request_id),
        )

    if method == "POST":
        if route_path == "/crash":
            if not CHAOS_ENDPOINTS_ENABLED:
                return _json_resp(
                    403,
                    make_error_payload(
                        "CHAOS_DISABLED",
                        "Chaos endpoints are disabled unless CHAOS_ENDPOINTS_ENABLED=true",
                        request_id,
                    ),
                )
            return _json_resp(
                500,
                make_error_payload(
                    "PROCESS_CRASH",
                    "Exiting process immediately for chaos test",
                    request_id,
                ),
                should_crash=True,
            )
        return _json_resp(
            404,
            make_error_payload("NOT_FOUND", f"Path {route_path} not found", request_id),
        )

    return _json_resp(
        405,
        make_error_payload("METHOD_NOT_ALLOWED", f"Method {method} not allowed", request_id),
    )


class TestAPIHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        pass

    def _handle(self, method: str) -> None:
        status, content_type, body, should_crash = dispatch_request(method, self.path)
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        if should_crash:
            os._exit(1)

    def do_GET(self) -> None:
        self._handle("GET")

    def do_POST(self) -> None:
        self._handle("POST")


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), TestAPIHandler)
    print(f"Starting phoenix-test-api v{APP_VERSION} (sha={GIT_SHA}) on 0.0.0.0:{PORT}...")
    server.serve_forever()
