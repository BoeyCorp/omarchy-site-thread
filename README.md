# UniFi SiteThread for Omarchy (BoeyCorp Fork)

UniFi SiteThread is a high-density, NOC-style UniFi Network and Protect operations cockpit for the Omarchy top bar.

Version 0.5.0 enhancements:

- **ASCII Fleet Globe & NOC World Map**: Interactive 3D ASCII orthographic globe and 2D equirectangular fleet map with color-coded status dots (green = online, amber = backup WAN, red = offline), manual/auto rotation, and one-click site drilldowns.
- **Agent Hub-Inspired High-Density Cockpit**: Compact header with status pill, last-refresh age, smooth rotating spinner, and active refresh glow bar. Four top-level metric tiles breakdown Sites, Gateways & Multi-WAN, Network Devices, and Clients (split into Wi-Fi and Wired).
- **Persistent Issue History & Resolution Tracking**: Active incidents plus resolved issues saved across sessions (`~/.config/site-thread/issues.json`). Resolved incidents are clearly distinguished as greyed-out cards with resolution timestamps and duration metrics. Includes filters for `All`, `Active`, and `Resolved`, plus a `Clear History` action.
- **Dynamic Omarchy Theme Reactivity**: Plugin bar icon and popup container automatically adapt to the user's active Omarchy desktop theme and light/dark luminance modes, replacing hardcoded color overrides with dynamic palette variables.
- **Gateway Telemetry & 1-Click SSH**: Displays gateway model (e.g. UCG-Max, UCG-Ultra, UDM-Pro) and LAN IP, with a direct SSH button opening your default terminal via `xdg-terminal-exec`.
- **Health-Aware Bar Icon**: Dynamic offline device and outage counters.
- **Browser-Based UI Account Sign-In**: Masked Site Manager API-key flow saved in desktop Secret Service via `secret-tool`.
- **Multi-Site Fleet Aggregation**: Direct Network and Protect overview across all owned or managed UI consoles.
- **Strict Plaintext QML Rendering**: Defense-in-depth sanitization preventing remote code injection or HTML escaping issues.

## Security model

UniFi SiteThread does not ask for or store your UniFi password. Sign-in happens in
your normal browser at `unifi.ui.com`; the plugin uses the official Site Manager
API-key flow. The key travels from the masked field to the local helper over
standard input, is stored by `secret-tool`, and never appears in Omarchy's
`shell.json`, process arguments, or logs.

Cloud requests use normal public TLS verification against `api.ui.com`. In the
optional local-console mode, the connection screen displays the console's
SHA-256 certificate fingerprint and every request pins its public key.

Create a dedicated local UniFi user with the minimum permissions needed for
Network viewing and Protect viewing, then create an API key while signed in as
that user.

## Install

Install the latest version directly from the public GitHub repository:

```bash
omarchy plugin add https://github.com/larrywcox/omarchy-site-thread.git --enable
```

To install a local development checkout instead:

```bash
omarchy plugin add /path/to/site-thread --enable
```

## Dependencies

UniFi SiteThread needs the following commands:

- `python3`
- `curl`
- `openssl`
- `secret-tool` from `libsecret`, for secure API-key storage
- `wl-paste` from `wl-clipboard`, for the **Paste API key from clipboard** button

Install any missing dependency through your system package manager before
enabling the plugin.

## Update

```bash
omarchy plugin update larrywcox.site-thread
```

## Remove

```bash
omarchy plugin remove larrywcox.site-thread --yes
```

Removing the plugin does not automatically delete its saved API key from the
desktop Secret Service. To remove that credential too, run:

```bash
secret-tool clear application site-thread profile default
```

## Connect

1. Click the UniFi SiteThread icon in the bar.
2. Select **Sign in at unifi.ui.com**.
3. In Site Manager, open **Settings → API Keys** and create an API key.
4. Return to UniFi SiteThread, paste the key into the masked field, and select
   **Connect all sites**.

If the usual keyboard shortcut is unavailable inside the bar popup, select
**Paste API key from clipboard** below the masked field.

Every site owned by or shared with that UI Account is loaded automatically.
The Sites tab keeps the entire fleet visible at once. Selecting a site opens its
live Network view inside UniFi SiteThread. Use **Back** to return to all sites.
When Protect is installed on that console, its Protect tab shows the site's
cameras and refreshes the selected camera while the panel remains open.

The credential remains available across logins while your desktop keyring is
unlocked.

## Roadmap

The backend and UI are deliberately structured for the next layers:

- Protect motion-event WebSocket and desktop notifications.
- Event filmstrip and low-latency RTSP video.
- WAN latency, VPN, Wi-Fi, and switch-port views.
- Carefully confirmed client, PoE, PTZ, light, siren, relay, and arm-profile actions.
- Side-by-side multi-camera layouts.

Operational actions should use a separate, explicitly privileged credential;
the default monitoring credential should stay read-only.

## License

MIT
