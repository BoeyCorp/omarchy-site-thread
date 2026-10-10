from __future__ import annotations

import importlib.machinery
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("site_thread", str(ROOT / "bin" / "site-thread"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC is not None
SITE_THREAD = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(SITE_THREAD)


class FeatureTelemetryTests(unittest.TestCase):
    def test_demo_summary_has_coordinates_and_gateways(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertTrue(summary.get("ok"))
        self.assertTrue(summary.get("demo"))
        sites = summary.get("sites", [])
        self.assertEqual(len(sites), 3)

        for site in sites:
            self.assertIn("lat", site)
            self.assertIn("lng", site)
            self.assertIsInstance(site["lat"], (int, float))
            self.assertIsInstance(site["lng"], (int, float))
            self.assertIn("gatewayModel", site)
            self.assertIn("gatewayIp", site)
            self.assertIn("wifiClients", site)
            self.assertIn("wiredClients", site)

        network = summary.get("network", {})
        self.assertIn("wifiClients", network)
        self.assertIn("wiredClients", network)
        self.assertIn("gatewaysCount", network)
        self.assertGreaterEqual(network["gatewaysCount"], 1)

    def test_demo_summary_has_sdwan_and_uplinks(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("sdwan", summary)
        sdwan = summary["sdwan"]
        self.assertTrue(sdwan.get("available"))
        self.assertEqual(sdwan.get("status"), "connected")
        self.assertGreaterEqual(len(sdwan.get("connections", [])), 1)

        devices = summary.get("network", {}).get("devices", [])
        self.assertTrue(any(d.get("parentName") for d in devices))

    def test_demo_summary_has_active_and_resolved_issues(self) -> None:
        summary = SITE_THREAD.demo_summary()
        issues = summary.get("issues", [])
        self.assertTrue(len(issues) >= 2)

        active = [i for i in issues if i.get("active") is True]
        resolved = [i for i in issues if i.get("active") is False]

        self.assertTrue(len(active) >= 1)
        self.assertTrue(len(resolved) >= 1)

        for res in resolved:
            self.assertIn("resolvedAt", res)
            self.assertIn("durationSeconds", res)
            self.assertGreater(res["durationSeconds"], 0)

    def test_timezone_coordinates_resolution(self) -> None:
        # Perth
        lat, lng = SITE_THREAD.site_coordinates({}, "Australia/Perth", 0)
        self.assertAlmostEqual(lat, -31.95, delta=1.0)
        self.assertAlmostEqual(lng, 115.86, delta=1.0)

        # London
        lat, lng = SITE_THREAD.site_coordinates({}, "Europe/London", 0)
        self.assertAlmostEqual(lat, 51.51, delta=1.0)
        self.assertAlmostEqual(lng, -0.13, delta=1.0)

        # Chicago
        lat, lng = SITE_THREAD.site_coordinates({}, "America/Chicago", 0)
        self.assertAlmostEqual(lat, 41.88, delta=1.0)
        self.assertAlmostEqual(lng, -87.63, delta=1.0)

    def test_custom_coordinates_override_timezone(self) -> None:
        meta = {"lat": 12.3456, "lng": 78.9012}
        lat, lng = SITE_THREAD.site_coordinates(meta, "Australia/Perth", 0)
        self.assertEqual(lat, 12.3456)
        self.assertEqual(lng, 78.9012)


if __name__ == "__main__":
    unittest.main()
