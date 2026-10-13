# UniFi SiteThread for Omarchy (BoeyCorp Fork)

UniFi SiteThread is a high-density, NOC-style UniFi Network and Protect operations cockpit for the Omarchy top bar. It aggregates every site owned by (or shared with) your UI Account into one popup and a seven-tab fleet analytics window, using only live data from the UniFi APIs.

> Screenshots below have names, IP/MAC addresses, SSIDs, passphrases and other identifying data blurred.

![UniFi SiteThread](preview.png)

![Status bar widget](docs/screenshots/status_bar_widget.png)

## Contents

- [Visual tour](#visual-tour)
- [Features](#features)
- [Security model](#security-model)
- [Install](#install)
- [Dependencies](#dependencies)
- [Connect](#connect)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [IPC reference](#ipc-reference)
- [Update / Remove](#update--remove)
- [Development](#development)
- [Roadmap](#roadmap)
- [License](#license)

## Visual tour

### Bar popup

![Overview](docs/screenshots/panel_overview.png)

**Overview (Cockpit)** – Fleet health at a glance, global topology, and urgent incident monitoring.
- **Fleet KPI Cards**: High-level status counters summarizing total online sites, WAN uplink stability, total hardware counts (highlighting offline units in urgent red), and client load broken down by Wi-Fi and wired connections.
- **Interactive 3D Vector Globe**: A real-time orthographic vector wireframe globe mapping site locations with geographic pins and interconnecting Site Magic SD-WAN links. Supports mouse drag rotation, scroll zooming, and continuous auto-rotation.
- **In-View Site Cards**: Dynamic site cards that orient with the globe camera, surfacing local throughput, client totals, and direct click-to-focus controls for sites currently visible.
- **Priority Attention Banner**: An alert strip highlighting active hardware and connectivity disruptions, detailing affected devices, host locations, and downtime duration.
- **Quick Action Header**: Instant shortcuts to launch the standalone 7-tab Fleet Analytics window, toggle color schemes, trigger manual background syncs, and open preferences.

![Sites](docs/screenshots/panel_sites.png)

**Sites** – Managed installations, site-level network telemetry, and direct operator actions.
- **Fleet Feature Cards**: Pinned summary modules providing instant insight into cross-site services:
  - **Site Magic SD-WAN**: Reports active mesh connectivity across gateways with a quick link to the SD-WAN topology view.
  - **WiFi & RF Spectrum Health**: Fleet SSID counts and real-time tri-band channel utilization across 2.4 GHz, 5 GHz, and 6 GHz spectrums.
  - **Fleet Firmware & Backups**: Upgrade readiness indicators and cloud backup freshness across all consoles.
- **Per-Site Health Rows**: Detailed cards for each managed site indicating gateway model badges (e.g. UCG Max, UCG Ultra), online status, device counts, client distribution, and WAN uptime percentages.
- **Direct Operator Shortcuts**: 1-click launcher buttons to open the site's UniFi OS console web interface, open an SSH terminal session to the gateway, or launch an active ICMP ping latency monitor.

![Devices](docs/screenshots/panel_devices.png)

**Devices** – Hardware inventory across the entire fleet with operational status and diagnostics.
- **Category Filtering**: Segment hardware instantly across Gateways, Switches, Access Points, and UniFi Protect Storage / NVRs.
- **Operational Status Indicators**: Color-coded connectivity badges and live uptime tracking.
- **Network Telemetry**: Surfaces assigned IP addresses, hardware MAC addresses, and active uplink topology for every device in the fleet.
- **Integrated Terminal Actions**: Action buttons next to each device allowing operators to launch 1-click SSH terminal sessions, start ICMP ping diagnostic tests, or open local web admin portals without leaving the desktop.
- **Fault Highlighting**: Unreachable or disconnected devices are immediately highlighted with prominent alert indicators.

![Issues](docs/screenshots/panel_issues.png)

**Issues** – Centralized fleet incident logging and historical tracking for network disruptions and hardware failures.
- **Real-Time Outage Tracking**: Logs and surfaces critical incidents such as gateway WAN drops, packet loss spikes, and unreachable access points or switches.
- **Lifecycle Filters**: Filter between `All`, `Active` (unresolved ongoing issues), and `Resolved` historical incidents, with a button to purge historical logs.
- **Downtime Duration**: Displays precise elapsed downtime duration (e.g. "Down for 23h 24m") and device context to distinguish transient blips from prolonged outages.

![Settings](docs/screenshots/panel_settings.png)

**Settings** – Comprehensive customization for the Omarchy top bar widget, diagnostic tools, and desktop integration.
- **Bar Badge Mode**: Select what telemetry appears on the top bar next to the UniFi icon: `Alerts Count`, `Fleet Clients`, `Sites Ratio`, `Updates`, or disabled (`Off`).
- **Multi-Dot Site Status**: Optionally displays individual color-coded status indicator dots for each site directly in the top bar.
- **3D Globe Behavior**: Toggle continuous background auto-rotation on the Overview tab or restrict globe interaction to manual mouse dragging.
- **Refresh Interval**: Set background telemetry polling frequency (`15s`, `30s`, `60s`, `2m`, or `5m`).
- **Preferred Terminal**: Configure which installed Linux terminal emulator (`Default`, `Ghostty`, `Kitty`, `Foot`, `Alacritty`) handles 1-click SSH and ping shortcuts.
- **Desktop Notifications**: Enable native `notify-send` desktop alert banners when site outages or WAN failovers occur, with an interactive test notification trigger.
- **Maintenance Actions**: Quick options to clear stored incident history or cleanly disconnect the stored API key from the desktop Secret Service keyring.

### Fleet Analytics & Telemetry window

**1. Overview & Mesh** – 24-hour WAN throughput, client density by band, Site Magic SD-WAN, managed site matrix.

![Overview & Mesh](docs/screenshots/analytics_overview.png)

**2. Client Telemetry** – searchable wired/WiFi client roster with uplink, signal, protocol, traffic and uptime.

![Client Telemetry](docs/screenshots/analytics_clients.png)

**3. WAN & Outages** – gateway WAN interfaces, link speed, ISP peering/SLA and historical outage timeline.

![WAN & Outages](docs/screenshots/analytics_wan.png)

**4. Switch Ports & PoE** – per-switch port strip, PoE budget, two-column port matrix, remote PoE power cycling.

![Switch Ports & PoE](docs/screenshots/analytics_switches.png)

**5. UniFi OS & Direct Connect** – console cards, `*.id.ui.direct` WebRTC P2P access and installed applications.

![UniFi OS & Direct Connect](docs/screenshots/analytics_consoles.png)

**6. WiFi & RF Spectrum** – WLAN inventory, QR onboarding, per-band congestion, AP radio assignments.

![WiFi & RF Spectrum](docs/screenshots/analytics_wifi.png)

**7. Firmware & Backups** – pending firmware updates, batch deployment, cloud configuration backups.

![Firmware & Backups](docs/screenshots/analytics_firmware.png)

## Features

### Bar widget
- Health-aware UniFi icon with optional multi-dot per-site status indicators.
- Configurable badge: **Alerts Count**, **Fleet Clients**, **Sites Ratio**, **Updates**, or **Off**.
- Adapts to the active Omarchy theme and light/dark mode through dynamic palette variables.

### Overview cockpit
- Header with status pill, last-refresh age, spinner and refresh glow bar; buttons for analytics, settings and refresh.
- Four KPI tiles: Sites, Gateways & Multi-WAN, Network Devices, Clients (Wi-Fi vs. wired).
- **Interactive 3D vector globe** (Natural Earth geometry via [OmaGlobe](https://github.com/zamak/omaglobe)): fast drag-to-rotate, scroll zoom, focus/auto-rotate controls, graticule, atmospheric shading, glowing status beacons and click-to-open site drilldown. SD-WAN links are drawn between sites.
- **Attention Required** list of active incidents.

### Sites and Devices
- Fleet-wide site list with gateway model, ISP, WAN uptime, client counts, and 1-click **SSH** / **Ping** / **Web** actions (opens your preferred terminal).
- Device inventory with filters for Gateways, Switches, APs and Storage.
- Per-site live Network view and, where installed, a Protect tab with cameras and live snapshot refresh.

### Issues
- Persistent issue history (`~/.config/site-thread/issues.json`) with **All / Active / Resolved** filters, resolution timestamps and durations, plus **Clear**.

### Analytics window (7 tabs)
Opened from the header button or `a`/`m`. Includes a refresh button next to close, site filtering (click a site to filter throughput), and consistent evenly-spaced tab buttons. Tab labels show live counts. All data comes from the UniFi API; nothing is placeholder.

### WiFi & RF health
- WLAN inventory with security type, VLAN, WiFi generation, hidden/guest flags and client counts.
- Copy password and **Share QR** onboarding.
- 2.4 / 5 / 6 GHz utilisation, interference, noise and channel distribution; Auto-RF status.
- Access point radio assignments and client load.

### Firmware & lifecycle
- Pending updates by device class, release channel, maintenance window, batch deployment workflow with an empty state when everything is current.
- Automated cloud backup status with **Create Backup Now**.

### Linux desktop & Omarchy integration
- Native desktop notifications (`notify-send`) for site outages and WAN failover, with test button.
- Preferred terminal selection: Default, Ghostty, Kitty, Foot, Alacritty.
- Configurable refresh interval (15s – 5m) and globe auto-rotate.
- Full IPC control for keybindings and scripting (see below).

## Security model

UniFi SiteThread does not ask for or store your UniFi password. Sign-in happens in
your normal browser at `unifi.ui.com`; the plugin uses the official Site Manager
API-key flow. The key travels from the masked field to the local helper over
standard input, is stored by `secret-tool`, and never appears in Omarchy's
`shell.json`, process arguments, or logs.

Cloud requests use normal public TLS verification against `api.ui.com`. In the
optional local-console mode, the connection screen displays the console's
SHA-256 certificate fingerprint and every request pins its public key.

All remote strings are rendered as plain text (defense in depth against markup injection).

Create a dedicated local UniFi user with the minimum permissions needed for
Network viewing and Protect viewing, then create an API key while signed in as
that user.

## Install

```bash
omarchy plugin add https://github.com/larrywcox/omarchy-site-thread.git --enable
```

Local development checkout:

```bash
omarchy plugin add /path/to/site-thread --enable
```

## Dependencies

- `python3`
- `curl`
- `openssl`
- `secret-tool` from `libsecret`, for secure API-key storage
- `wl-paste` from `wl-clipboard`, for the **Paste API key from clipboard** button
- `notify-send` (optional) for desktop notifications

## Connect

1. Click the UniFi SiteThread icon in the bar.
2. Select **Sign in at unifi.ui.com**.
3. In Site Manager, open **Settings → API Keys** and create an API key.
4. Return to UniFi SiteThread, paste the key into the masked field, and select
   **Connect all sites**.

If the usual keyboard shortcut is unavailable inside the bar popup, select
**Paste API key from clipboard** below the masked field. The credential remains
available across logins while your desktop keyring is unlocked.

## Keyboard shortcuts

| Key | Action |
| --- | --- |
| `r` | Refresh |
| `s` | Toggle settings |
| `a` / `m` | Toggle analytics window |
| `w` | Switch tab |
| `Esc` | Close |

## IPC reference

```bash
qs ipc -p /usr/share/omarchy/shell call larrywcox.site-thread <function> [args]
```

| Function | Description |
| --- | --- |
| `open` / `close` / `toggle` | Show, hide or toggle the popup |
| `tab <0-3>` | Open a popup tab (Overview, Sites, Issues, Protect) |
| `openSettings` / `closeSettings` | Settings view |
| `openAnalytics` / `closeAnalytics` / `toggleAnalytics` | Analytics window |
| `openAnalyticsTab <0-6>` | Open a specific analytics tab |
| `filterAnalyticsSite <name>` / `clearAnalyticsSiteFilter` | Site filter |
| `setSitesSubView sites\|devices` | Sites sub-view |
| `rotate <lon>` / `zoomIn` / `zoomOut` / `setGlobeScale <n>` | Globe control |

## Update / Remove

```bash
omarchy plugin update larrywcox.site-thread
omarchy plugin remove larrywcox.site-thread --yes
```

Removing the plugin does not delete the saved API key. To remove it:

```bash
secret-tool clear application site-thread profile default
```

## Development

```bash
python3 -m unittest discover -s tests
```

## Roadmap

- Protect motion-event WebSocket and desktop notifications.
- Event filmstrip and low-latency RTSP video.
- Carefully confirmed client, PTZ, light, siren, relay, and arm-profile actions.
- Side-by-side multi-camera layouts.

Operational actions should use a separate, explicitly privileged credential;
the default monitoring credential should stay read-only.

## License

MIT
