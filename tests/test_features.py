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

    def test_analytics_window_matches_agent_hub_window_size(self) -> None:
        self.assertIn("minimumSize: Qt.size(860, 580)", self.analytics_qml)
        self.assertIn("implicitWidth: 1080", self.analytics_qml)
        self.assertIn("implicitHeight: 740", self.analytics_qml)
        self.assertIn('title: "UniFi SiteThread — Fleet Analytics & Telemetry"', self.analytics_qml)

    def test_switch_ports_tab_has_searchable_site_and_switch_dropdowns(self) -> None:
        self.assertIn("property string selectedSwitchSite: \"all\"", self.analytics_qml)
        self.assertIn("property string selectedSwitchMac: \"\"", self.analytics_qml)
        self.assertIn("readonly property var switchSiteOptions:", self.analytics_qml)
        self.assertIn("readonly property var switchesForSelectedSite:", self.analytics_qml)
        self.assertIn("readonly property var switchOptionsForSelectedSite:", self.analytics_qml)
        self.assertIn("id: switchSiteDropdown", self.analytics_qml)
        self.assertIn("id: switchPickerDropdown", self.analytics_qml)
        self.assertIn('background: root.isLightTheme ? "#ffffff" : "#1e1e2e"', self.analytics_qml)
        self.assertIn('popupBorder: root.accent', self.analytics_qml)

    def test_switch_ports_tab_has_dense_port_matrix_layout(self) -> None:
        self.assertIn("id: portGrid", self.analytics_qml)
        self.assertIn("columns: 2", self.analytics_qml)
        self.assertIn("rowSpacing: Style.space(2)", self.analytics_qml)
        self.assertIn("height: Style.space(20)", self.analytics_qml)
        self.assertIn("height: Style.space(25)", self.analytics_qml)
        self.assertIn("Layout.preferredWidth: Style.space(32)", self.analytics_qml)
        self.assertIn("Layout.preferredHeight: Style.space(18)", self.analytics_qml)
        self.assertIn("Layout.preferredWidth: Style.space(48)", self.analytics_qml)

    def test_switch_ports_tab_cycle_button_has_tooltip(self) -> None:
        self.assertIn("visible: cycleBtnMouse.containsMouse && (modelData.poeMode !== \"off\" || modelData.poePower > 0)", self.analytics_qml)
        self.assertIn('text: "Power cycle PoE on Port " + modelData.portIdx', self.analytics_qml)

    def test_switch_ports_tab_has_chassis_jack_visualizer(self) -> None:
        self.assertIn("id: jackRowLayout", self.analytics_qml)
        self.assertIn("Physical RJ45 Faceplate Port Visualizer", self.analytics_qml)


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


class GlobeSdwanFeatureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.globe_qml = (ROOT / "Globe.qml").read_text(encoding="utf-8")
        self.globe_model_js = (ROOT / "GlobeModel.js").read_text(encoding="utf-8")
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")

    def test_globe_qml_exposes_connections_and_traffic_properties(self) -> None:
        self.assertIn("property var connections: []", self.globe_qml)
        self.assertIn("property var sdwan: null", self.globe_qml)
        self.assertIn("property bool animateTraffic: true", self.globe_qml)
        self.assertIn("property real flowProgress: 0.0", self.globe_qml)
        self.assertIn("property var preparedConnections: []", self.globe_qml)

    def test_globe_qml_implements_arc_rendering_and_traffic_pulses(self) -> None:
        self.assertIn("function prepareConnectionGeometry()", self.globe_qml)
        self.assertIn("function paintConnections(", self.globe_qml)
        self.assertIn("function drawTrafficPulse(", self.globe_qml)
        self.assertIn("id: flowAnimation", self.globe_qml)

    def test_panel_binds_connections_and_traffic_to_globe(self) -> None:
        self.assertIn("id: fleetGlobe", self.panel_qml)
        self.assertIn("connections: (root.data && root.data.sdwan && root.data.sdwan.connections) ? root.data.sdwan.connections : []", self.panel_qml)
        self.assertIn("sdwan: root.data ? root.data.sdwan : null", self.panel_qml)
        self.assertIn("animateTraffic: root.opened && root.activeTab === 0", self.panel_qml)

    def test_globe_model_has_spherical_arc_and_color_math(self) -> None:
        self.assertIn("function latLngToVector(", self.globe_model_js)
        self.assertIn("function angularDistance(", self.globe_model_js)
        self.assertIn("function interpolateArc(", self.globe_model_js)
        self.assertIn("function generateArcWaypoints(", self.globe_model_js)
        self.assertIn("function latencyColor(", self.globe_model_js)
        self.assertIn("function findSite(", self.globe_model_js)

    def test_demo_summary_sdwan_has_multi_site_connections_and_ping(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("sdwan", summary)
        sdwan = summary["sdwan"]
        connections = sdwan.get("connections", [])
        self.assertGreaterEqual(len(connections), 2)

        pings = [c.get("ping", 0) for c in connections]
        self.assertTrue(any(p < 35 for p in pings))  # healthy/fast (<35ms)
        self.assertTrue(any(p >= 35 for p in pings))  # moderate/backup (>=35ms)

        for conn in connections:
            self.assertIn("siteA", conn)
            self.assertIn("siteB", conn)
            self.assertIn("ping", conn)
            self.assertIn("connected", conn)


class GlobeZoomFeatureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.globe_qml = (ROOT / "Globe.qml").read_text(encoding="utf-8")
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")

    def test_globe_scale_range_allows_deep_zoom(self) -> None:
        self.assertIn("property real maximumScale: 160.0", self.globe_qml)
        self.assertIn("property real minimumScale: 0.5", self.globe_qml)

    def test_globe_exposes_zoom_methods(self) -> None:
        self.assertIn("function zoomIn()", self.globe_qml)
        self.assertIn("function zoomOut()", self.globe_qml)
        self.assertIn("function resetZoom()", self.globe_qml)

    def test_globe_mouse_area_has_wheel_and_double_click_zoom(self) -> None:
        self.assertIn("onWheel: function(wheel)", self.globe_qml)
        self.assertIn("onDoubleClicked: function(mouse)", self.globe_qml)
        self.assertIn("root.zoomIn()", self.globe_qml)

    def test_panel_has_zoom_buttons_and_ipc_methods(self) -> None:
        self.assertIn("id: zoomInMouse", self.panel_qml)
        self.assertIn("id: zoomOutMouse", self.panel_qml)
        self.assertIn("function zoomIn(): void", self.panel_qml)
        self.assertIn("function zoomOut(): void", self.panel_qml)
        self.assertIn("function setGlobeScale(scale: real): void", self.panel_qml)
        self.assertIn("function globeScaleValue(): real", self.panel_qml)

    def test_globe_drag_sensitivity_is_fast(self) -> None:
        self.assertIn("property real longitudeSensitivity: 0.65", self.globe_qml)
        self.assertIn("property real latitudeSensitivity: 0.55", self.globe_qml)


class SiteCachingAndPrefetchTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")

    def test_site_cache_path_generation(self) -> None:
        path = SITE_THREAD.site_cache_path("console:123", "site/home")
        self.assertTrue(path.name.startswith("site_console_123_site_home"))
        self.assertTrue(path.name.endswith(".json"))

    def test_save_and_read_site_cache(self) -> None:
        test_payload = {
            "ok": True,
            "connected": True,
            "siteId": "test-site",
            "hostId": "test-host",
            "network": {"deviceCount": 5},
        }
        SITE_THREAD.save_site_cache("test-host", "test-site", test_payload)

        cached = SITE_THREAD.read_site_cache("test-host", "test-site")
        self.assertIsNotNone(cached)
        self.assertTrue(cached.get("_cached"))
        self.assertIn("cachedAt", cached)
        self.assertEqual(cached.get("siteId"), "test-site")
        self.assertEqual(cached.get("network", {}).get("deviceCount"), 5)

    def test_read_site_cache_ttl_expiration(self) -> None:
        test_payload = {"ok": True, "siteId": "exp-site"}
        SITE_THREAD.save_site_cache("exp-host", "exp-site", test_payload)

        # Fresh cache (< 600s) is valid
        self.assertIsNotNone(SITE_THREAD.read_site_cache("exp-host", "exp-site", max_age=600))
        # Zero max_age simulates expired cache
        self.assertIsNone(SITE_THREAD.read_site_cache("exp-host", "exp-site", max_age=0))

    def test_demo_site_generation(self) -> None:
        site = SITE_THREAD.demo_site("console-home", "home")
        self.assertTrue(site.get("ok"))
        self.assertTrue(site.get("demo"))
        self.assertEqual(site.get("siteId"), "home")
        self.assertIn("network", site)
        self.assertIn("protect", site)
        self.assertIn("console", site)
        self.assertGreaterEqual(len(site["network"]["devices"]), 1)

    def test_panel_has_prefetch_timer_and_cached_proc(self) -> None:
        self.assertIn("id: prefetchTimer", self.panel_qml)
        self.assertIn("interval: 600000", self.panel_qml)
        self.assertIn("root.prefetchSites()", self.panel_qml)
        self.assertIn("id: prefetchProc", self.panel_qml)
        self.assertIn("prefetch-sites", self.panel_qml)

        self.assertIn("id: siteCachedProc", self.panel_qml)
        self.assertIn("--cached-only", self.panel_qml)
        self.assertIn("--live", self.panel_qml)
        self.assertIn("property bool siteLiveRefreshing: false", self.panel_qml)


class MergedSitesAndDevicesTabTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")

    def test_top_navigation_has_four_tabs_without_standalone_devices(self) -> None:
        self.assertIn('{ id: 0, label: "Overview"', self.panel_qml)
        self.assertIn('{ id: 1, label: root.cloudMode ? "Sites', self.panel_qml)
        self.assertIn('{ id: 2, label: "Issues (', self.panel_qml)
        self.assertIn('{ id: 3, label: "Protect (', self.panel_qml)
        self.assertNotIn('{ id: 2, label: "Devices', self.panel_qml)

    def test_sites_tab_has_subview_toggle_and_merges_device_inventory(self) -> None:
        self.assertIn('property string sitesSubView: "sites"', self.panel_qml)
        self.assertIn('id: sitesSubPillText', self.panel_qml)
        self.assertIn('id: devSubPillText', self.panel_qml)
        self.assertIn('visible: root.sitesSubView === "sites"', self.panel_qml)
        self.assertIn('visible: root.sitesSubView === "devices"', self.panel_qml)
        self.assertIn('DeviceInventoryView {', self.panel_qml)

    def test_overview_statblocks_route_to_merged_sites_and_devices(self) -> None:
        self.assertIn('root.activeTab = 1; root.sitesSubView = "sites";', self.panel_qml)
        self.assertIn('root.activeTab = 1; root.sitesSubView = "devices";', self.panel_qml)

    def test_ipc_supports_four_tabs_and_sites_subview(self) -> None:
        self.assertIn("root.activeTab = Math.max(0, Math.min(3, index))", self.panel_qml)
        self.assertIn("function setSitesSubView(view: string): void", self.panel_qml)
        self.assertIn("sitesSubView: root.sitesSubView,", self.panel_qml)


class ActionButtonSizingAndOverlapTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.device_view_qml = (ROOT / "DeviceInventoryView.qml").read_text(encoding="utf-8")
        self.topology_qml = (ROOT / "TopologyTreeView.qml").read_text(encoding="utf-8")
        self.analytics_qml = (ROOT / "windows" / "AnalyticsWindow.qml").read_text(encoding="utf-8")

    def test_sdwan_banner_action_button_and_row_layout(self) -> None:
        self.assertIn("id: sdwanRow", self.panel_qml)
        self.assertIn("id: sdwanBtnRow", self.panel_qml)
        self.assertIn("implicitWidth: sdwanBtnRow.implicitWidth + Style.space(14)", self.panel_qml)

    def test_device_inventory_action_buttons_sizing_and_no_overlap(self) -> None:
        self.assertIn("implicitWidth: sshBtnRow.implicitWidth + Style.space(12)", self.device_view_qml)
        self.assertIn("implicitWidth: pingBtnRow.implicitWidth + Style.space(12)", self.device_view_qml)
        self.assertIn("implicitWidth: webBtnRow.implicitWidth + Style.space(12)", self.device_view_qml)
        self.assertIn('text: "IP: "', self.device_view_qml)
        self.assertIn("elide: Text.ElideRight", self.device_view_qml)

    def test_site_cards_action_buttons_padding(self) -> None:
        self.assertIn("implicitWidth: sshBtnText.implicitWidth + Style.space(14)", self.panel_qml)
        self.assertIn("implicitWidth: pingBtnText.implicitWidth + Style.space(14)", self.panel_qml)

    def test_topology_tree_action_buttons_sizing(self) -> None:
        self.assertIn("implicitWidth: gwSshRow.implicitWidth + Style.space(12)", self.topology_qml)
        self.assertIn("implicitWidth: t1ActionRow.implicitWidth + Style.space(10)", self.topology_qml)


class ActionButtonToolTipTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.device_view_qml = (ROOT / "DeviceInventoryView.qml").read_text(encoding="utf-8")
        self.topology_qml = (ROOT / "TopologyTreeView.qml").read_text(encoding="utf-8")

    def test_sdwan_banner_mesh_button_has_tooltip(self) -> None:
        self.assertIn("id: sdwanBtnMouse", self.panel_qml)
        self.assertIn("visible: sdwanBtnMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Open SD-WAN Site Magic mesh topology and analytics"', self.panel_qml)

    def test_subview_toggle_pills_have_tooltips(self) -> None:
        self.assertIn("visible: subSitesMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "View fleet sites and SD-WAN mesh connections"', self.panel_qml)
        self.assertIn("visible: subDevMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "View all network hardware devices across fleet"', self.panel_qml)

    def test_site_cards_actions_have_tooltips(self) -> None:
        self.assertIn("visible: directSiteMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Direct P2P connect to UniFi OS console"', self.panel_qml)
        self.assertIn("visible: sshMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Open SSH terminal to gateway (" + siteCardSurface.modelData.gatewayIp + ")"', self.panel_qml)
        self.assertIn("visible: pingMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Ping gateway (" + siteCardSurface.modelData.gatewayIp + ")"', self.panel_qml)

    def test_insite_direct_connect_buttons_have_tooltips(self) -> None:
        self.assertIn("visible: directBtnMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Launch direct P2P console connection"', self.panel_qml)
        self.assertIn("visible: directHubMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Open UniFi OS applications hub"', self.panel_qml)

    def test_device_inventory_buttons_have_tooltips(self) -> None:
        self.assertIn("visible: catMouse.containsMouse", self.device_view_qml)
        self.assertIn("visible: sshMouse.containsMouse", self.device_view_qml)
        self.assertIn('text: "Open SSH terminal session (" + modelData.ip + ")"', self.device_view_qml)
        self.assertIn("visible: pingMouse.containsMouse", self.device_view_qml)
        self.assertIn('text: "Send ICMP ping to " + modelData.ip', self.device_view_qml)
        self.assertIn("visible: webMouse.containsMouse", self.device_view_qml)
        self.assertIn('text: "Open device web management page (https://" + modelData.ip + ")"', self.device_view_qml)

    def test_topology_tree_buttons_have_tooltips(self) -> None:
        self.assertIn("visible: gwSshMouse.containsMouse", self.topology_qml)
        self.assertIn('text: "Open SSH terminal to gateway (" + (gwCard.gw ? gwCard.gw.ip : "") + ")"', self.topology_qml)
        self.assertIn("visible: t1ActionMouse.containsMouse", self.topology_qml)
        self.assertIn('text: root.isSwitch(modelData) ? ("Open SSH session to switch (" + modelData.ip + ")") : ("Ping device (" + modelData.ip + ")")', self.topology_qml)
        self.assertIn("visible: t2PingMouse.containsMouse", self.topology_qml)
        self.assertIn('text: "Ping device (" + modelData.ip + ")"', self.topology_qml)


class AttentionSectionLayoutTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")

    def test_attention_required_card_uses_row_layout_with_clean_fit(self) -> None:
        self.assertIn("id: activeIssueRow", self.panel_qml)
        import re
        self.assertTrue(re.search(r"RowLayout\s*\{\s*id:\s*activeIssueRow", self.panel_qml))
        self.assertIn("Layout.fillWidth: true", self.panel_qml)
        self.assertIn("Layout.minimumWidth: 0", self.panel_qml)
        self.assertIn("elide: Text.ElideRight", self.panel_qml)

    def test_active_pill_has_explicit_preferred_sizing(self) -> None:
        self.assertIn("id: activeIssuePill", self.panel_qml)
        self.assertIn("implicitWidth: activePillLabel.implicitWidth + Style.space(12)", self.panel_qml)
        self.assertIn("Layout.preferredWidth: activePillLabel.implicitWidth + Style.space(12)", self.panel_qml)
        self.assertIn('text: "ACTIVE"', self.panel_qml)

    def test_active_issue_card_has_hover_and_navigation(self) -> None:
        self.assertIn("id: activeIssueMouse", self.panel_qml)
        self.assertIn("color: activeIssueMouse.containsMouse ? root.cardHover : root.card", self.panel_qml)
        self.assertIn("onClicked: root.activeTab = 2", self.panel_qml)


class WiFiAndRfSpectrumTests(unittest.TestCase):
    def setUp(self) -> None:
        self.analytics_qml = (ROOT / "windows" / "AnalyticsWindow.qml").read_text(encoding="utf-8")

    def test_demo_summary_has_wlans_and_spectrum(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("wlans", summary)
        self.assertIn("spectrum", summary)
        wlans = summary["wlans"]
        spectrum = summary["spectrum"]
        self.assertGreaterEqual(len(wlans), 3)
        for wlan in wlans:
            self.assertIn("id", wlan)
            self.assertIn("name", wlan)
            self.assertIn("security", wlan)
            self.assertIn("bands", wlan)
            self.assertIn("vlan", wlan)
            self.assertIn("clientCount", wlan)
            self.assertIn("passphrase", wlan)
            self.assertIn("qrCode", wlan)
            self.assertTrue(wlan["qrCode"].startswith("WIFI:S:"))

        self.assertIn("bands", spectrum)
        bands_list = spectrum["bands"]
        self.assertGreaterEqual(len(bands_list), 3)
        bands = [s.get("band") for s in bands_list]
        self.assertIn("2.4 GHz", bands)
        self.assertIn("5 GHz", bands)
        self.assertIn("6 GHz", bands)
        for band_info in bands_list:
            self.assertIn("utilization", band_info)
            self.assertIn("noiseFloor", band_info)
            self.assertIn("interference", band_info)
            self.assertIn("channels", band_info)

    def test_analytics_window_wifi_rf_spectrum_tab_and_state(self) -> None:
        self.assertIn('"WiFi & RF Spectrum ("', self.analytics_qml)
        self.assertIn("id: tab5View", self.analytics_qml)
        self.assertIn("property var fleetWlans:", self.analytics_qml)
        self.assertIn("property var fleetSpectrum:", self.analytics_qml)
        self.assertIn("property string wlanSearch:", self.analytics_qml)
        self.assertIn("property string wlanSiteFilter:", self.analytics_qml)
        self.assertIn("property var selectedWlanForQr:", self.analytics_qml)
        self.assertIn("property bool showQrModal:", self.analytics_qml)
        self.assertIn("id: qrCanvas", self.analytics_qml)
        self.assertIn("WiFi password", self.analytics_qml)


class LinuxDesktopIntegrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.settings_qml = (ROOT / "SettingsView.qml").read_text(encoding="utf-8")

    def test_panel_has_notifications_and_settings(self) -> None:
        self.assertIn("property bool enableNotifications:", self.panel_qml)
        self.assertIn("function sendDesktopNotification(title, message, urgency)", self.panel_qml)
        self.assertIn("function testNotification()", self.panel_qml)
        self.assertIn('Quickshell.execDetached(["notify-send", "--app-name=UniFi SiteThread"', self.panel_qml)
        self.assertIn("function notify(title: string, message: string, urgency: string): void", self.panel_qml)

    def test_panel_updates_badge_mode(self) -> None:
        self.assertIn('else if (root.badgeMode === "updates")', self.panel_qml)
        self.assertIn("root.data.network.updateCount", self.panel_qml)

    def test_settings_view_has_notification_toggle_and_test_button(self) -> None:
        self.assertIn("signal testNotifyRequested()", self.settings_qml)
        self.assertIn("LINUX DESKTOP & NOTIFICATIONS", self.settings_qml)
        self.assertIn("Notifications: Enabled", self.settings_qml)
        self.assertIn("Send Test Notification", self.settings_qml)
        self.assertIn('"updates"', self.settings_qml)

    def test_site_thread_notify_command(self) -> None:
        import io
        from contextlib import redirect_stdout
        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_notify("Test Alert", "Unit test alert body", "normal")
            self.assertEqual(cm.exception.code, 0)
        res = json.loads(out.getvalue())
        self.assertTrue(res.get("ok"))
        self.assertIn("Desktop notification sent", res.get("message", ""))


class FirmwareLifecycleManagementTests(unittest.TestCase):
    def setUp(self) -> None:
        self.analytics_qml = (ROOT / "windows" / "AnalyticsWindow.qml").read_text(encoding="utf-8")

    def test_demo_summary_has_firmware_updates_and_backups(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("firmwareUpdates", summary)
        self.assertIn("backups", summary)
        updates = summary["firmwareUpdates"]
        backups = summary["backups"]
        self.assertGreaterEqual(len(updates), 2)
        for u in updates:
            self.assertIn("deviceId", u)
            self.assertIn("name", u)
            self.assertIn("model", u)
            self.assertIn("currentVersion", u)
            self.assertIn("targetVersion", u)
            self.assertIn("severity", u)
            self.assertIn("releaseNotes", u)

        self.assertGreaterEqual(len(backups), 2)
        for b in backups:
            self.assertIn("siteName", b)
            self.assertIn("hostId", b)
            self.assertIn("lastBackup", b)
            self.assertIn("status", b)

    def test_bin_site_thread_upgrade_and_backup_commands(self) -> None:
        import io
        from contextlib import redirect_stdout

        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_upgrade_device("console-1", "00:11:22:33:44:55")
            self.assertEqual(cm.exception.code, 0)
        res = json.loads(out.getvalue())
        self.assertTrue(res.get("ok"))
        self.assertIn("Firmware upgrade initiated", res.get("message", ""))

        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_upgrade_all("all")
            self.assertEqual(cm.exception.code, 0)
        res = json.loads(out.getvalue())
        self.assertTrue(res.get("ok"))
        self.assertIn("Fleet firmware upgrade batch initiated", res.get("message", ""))

        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_backup("console-1")
            self.assertEqual(cm.exception.code, 0)
        res = json.loads(out.getvalue())
        self.assertTrue(res.get("ok"))
        self.assertIn("backup created successfully", res.get("message", ""))

    def test_analytics_window_firmware_tab_and_processes(self) -> None:
        self.assertIn('"Firmware & Backups ("', self.analytics_qml)
        self.assertIn("id: tab6View", self.analytics_qml)
        self.assertIn("property var fleetUpdates:", self.analytics_qml)
        self.assertIn("property var fleetBackups:", self.analytics_qml)
        self.assertIn("id: upgradeDevProc", self.analytics_qml)
        self.assertIn("id: upgradeAllProc", self.analytics_qml)
        self.assertIn("id: backupProc", self.analytics_qml)
        self.assertIn("property bool bulkUpdateConfirm:", self.analytics_qml)
        self.assertIn("Update All Devices", self.analytics_qml)
        self.assertIn("Create Backup Now", self.analytics_qml)


if __name__ == "__main__":
    unittest.main()




