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

    def test_demo_summary_has_clients_telemetry(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("clients", summary)
        clients = summary["clients"]
        self.assertGreaterEqual(len(clients), 3)
        for client in clients:
            self.assertIn("name", client)
            self.assertIn("ip", client)
            self.assertIn("mac", client)
            self.assertIn("uplinkName", client)
            self.assertIn("uplinkPort", client)
            self.assertIn("radioProto", client)

    def test_demo_summary_has_wans_and_outages(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("wans", summary)
        wans = summary["wans"]
        self.assertGreaterEqual(len(wans), 2)
        for wan in wans:
            self.assertIn("interface", wan)
            self.assertIn("speedType", wan)
            self.assertIn("ipv4", wan)
            self.assertIn("type", wan)

        self.assertIn("outages", summary)
        outages = summary["outages"]
        self.assertGreaterEqual(len(outages), 1)
        for outage in outages:
            self.assertIn("siteName", outage)
            self.assertIn("timestamp", outage)
            self.assertIn("durationText", outage)

    def test_demo_summary_has_switches_and_poe_ports(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("switches", summary)
        switches = summary["switches"]
        self.assertGreaterEqual(len(switches), 1)
        sw = switches[0]
        self.assertIn("name", sw)
        self.assertIn("mac", sw)
        self.assertIn("totalPower", sw)
        self.assertIn("ports", sw)
        ports = sw["ports"]
        self.assertGreaterEqual(len(ports), 8)
        self.assertTrue(any(p.get("poePower", 0) > 0 for p in ports))

    def test_demo_summary_has_consoles_and_direct_connect(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("consoles", summary)
        consoles = summary["consoles"]
        self.assertGreaterEqual(len(consoles), 3)

        for c in consoles:
            self.assertIn("hostId", c)
            self.assertIn("name", c)
            self.assertIn("model", c)
            self.assertIn("firmwareVersion", c)
            self.assertIn("directConnectDomain", c)
            self.assertTrue(c["directConnectDomain"].endswith(".id.ui.direct"))
            self.assertIn("directConnectUrl", c)
            self.assertTrue(c["directConnectUrl"].startswith("https://"))
            self.assertIn("applications", c)
            apps = c["applications"]
            self.assertGreaterEqual(len(apps), 1)
            for app in apps:
                self.assertIn("id", app)
                self.assertIn("name", app)
                self.assertIn("version", app)
                self.assertIn("directUrl", app)
                self.assertTrue(app["directUrl"].startswith("https://"))


class BarInteractionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")

    def test_bar_extra_mouse_area_exists_and_configured(self) -> None:
        self.assertIn("id: barExtraMouse", self.panel_qml)
        self.assertIn("cursorShape: Qt.PointingHandCursor", self.panel_qml)
        self.assertIn("acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton", self.panel_qml)
        self.assertIn("root.handleBarClick(mouse.button)", self.panel_qml)

    def test_bar_button_uses_handle_bar_click(self) -> None:
        self.assertIn("root.handleBarClick(b)", self.panel_qml)

    def test_go_to_main_page_function_resets_navigation_state(self) -> None:
        self.assertIn("function goToMainPage()", self.panel_qml)
        self.assertIn("root.activeTab = 0", self.panel_qml)
        self.assertIn("root.settingsMode = false", self.panel_qml)
        self.assertIn("root.backToSites()", self.panel_qml)
        self.assertIn("root.closeAnalytics()", self.panel_qml)

    def test_ipc_handler_exposes_bar_interactions(self) -> None:
        self.assertIn("function goToMainPage(): void", self.panel_qml)
        self.assertIn("function handleBarClick(button: int): void", self.panel_qml)
        self.assertIn("activeTab: root.activeTab", self.panel_qml)
        self.assertIn("inSite: root.inSite", self.panel_qml)


class ConsoleDirectConnectIntegrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.analytics_qml = (ROOT / "windows" / "AnalyticsWindow.qml").read_text(encoding="utf-8")

    def test_panel_supports_analytics_tab_4(self) -> None:
        self.assertIn("Math.min(4, tabIndex)", self.panel_qml)

    def test_panel_has_direct_connect_button_and_banner(self) -> None:
        self.assertIn("id: directConnectSiteBtn", self.panel_qml)
        self.assertIn("id: directConnectBanner", self.panel_qml)
        self.assertIn("function getSiteConsole(hostId)", self.panel_qml)

    def test_analytics_window_has_tab_4_unifi_os(self) -> None:
        self.assertIn("UniFi OS & Direct Connect", self.analytics_qml)
        self.assertIn("property var fleetConsoles:", self.analytics_qml)
        self.assertIn("function copyToClipboard(text, label)", self.analytics_qml)
        self.assertIn("function openExternalUrl(url)", self.analytics_qml)
        self.assertIn("id: tab4View", self.analytics_qml)


class UiDimensionsAndDensityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.statblock_qml = (ROOT / "StatBlock.qml").read_text(encoding="utf-8")
        self.device_view_qml = (ROOT / "DeviceInventoryView.qml").read_text(encoding="utf-8")

    def test_panel_width_matches_agent_hub(self) -> None:
        self.assertIn('setting("panelWidth", 450)', self.panel_qml)

    def test_panel_content_height_matches_dense_profile(self) -> None:
        self.assertIn("Math.min(Style.space(720), content.implicitHeight)", self.panel_qml)

    def test_tab_nav_matches_agent_hub_density(self) -> None:
        self.assertIn("height: Style.space(28)", self.panel_qml)

    def test_statblock_dimensions_match_agent_hub(self) -> None:
        self.assertIn("implicitHeight: Style.space(46)", self.statblock_qml)
        self.assertIn("font.pixelSize: 13", self.statblock_qml)

    def test_overview_globe_is_full_width_with_in_view_roster(self) -> None:
        self.assertIn("id: globeContainer", self.panel_qml)
        self.assertIn("height: Style.space(175)", self.panel_qml)
        self.assertIn("IN VIEW", self.panel_qml)

    def test_site_roster_has_compact_action_cluster(self) -> None:
        self.assertIn("id: siteCardSurface", self.panel_qml)
        self.assertIn("id: directSiteMouse", self.panel_qml)
        self.assertIn("id: sshBtnText", self.panel_qml)
        self.assertIn("id: pingBtnText", self.panel_qml)

    def test_device_inventory_uses_flickable_filter_bar(self) -> None:
        self.assertIn("id: catPillsRow", self.device_view_qml)


if __name__ == "__main__":
    unittest.main()

