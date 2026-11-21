#!/usr/bin/env python3
"""
Table-driven unit tests for Phoenix Test API (API.md contract verification).
"""
import json
import os
import unittest

import app


class TestPhoenixAPI(unittest.TestCase):
    def test_endpoints_table_driven_chaos_enabled(self) -> None:
        os.environ["CHAOS_ENDPOINTS_ENABLED"] = "true"
        cases = [
            ("GET", "/", 200, "Phoenix Platform"),
            ("GET", "/healthz", 200, "ok"),
            ("GET", "/readyz", 200, "ready"),
            ("GET", "/version", 200, "version"),
            ("GET", "/work", 200, "completed"),
            ("GET", "/slow?ms=10", 200, "slow_completed"),
            ("GET", "/fail", 500, "SIMULATED_500_FAILURE"),
            ("POST", "/crash", 500, "SIMULATED_CRASH"),
            ("GET", "/unknown-route", 404, "NOT_FOUND"),
        ]
        for method, path, expected_status, expected_substr in cases:
            with self.subTest(method=method, path=path):
                status, _, raw = app.dispatch_request(method, path)
                body = raw.decode("utf-8")
                self.assertEqual(status, expected_status)
                self.assertIn(expected_substr, body)
                if expected_status >= 400:
                    parsed = json.loads(body)
                    self.assertIn("error", parsed)
                    self.assertIn("code", parsed["error"])
                    self.assertIn("message", parsed["error"])
                    self.assertIn("request_id", parsed["error"])

    def test_chaos_endpoints_disabled_by_default(self) -> None:
        os.environ["CHAOS_ENDPOINTS_ENABLED"] = "false"
        for method, path in [("GET", "/slow"), ("GET", "/fail"), ("POST", "/crash")]:
            with self.subTest(method=method, path=path):
                status, _, raw = app.dispatch_request(method, path)
                self.assertEqual(status, 403)
                parsed = json.loads(raw.decode("utf-8"))
                self.assertEqual(parsed["error"]["code"], "CHAOS_DISABLED")

    def test_metrics_contract(self) -> None:
        os.environ["CHAOS_ENDPOINTS_ENABLED"] = "true"
        app.dispatch_request("GET", "/work")
        status, _, raw = app.dispatch_request("GET", "/metrics")
        body = raw.decode("utf-8")
        self.assertEqual(status, 200)
        self.assertIn("http_requests_total{", body)
        self.assertIn("http_request_duration_seconds_bucket{", body)
        self.assertIn("app_build_info{", body)


if __name__ == "__main__":
    unittest.main()
