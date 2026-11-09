#!/usr/bin/env python3
"""Table-driven unit tests for Phoenix Platform Test API (API.md contract)."""
import json
import unittest

import app


class TestPhoenixAPI(unittest.TestCase):
    def test_endpoints_table_driven_chaos_enabled(self) -> None:
        app.CHAOS_ENDPOINTS_ENABLED = True
        cases = [
            ("GET", "/healthz", 200, "status", False),
            ("GET", "/readyz", 200, "status", False),
            ("GET", "/version", 200, "version", False),
            ("GET", "/work", 200, "request_id", False),
            ("GET", "/slow?ms=10", 200, "slept_ms", False),
            ("GET", "/fail", 500, "error", False),
            ("POST", "/crash", 500, "error", True),
            ("GET", "/unknown-route", 404, "error", False),
        ]
        for method, path, expected_status, expected_key, expected_crash in cases:
            with self.subTest(method=method, path=path):
                status, content_type, body, should_crash = app.dispatch_request(method, path)
                self.assertEqual(status, expected_status)
                self.assertEqual(content_type, "application/json")
                self.assertEqual(should_crash, expected_crash)
                payload = json.loads(body.decode("utf-8"))
                self.assertIn(expected_key, payload)
                if expected_status >= 400:
                    self.assertIn("code", payload["error"])
                    self.assertIn("message", payload["error"])
                    self.assertIn("request_id", payload["error"])

    def test_chaos_endpoints_disabled_by_default(self) -> None:
        app.CHAOS_ENDPOINTS_ENABLED = False
        for method, path in [("GET", "/slow?ms=10"), ("GET", "/fail"), ("POST", "/crash")]:
            with self.subTest(method=method, path=path):
                status, _, body, should_crash = app.dispatch_request(method, path)
                self.assertEqual(status, 403)
                self.assertFalse(should_crash)
                payload = json.loads(body.decode("utf-8"))
                self.assertEqual(payload["error"]["code"], "CHAOS_DISABLED")

    def test_metrics_contract(self) -> None:
        app.CHAOS_ENDPOINTS_ENABLED = True
        app.dispatch_request("GET", "/work")
        status, content_type, body, _ = app.dispatch_request("GET", "/metrics")
        text = body.decode("utf-8")
        self.assertEqual(status, 200)
        self.assertIn("text/plain", content_type)
        self.assertIn("app_build_info{", text)
        self.assertIn('http_requests_total{path="/work",method="GET",status="200"}', text)
        self.assertIn('http_request_duration_seconds_bucket{path="/work",le="0.3"}', text)


if __name__ == "__main__":
    unittest.main()
