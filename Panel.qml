import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "GlobeModel.js" as GlobeModel

Panel {
  id: root
  moduleName: "larrywcox.site-thread"
  ipcTarget: "larrywcox.site-thread"
  manageIpc: false

  readonly property string helper: Qt.resolvedUrl("bin/site-thread").toString().replace(/^file:\/\//, "")
  readonly property color foreground: (bar && bar.barForeground) ? bar.barForeground : ((bar && bar.foreground) ? bar.foreground : (Color.foreground || "#D8DEE9"))
  readonly property color urgent: (bar && bar.urgent) ? bar.urgent : (Color.urgent || "#ff4d5a")
  readonly property color accent: (bar && bar.accent) ? bar.accent : (Color.accent || "#89B4FA")
  readonly property color healthy: "#10b981"
  readonly property color backup: "#f59e0b"

  readonly property bool isLightTheme: {
    var bg = (bar && bar.background) ? bar.background : (Color.background || "#1E1E2E")
    var bgLum = (bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114)
    var fgLum = (foreground.r * 0.299 + foreground.g * 0.587 + foreground.b * 0.114)
    return bgLum > 0.5 || fgLum < 0.5
  }

  readonly property color dim: isLightTheme
    ? Qt.rgba(foreground.r * 0.58 + ((bar && bar.background) ? bar.background.r : 1.0) * 0.42,
              foreground.g * 0.58 + ((bar && bar.background) ? bar.background.g : 1.0) * 0.42,
              foreground.b * 0.58 + ((bar && bar.background) ? bar.background.b : 1.0) * 0.42, 1.0)
    : Qt.darker(foreground, 1.45)
  readonly property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.04 : 0.055)
  readonly property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.08 : 0.085)
  readonly property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.14 : 0.18)
  readonly property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.12 : 0.24)

  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int panelWidth: setting("panelWidth", 780)
  readonly property int refreshSeconds: setting("refreshSeconds", 30)

  property bool autoRotate: false
  property string issueFilter: "all"
  property int refreshAgeSec: 0
  property double lastRefreshMs: Date.now()

  property var data: ({ connected: false })
  property bool loading: false
  property string notice: ""
  property int activeTab: 0
  property string pendingSecret: ""
  property string probeFingerprint: ""
  property bool certificateAccepted: false
  property string selectedCameraId: ""
  property string selectedCameraName: ""
  property string snapshotPath: ""
  property bool confirmDisconnect: false
  property bool localSetup: false
  property bool pasteForLocalConsole: false
  property var selectedSite: null
  property var siteData: ({})
  property bool siteLoading: false
  property int siteTab: 0
  property string overviewSelection: ""
  property var downConfirmations: ({})

  readonly property bool connected: data && data.connected === true
  readonly property bool cloudMode: connected && data.mode === "cloud"
  readonly property bool inSite: selectedSite !== null
  readonly property bool siteProtectInstalled: siteData !== null && siteData.protect !== undefined && siteData.protect.installed === true
  readonly property string severity: connected ? String(data.severity || "healthy") : "disconnected"
  readonly property int siteDownCount: connected && cloudMode ? countSitesWithStatus("down") : 0
  readonly property int siteBackupCount: connected && cloudMode ? countSitesWithStatus("backup") : 0
  readonly property string barSeverity: cloudMode
    ? (siteDownCount > 0 ? "critical" : (siteBackupCount > 0 ? "warning" : "healthy"))
    : severity
  readonly property var issuesList: data && data.issues ? data.issues : []
  readonly property int activeIssuesCount: {
    var count = 0
    for (var i = 0; i < issuesList.length; i++) {
      if (issuesList[i].active === true) count++
    }
    return count
  }
  readonly property int alertCount: connected
    ? (cloudMode
      ? Math.max(siteDownCount + siteBackupCount, activeIssuesCount)
      : Number((data.network && data.network.offlineCount || 0) + (data.protect && data.protect.offlineCount || 0) + activeIssuesCount))
    : 0

  function countSitesWithStatus(status) {
    var count = 0
    var sites = data && data.sites ? data.sites : []
    for (var index = 0; index < sites.length; index++) {
      if (String(sites[index].status || "up") === status) count++
    }
    return count
  }

  function countPendingSites() {
    var count = 0
    var sites = data && data.sites ? data.sites : []
    for (var index = 0; index < sites.length; index++) {
      if (sites[index].pendingDown === true) count++
    }
    return count
  }

  function stabilizeCloudSummary(parsed) {
    if (!parsed || parsed.ok !== true || parsed.mode !== "cloud" || !parsed.sites) return parsed
    var nextConfirmations = ({})
    for (var index = 0; index < parsed.sites.length; index++) {
      var site = parsed.sites[index]
      var key = String(site.hostId || "") + ":" + String(site.id || "")
      if (String(site.status || "up") === "down") {
        var failures = Number(downConfirmations[key] || 0) + 1
        nextConfirmations[key] = Math.min(2, failures)
        if (failures < 2) {
          site.status = "up"
          site.statusText = "Checking connectivity"
          site.pendingDown = true
        }
      }
    }
    downConfirmations = nextConfirmations

    var priority = ({ down: 0, backup: 1, up: 2 })
    parsed.sites.sort(function(left, right) {
      var leftRank = priority[String(left.status || "up")]
      var rightRank = priority[String(right.status || "up")]
      if (leftRank !== rightRank) return leftRank - rightRank
      var leftName = String(left.name || "").toLowerCase()
      var rightName = String(right.name || "").toLowerCase()
      return leftName < rightName ? -1 : (leftName > rightName ? 1 : 0)
    })

    var confirmedDown = 0
    var backupActive = 0
    for (var siteIndex = 0; siteIndex < parsed.sites.length; siteIndex++) {
      if (parsed.sites[siteIndex].status === "down") confirmedDown++
      else if (parsed.sites[siteIndex].status === "backup") backupActive++
    }
    var offlineDevices = Number(parsed.network && parsed.network.offlineCount || 0)
    var updates = Number(parsed.network && parsed.network.updateCount || 0)
    if (confirmedDown > 0) {
      parsed.severity = "critical"
      parsed.message = String(confirmedDown) + " site(s) unreachable"
    } else if (backupActive > 0) {
      parsed.severity = "warning"
      parsed.message = String(backupActive) + " site(s) using backup WAN"
    } else if (offlineDevices > 0) {
      parsed.severity = "critical"
      parsed.message = String(offlineDevices) + " device(s) offline across " + String(parsed.sites.length) + " sites"
    } else if (updates > 0) {
      parsed.severity = "warning"
      parsed.message = String(updates) + " firmware update(s) across " + String(parsed.sites.length) + " sites"
    } else {
      parsed.severity = "healthy"
      parsed.message = "All " + String(parsed.sites.length) + " sites operational"
    }
    return parsed
  }

  function refresh() {
    if (summaryProc.running) return
    loading = true
    notice = ""
    summaryProc.command = [helper, "summary"]
    summaryProc.running = true
  }

  function openSite(site) {
    if (!site || !site.hostId || !site.id) return
    selectedSite = site
    siteData = ({})
    siteTab = 0
    selectedCameraId = ""
    selectedCameraName = ""
    snapshotPath = ""
    loadSite()
  }

  function loadSite() {
    if (!inSite || siteProc.running) return
    siteLoading = true
    notice = ""
    siteProc.command = [helper, "site", String(selectedSite.hostId), String(selectedSite.id)]
    siteProc.running = true
  }

  function backToSites() {
    selectedSite = null
    siteData = ({})
    siteTab = 0
    selectedCameraId = ""
    selectedCameraName = ""
    snapshotPath = ""
    activeTab = 1
    notice = ""
  }

  function attentionSites() {
    var result = []
    var sites = data && data.sites ? data.sites : []
    for (var index = 0; index < sites.length; index++) {
      var site = sites[index]
      if (String(site.status || "up") !== "up") result.push(site)
    }
    return result
  }

  function siteAttentionColor(site) {
    if (site && String(site.status || "up") === "up" && Number(site.offlineCount || 0) > 0) return urgent
    return Model.siteColor(site ? site.status : "up", healthy, backup, urgent)
  }

  function overviewSiteItems(kind) {
    var result = []
    var sites = data && data.sites ? data.sites : []
    for (var index = 0; index < sites.length; index++) {
      var site = sites[index]
      if (kind === "sites"
          || (kind === "clients" && Number(site.clientCount || 0) > 0)
          || (kind === "offline" && String(site.status || "up") !== "up")) {
        result.push(site)
      }
    }
    if (kind === "clients") result.sort(function(left, right) { return Number(right.clientCount || 0) - Number(left.clientCount || 0) })
    return result
  }

  function overviewDeviceItems(kind) {
    var result = []
    var devices = data && data.network && data.network.devices ? data.network.devices : []
    for (var index = 0; index < devices.length; index++) {
      if (kind === "devices" || (kind === "offline" && devices[index].online !== true)) result.push(devices[index])
    }
    if (!cloudMode && kind === "cameras") {
      return data && data.protect && data.protect.cameras ? data.protect.cameras : []
    }
    return result
  }

  function selectOverview(kind) {
    overviewSelection = overviewSelection === kind ? "" : kind
  }

  function inspectCertificate() {
    if (probeProc.running || hostField.text.trim() === "") return
    probeFingerprint = ""
    certificateAccepted = false
    notice = "Inspecting the console certificate…"
    probeProc.command = [helper, "probe", hostField.text.trim()]
    probeProc.running = true
  }

  function connect() {
    if (connectProc.running || !certificateAccepted || probeFingerprint === "" || apiKeyField.text === "") return
    pendingSecret = apiKeyField.text
    apiKeyField.text = ""
    notice = "Authenticating securely…"
    connectProc.command = [helper, "connect", hostField.text.trim(), probeFingerprint]
    connectProc.running = true
  }

  function connectCloud() {
    if (cloudConnectProc.running || cloudKeyField.text === "") return
    pendingSecret = cloudKeyField.text
    cloudKeyField.text = ""
    notice = "Connecting to all UniFi sites…"
    cloudConnectProc.command = [helper, "connect-cloud"]
    cloudConnectProc.running = true
  }

  function pasteApiKey(forLocalConsole) {
    if (pasteProc.running) return
    pasteForLocalConsole = forLocalConsole === true
    notice = "Reading the clipboard…"
    pasteProc.running = true
  }

  function selectCamera(camera) {
    if (!camera) return
    selectedCameraId = String(camera.id || "")
    selectedCameraName = Model.safe(camera.name, "Camera")
    snapshotPath = ""
    if (selectedCameraId !== "") requestSnapshot()
  }

  function requestSnapshot() {
    var viewingProtect = inSite ? siteTab === 1 : activeTab === 2
    if (!opened || !viewingProtect || selectedCameraId === "" || snapshotProc.running) return
    snapshotProc.command = inSite
      ? [helper, "snapshot", selectedCameraId, String(selectedSite.hostId)]
      : [helper, "snapshot", selectedCameraId]
    snapshotProc.running = true
  }

  function openConsole() {
    if (!connected) return
    Quickshell.execDetached(["xdg-open", String(data.baseUrl || ("https://" + String(data.host || "")))])
  }

  function openAccount() {
    Quickshell.execDetached(["xdg-open", "https://unifi.ui.com"])
  }

  onOpenedChanged: {
    if (opened) {
      if (inSite) loadSite()
      else refresh()
    }
    else snapshotPath = ""
  }

  onActiveTabChanged: {
    if (!inSite && activeTab === 2 && data.protect && data.protect.cameras && data.protect.cameras.length > 0) {
      if (selectedCameraId === "") selectCamera(data.protect.cameras[0])
      else requestSnapshot()
    }
  }

  onSiteTabChanged: {
    if (inSite && siteTab === 1 && siteProtectInstalled && siteData.protect.cameras.length > 0) {
      if (selectedCameraId === "") selectCamera(siteData.protect.cameras[0])
      else requestSnapshot()
    }
  }

  Component.onCompleted: refresh()

  Process {
    id: summaryProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, connected: false, error: "Invalid helper response" })
        root.data = root.stabilizeCloudSummary(parsed)
        root.notice = parsed.ok ? "" : Model.safe(parsed.error, "Unable to load UniFi")
        root.loading = false
        root.refreshAgeSec = 0
        root.lastRefreshMs = Date.now()
      }
    }
    onExited: function(exitCode) { root.loading = false }
  }

  Process {
    id: clearHistoryProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
    }
  }

  Process {
    id: siteProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, error: "Invalid site response" })
        if (parsed.ok) {
          root.siteData = parsed
          root.notice = ""
          if (root.siteTab === 1 && parsed.protect && parsed.protect.cameras && parsed.protect.cameras.length > 0) {
            var selectedStillExists = false
            for (var index = 0; index < parsed.protect.cameras.length; index++) {
              if (String(parsed.protect.cameras[index].id) === root.selectedCameraId) selectedStillExists = true
            }
            if (!selectedStillExists) root.selectCamera(parsed.protect.cameras[0])
            else root.requestSnapshot()
          }
        } else root.notice = Model.safe(parsed.error, "Unable to load this site")
        root.siteLoading = false
      }
    }
    onExited: function(exitCode) { root.siteLoading = false }
  }

  Process {
    id: probeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, error: "Certificate inspection failed" })
        if (parsed.ok) {
          root.probeFingerprint = String(parsed.fingerprint || "")
          root.certificateAccepted = parsed.trusted === true
          root.notice = parsed.trusted ? "Console identity already trusted" : "Compare this fingerprint with your UniFi console"
        } else root.notice = Model.safe(parsed.error, "Certificate inspection failed")
      }
    }
  }

  Process {
    id: connectProc
    stdinEnabled: true
    onStarted: {
      write(root.pendingSecret + "\n")
      root.pendingSecret = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, connected: false, error: "Authentication failed" })
        root.data = root.stabilizeCloudSummary(parsed)
        if (parsed.ok) {
          root.notice = "Connected securely"
          root.probeFingerprint = ""
          root.certificateAccepted = false
        } else root.notice = Model.safe(parsed.error, "Authentication failed")
      }
    }
    onExited: root.pendingSecret = ""
  }

  Process {
    id: cloudConnectProc
    stdinEnabled: true
    onStarted: {
      write(root.pendingSecret + "\n")
      root.pendingSecret = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, connected: false, error: "Site Manager authentication failed" })
        root.data = root.stabilizeCloudSummary(parsed)
        if (parsed.ok) {
          root.notice = "Connected to all accessible sites"
          root.activeTab = 0
        } else root.notice = Model.safe(parsed.error, "Site Manager authentication failed")
      }
    }
    onExited: root.pendingSecret = ""
  }

  Process {
    id: pasteProc
    command: ["wl-paste", "--no-newline", "--type", "text"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var value = String(text || "").trim()
        if (value === "") {
          root.notice = "No text was found on the clipboard"
          return
        }
        if (root.pasteForLocalConsole) apiKeyField.text = value
        else cloudKeyField.text = value
        root.notice = "API key pasted securely"
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.notice = "Clipboard access failed"
    }
  }

  Process {
    id: snapshotProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false })
        if (parsed.ok && parsed.path) root.snapshotPath = "file://" + parsed.path
      }
    }
  }

  Process {
    id: disconnectProc
    command: [root.helper, "disconnect"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.confirmDisconnect = false
        root.data = ({ connected: false })
        root.notice = "Connection removed"
      }
    }
  }

  Timer {
    interval: Math.max(10, root.refreshSeconds) * 1000
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.inSite ? root.loadSite() : root.refresh()
  }

  Timer {
    interval: 2500
    running: root.opened && root.selectedCameraId !== "" && (root.inSite ? root.siteTab === 1 : root.activeTab === 2)
    repeat: true
    triggeredOnStart: false
    onTriggered: root.requestSnapshot()
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.refreshAgeSec = Math.max(0, Math.floor((Date.now() - root.lastRefreshMs) / 1000))
  }


  implicitWidth: button.implicitWidth + (badge.visible ? badge.width : 0)
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    parent: root
    x: 0
    y: 0
    height: parent ? parent.height : implicitHeight
    bar: root.bar
    text: Model.severityIcon(root.barSeverity)
    foreground: root.foreground
    activeColor: root.barSeverity === "critical" ? root.urgent : (root.barSeverity === "warning" ? root.backup : root.foreground)
    useActiveColor: root.connected && root.barSeverity !== "healthy"
    active: root.connected && root.barSeverity !== "healthy"
    dimmed: !root.connected
    tooltipText: !root.connected
      ? "UniFi SiteThread · Connect"
      : "UniFi SiteThread · " + Model.safe(root.data.message, "Connected")
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  Rectangle {
    id: badge
    parent: root
    visible: root.alertCount > 0
    x: button.x + button.width - Style.space(4)
    y: Math.max(0, (root.height - height) / 2)
    width: Math.max(height, badgeText.implicitWidth + Style.space(6))
    height: Style.space(15)
    radius: height / 2
    color: root.barSeverity === "critical" ? root.urgent : root.backup
    border.width: 1
    border.color: (Color.popups && Color.popups.background) ? Color.popups.background : "#1E1E2E"
    Text { textFormat: Text.PlainText;
      id: badgeText
      anchors.centerIn: parent
      text: String(root.alertCount)
      color: "#ffffff"
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    triggerMode: "click"
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: popup.fittedContentHeight(Math.min(Style.space(650), content.implicitHeight))

    Flickable {
      id: scroll
      anchors.fill: parent
      contentWidth: width
      contentHeight: content.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: content
        width: scroll.width
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(10)
          PanelActionButton {
            visible: root.inSite
            iconText: "\uf060"
            tooltipText: "Back to all sites"
            foreground: root.foreground
            fontFamily: root.fontFamily
            size: Style.space(28)
            onClicked: root.backToSites()
          }
          Text { textFormat: Text.PlainText;
            text: "\uf233"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            width: parent.width - Style.space(root.inSite ? 190 : 200)
            spacing: Style.space(1)
            Row {
              spacing: Style.space(8)
              Text { textFormat: Text.PlainText;
                text: root.inSite ? Model.safe(root.selectedSite.name, "UNIFI SITE") : "UNIFI SITETHREAD"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Rectangle {
                visible: root.connected && !root.inSite
                radius: 3
                height: Style.space(16)
                width: statusPillText.implicitWidth + Style.space(8)
                color: root.barSeverity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18) : (root.barSeverity === "warning" ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.18) : Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.18))
                border.width: 1
                border.color: root.barSeverity === "critical" ? root.urgent : (root.barSeverity === "warning" ? root.backup : root.healthy)
                anchors.verticalCenter: parent.verticalCenter
                Text { textFormat: Text.PlainText;
                  id: statusPillText
                  anchors.centerIn: parent
                  text: root.barSeverity === "critical" ? "ATTENTION" : (root.barSeverity === "warning" ? "BACKUP WAN" : "OPERATIONAL")
                  color: root.barSeverity === "critical" ? root.urgent : (root.barSeverity === "warning" ? root.backup : root.healthy)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                }
              }
            }
            Text { textFormat: Text.PlainText;
              text: root.inSite
                ? Model.safe(root.selectedSite.statusText, "Live site view")
                : (root.connected ? Model.summarySubtitle(root.data) : "Network + Protect")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
          Text { textFormat: Text.PlainText;
            visible: root.connected && !root.inSite && root.refreshAgeSec >= 0
            text: Model.formatAge(root.refreshAgeSec)
            color: root.refreshAgeSec > 120 ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            anchors.verticalCenter: parent.verticalCenter
          }
          PanelActionButton {
            id: refreshActionBtn
            iconText: "\uf021"
            tooltipText: "Refresh"
            foreground: root.loading ? root.accent : root.foreground
            fontFamily: root.fontFamily
            size: Style.space(28)
            onClicked: root.inSite ? root.loadSite() : root.refresh()
            RotationAnimation on rotation {
              running: root.loading
              loops: Animation.Infinite
              from: 0
              to: 360
              duration: 800
            }
          }
          PanelActionButton {
            visible: root.connected && !root.inSite
            iconText: "\uf35d"
            tooltipText: "Open UniFi"
            foreground: root.foreground
            fontFamily: root.fontFamily
            size: Style.space(28)
            onClicked: root.openConsole()
          }
        }

        Rectangle {
          width: parent.width
          height: 2
          color: "transparent"
          clip: true
          visible: root.loading
          Rectangle {
            id: refreshProgressGlow
            width: parent.width * 0.35
            height: 2
            radius: 1
            color: root.accent
            NumberAnimation on x {
              running: root.loading && root.opened
              loops: Animation.Infinite
              from: -refreshProgressGlow.width
              to: parent.width
              duration: 800
              easing.type: Easing.InOutQuad
            }
          }
        }

        Text { textFormat: Text.PlainText;
          visible: root.notice !== ""
          width: parent.width
          text: root.notice
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          color: root.notice.indexOf("failed") >= 0 || root.notice.indexOf("invalid") >= 0 ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Column {
          visible: !root.connected
          width: parent.width
          spacing: Style.space(12)

          PanelSectionHeader {
            width: parent.width
            text: root.localSetup ? "CONNECT TO A LOCAL UNIFI CONSOLE" : "SIGN IN TO UNIFI SITE MANAGER"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text { textFormat: Text.PlainText;
            width: parent.width
            text: root.localSetup
              ? "Use this only for a console that is not available through your UI Account. The key stays in your encrypted desktop credential store."
              : "Sign in safely in your browser, create a UI Account API key, and UniFi SiteThread will combine every site you own or administer into one view. Your password never enters this plugin."
            wrapMode: Text.WordWrap
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Column {
            visible: !root.localSetup
            width: parent.width
            spacing: Style.space(10)

            Row {
              width: parent.width
              spacing: Style.space(10)
              Rectangle {
                width: signInText.implicitWidth + Style.space(24)
                height: Style.space(36)
                radius: Style.cornerRadius
                color: signInArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
                border.width: 1
                border.color: root.accent
                Text { textFormat: Text.PlainText; id: signInText; anchors.centerIn: parent; text: "Sign in at unifi.ui.com"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                MouseArea { id: signInArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openAccount() }
              }
              Text { textFormat: Text.PlainText;
                anchors.verticalCenter: parent.verticalCenter
                text: "Then open Settings → API Keys → Create New API Key"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            TextField {
              id: cloudKeyField
              width: parent.width
              password: true
              placeholderText: "UI Account API key"
              foreground: root.foreground
              accent: root.accent
              font.family: root.fontFamily
              Keys.onReturnPressed: root.connectCloud()
            }

            Text { textFormat: Text.PlainText;
              width: parent.width
              text: pasteProc.running && !root.pasteForLocalConsole ? "Pasting…" : "Paste API key from clipboard"
              color: root.accent
              horizontalAlignment: Text.AlignRight
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.underline: cloudPasteArea.containsMouse
              MouseArea {
                id: cloudPasteArea
                anchors.fill: parent
                enabled: !pasteProc.running
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.pasteApiKey(false)
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(10)
              Rectangle {
                width: cloudConnectText.implicitWidth + Style.space(24)
                height: Style.space(36)
                radius: Style.cornerRadius
                opacity: cloudKeyField.text !== "" ? 1 : 0.45
                color: root.accent
                Text { textFormat: Text.PlainText; id: cloudConnectText; anchors.centerIn: parent; text: cloudConnectProc.running ? "Connecting…" : "Connect all sites"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                MouseArea { anchors.fill: parent; enabled: cloudKeyField.text !== "" && !cloudConnectProc.running; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.connectCloud() }
              }
              Text { textFormat: Text.PlainText;
                anchors.verticalCenter: parent.verticalCenter
                text: "Includes sites shared with your UI Account"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Text { textFormat: Text.PlainText;
              width: parent.width
              text: "Use a local console connection instead"
              color: root.accent
              horizontalAlignment: Text.AlignRight
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.underline: localSetupArea.containsMouse
              MouseArea { id: localSetupArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.localSetup = true }
            }
          }

          TextField {
            id: hostField
            visible: root.localSetup
            width: parent.width
            placeholderText: "Console address · 192.168.1.1 or unifi.local"
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            onTextChanged: {
              root.probeFingerprint = ""
              root.certificateAccepted = false
            }
            Keys.onReturnPressed: root.inspectCertificate()
          }

          Row {
            visible: root.localSetup
            width: parent.width
            spacing: Style.space(10)
            Rectangle {
              width: inspectText.implicitWidth + Style.space(20)
              height: Style.space(34)
              radius: Style.cornerRadius
              color: inspectArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
              Text { textFormat: Text.PlainText;
                id: inspectText
                anchors.centerIn: parent
                text: probeProc.running ? "Inspecting…" : "Inspect certificate"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              MouseArea {
                id: inspectArea
                anchors.fill: parent
                enabled: !probeProc.running
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.inspectCertificate()
              }
            }
            Text { textFormat: Text.PlainText;
              anchors.verticalCenter: parent.verticalCenter
              text: "No credential is sent during this check"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          BorderSurface {
            visible: root.localSetup && root.probeFingerprint !== ""
            width: parent.width
            implicitHeight: fingerprintColumn.implicitHeight + Style.space(20)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
            radius: Style.cornerRadius
            borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14), 1)
            Column {
              id: fingerprintColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(10)
              spacing: Style.space(8)
              Text { textFormat: Text.PlainText;
                text: "CONSOLE CERTIFICATE · SHA-256"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              Text { textFormat: Text.PlainText;
                width: parent.width
                text: root.probeFingerprint
                color: root.foreground
                font.family: "monospace"
                font.pixelSize: Style.font.caption
                wrapMode: Text.WrapAnywhere
              }
              Row {
                spacing: Style.space(8)
                Rectangle {
                  width: Style.space(20)
                  height: width
                  radius: Style.space(4)
                  color: root.certificateAccepted ? root.accent : "transparent"
                  border.width: 1
                  border.color: root.certificateAccepted ? root.accent : root.dim
                  Text { textFormat: Text.PlainText;
                    anchors.centerIn: parent
                    visible: root.certificateAccepted
                    text: "✓"
                    color: root.foreground
                    font.bold: true
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.certificateAccepted = !root.certificateAccepted
                  }
                }
                Text { textFormat: Text.PlainText;
                  width: fingerprintColumn.width - Style.space(35)
                  text: "I verified this fingerprint in UniFi Console → Settings → System → Advanced"
                  wrapMode: Text.WordWrap
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }

          TextField {
            id: apiKeyField
            visible: root.localSetup && root.probeFingerprint !== ""
            width: parent.width
            password: true
            placeholderText: "UniFi API key"
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            Keys.onReturnPressed: root.connect()
          }

          Text { textFormat: Text.PlainText;
            visible: root.localSetup && root.probeFingerprint !== ""
            width: parent.width
            text: pasteProc.running && root.pasteForLocalConsole ? "Pasting…" : "Paste API key from clipboard"
            color: root.accent
            horizontalAlignment: Text.AlignRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.underline: localPasteArea.containsMouse
            MouseArea {
              id: localPasteArea
              anchors.fill: parent
              enabled: !pasteProc.running
              hoverEnabled: true
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.pasteApiKey(true)
            }
          }

          Row {
            visible: root.localSetup && root.probeFingerprint !== ""
            width: parent.width
            spacing: Style.space(10)
            Rectangle {
              width: connectText.implicitWidth + Style.space(24)
              height: Style.space(36)
              radius: Style.cornerRadius
              opacity: root.certificateAccepted && apiKeyField.text !== "" ? 1 : 0.45
              color: root.accent
              Text { textFormat: Text.PlainText;
                id: connectText
                anchors.centerIn: parent
                text: connectProc.running ? "Connecting…" : "Connect securely"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              MouseArea {
                anchors.fill: parent
                enabled: root.certificateAccepted && apiKeyField.text !== "" && !connectProc.running
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.connect()
              }
            }
          }

          Text { textFormat: Text.PlainText;
            visible: root.localSetup
            width: parent.width
            text: "Use UI Account to show all sites"
            color: root.accent
            horizontalAlignment: Text.AlignRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.underline: cloudSetupArea.containsMouse
            MouseArea { id: cloudSetupArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.localSetup = false }
          }

        }

        Column {
          visible: root.connected && !root.inSite
          width: parent.width
          spacing: Style.space(12)

          Rectangle {
            width: parent.width
            height: Style.space(30)
            color: root.track
            radius: Style.cornerRadius
            border.width: 1
            border.color: root.outline

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(2)
              spacing: Style.space(3)

              Repeater {
                model: [
                  { id: 0, label: "Overview", icon: "\uf3c5" },
                  { id: 1, label: root.cloudMode ? "Sites (" + (root.data.sites ? root.data.sites.length : 0) + ")" : "Devices", icon: "\uf233" },
                  { id: 2, label: "Issues (" + root.activeIssuesCount + ")", icon: "\uf071" },
                  { id: 3, label: "Cameras (" + (root.data.protect && root.data.protect.cameras ? root.data.protect.cameras.length : 0) + ")", icon: "\uf03d", visible: !root.cloudMode || (root.data.protect && root.data.protect.available) }
                ]
                Rectangle {
                  required property var modelData
                  visible: modelData.visible !== false
                  width: Math.floor((parent.width - Style.space(12)) / (3 + (root.data.protect && root.data.protect.available ? 1 : 0)))
                  height: parent.height
                  radius: Style.cornerRadius - 1
                  readonly property bool isSelected: root.activeTab === modelData.id
                  color: isSelected ? root.accent : (tabMouse.containsMouse ? root.cardHover : "transparent")

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(5)
                    Text { textFormat: Text.PlainText; text: modelData.icon; color: isSelected ? (root.isLightTheme ? "#ffffff" : "#000000") : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: modelData.label; color: isSelected ? (root.isLightTheme ? "#ffffff" : "#000000") : (isSelected ? root.foreground : root.dim); font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: isSelected }
                  }

                  MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = modelData.id
                  }
                }
              }
            }
          }

          // TAB 0: OVERVIEW COCKPIT & ASCII GLOBE
          Column {
            visible: root.activeTab === 0
            width: parent.width
            spacing: Style.space(10)

            // 4-Card Cockpit Metric Row
            Row {
              width: parent.width
              spacing: Style.space(8)

              // 1. SITES METRIC CARD
              BorderSurface {
                width: Math.floor((content.width - Style.space(24)) / 4)
                implicitHeight: sitesMetricCol.implicitHeight + Style.space(16)
                color: root.card
                radius: Style.cornerRadius
                borderSpec: Border.flat(root.outline, 1)
                Column {
                  id: sitesMetricCol
                  anchors.centerIn: parent
                  spacing: Style.space(2)
                  Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(5)
                    Text { textFormat: Text.PlainText; text: "\uf3c5"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: "SITES"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                  }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: String(root.data.sites ? root.data.sites.length : 1); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: root.siteDownCount > 0 ? (root.siteDownCount + " Down") : "All Healthy"; color: root.siteDownCount > 0 ? root.urgent : root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeTab = 1 }
              }

              // 2. GATEWAYS & WAN METRIC CARD
              BorderSurface {
                width: Math.floor((content.width - Style.space(24)) / 4)
                implicitHeight: gwMetricCol.implicitHeight + Style.space(16)
                color: root.card
                radius: Style.cornerRadius
                borderSpec: Border.flat(root.outline, 1)
                Column {
                  id: gwMetricCol
                  anchors.centerIn: parent
                  spacing: Style.space(2)
                  Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(5)
                    Text { textFormat: Text.PlainText; text: "\uf233"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: "GATEWAYS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                  }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: String(root.data.network && root.data.network.gatewaysCount ? root.data.network.gatewaysCount : (root.data.sites ? root.data.sites.length : 1)); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: root.siteBackupCount > 0 ? (root.siteBackupCount + " Backup WAN") : "WAN Normal"; color: root.siteBackupCount > 0 ? root.backup : root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeTab = 1 }
              }

              // 3. DEVICES METRIC CARD
              BorderSurface {
                width: Math.floor((content.width - Style.space(24)) / 4)
                implicitHeight: devMetricCol.implicitHeight + Style.space(16)
                color: root.card
                radius: Style.cornerRadius
                borderSpec: Border.flat(root.outline, 1)
                Column {
                  id: devMetricCol
                  anchors.centerIn: parent
                  spacing: Style.space(2)
                  Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(5)
                    Text { textFormat: Text.PlainText; text: "\uf2db"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: "DEVICES"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                  }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: String(root.data.network ? root.data.network.deviceCount || 0 : 0); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: Number(root.data.network && root.data.network.offlineCount || 0) > 0 ? (root.data.network.offlineCount + " Offline") : "0 Offline"; color: Number(root.data.network && root.data.network.offlineCount || 0) > 0 ? root.urgent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeTab = 1 }
              }

              // 4. CLIENTS METRIC CARD
              BorderSurface {
                width: Math.floor((content.width - Style.space(24)) / 4)
                implicitHeight: cliMetricCol.implicitHeight + Style.space(16)
                color: root.card
                radius: Style.cornerRadius
                borderSpec: Border.flat(root.outline, 1)
                Column {
                  id: cliMetricCol
                  anchors.centerIn: parent
                  spacing: Style.space(2)
                  Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(5)
                    Text { textFormat: Text.PlainText; text: "\uf0c0"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: "CLIENTS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                  }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: String(root.data.network ? root.data.network.clientCount || 0 : 0); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: "WiFi: " + (root.data.network && root.data.network.wifiClients ? root.data.network.wifiClients : 0) + " · Wired: " + (root.data.network && root.data.network.wiredClients ? root.data.network.wiredClients : 0); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeTab = 1 }
              }
            }

            // 3D VECTOR GLOBE (OMAGLOBE CANVAS INTEGRATION)
            BorderSurface {
              width: parent.width
              implicitHeight: globeCardColumn.implicitHeight + Style.space(20)
              color: root.card
              radius: Style.cornerRadius
              borderSpec: Border.flat(root.outline, 1)

              Column {
                id: globeCardColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Globe Header Accessory Bar
                Item {
                  width: parent.width
                  height: Style.space(24)

                  Row {
                    spacing: Style.space(6)
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    Text { textFormat: Text.PlainText; text: "\uf0ac"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                    Text { textFormat: Text.PlainText; text: "GLOBAL FLEET TOPOLOGY"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                  }

                  // Controls: Focus, Rotate left/right, Auto-rotate
                  Row {
                    spacing: Style.space(4)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    // Focus sites
                    Rectangle {
                      width: focusBtnText.implicitWidth + Style.space(14)
                      height: Style.space(22)
                      radius: 3
                      color: focusMouse.containsMouse ? root.cardHover : root.track
                      Text { textFormat: Text.PlainText; id: focusBtnText; anchors.centerIn: parent; text: " Focus"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                      MouseArea {
                        id: focusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (root.data && root.data.sites && root.data.sites.length > 0) {
                            fleetGlobe.focusSite(root.data.sites[0])
                          }
                        }
                      }
                    }

                    // Rotate left
                    Rectangle {
                      width: Style.space(22)
                      height: Style.space(22)
                      radius: 3
                      color: rotLeftMouse.containsMouse ? root.cardHover : root.track
                      Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "◀"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                      MouseArea {
                        id: rotLeftMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fleetGlobe.centreLongitude = GlobeModel.wrapLongitude(fleetGlobe.centreLongitude - 25)
                      }
                    }

                    // Rotate right
                    Rectangle {
                      width: Style.space(22)
                      height: Style.space(22)
                      radius: 3
                      color: rotRightMouse.containsMouse ? root.cardHover : root.track
                      Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "▶"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                      MouseArea {
                        id: rotRightMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fleetGlobe.centreLongitude = GlobeModel.wrapLongitude(fleetGlobe.centreLongitude + 25)
                      }
                    }

                    // Auto-rotate toggle
                    Rectangle {
                      width: autoRotText.implicitWidth + Style.space(10)
                      height: Style.space(22)
                      radius: 3
                      color: root.autoRotate ? root.cardHover : root.track
                      border.width: 1
                      border.color: root.autoRotate ? root.accent : "transparent"
                      Text { textFormat: Text.PlainText; id: autoRotText; anchors.centerIn: parent; text: root.autoRotate ? " Auto" : " Auto"; color: root.autoRotate ? root.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.autoRotate = !root.autoRotate }
                    }
                  }
                }

                // 3D Globe Canvas Container
                Rectangle {
                  id: globeContainer
                  width: parent.width
                  height: Style.space(260)
                  color: root.isLightTheme ? "#f1f5f9" : "#080b11"
                  radius: Style.cornerRadius - 2
                  border.width: 1
                  border.color: root.outline
                  clip: true

                  Globe {
                    id: fleetGlobe
                    anchors.fill: parent
                    sites: root.data && root.data.sites ? root.data.sites : []
                    autoRotate: root.autoRotate && root.opened && root.activeTab === 0
                    fontFamily: root.fontFamily
                    sphereColor: root.isLightTheme ? "#e2e8f0" : "#0f1520"
                    landColor: root.isLightTheme ? "#94a3b8" : "#1e293b"
                    gridColor: root.isLightTheme ? "#cbd5e1" : "#334155"
                    outlineColor: root.accent
                    textColor: root.foreground
                    healthy: root.healthy
                    backup: root.backup
                    urgent: root.urgent
                    onSiteActivated: function(site) {
                      root.openSite(site)
                    }
                  }
                }

                // Interactive Telemetry Strip
                Rectangle {
                  width: parent.width
                  height: Style.space(26)
                  radius: 3
                  color: root.track
                  border.width: 1
                  border.color: root.outline

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(8)
                    Rectangle {
                      width: Style.space(6)
                      height: width
                      radius: width / 2
                      color: root.healthy
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text { textFormat: Text.PlainText;
                      text: (root.data && root.data.sites ? root.data.sites.length : 0) + " sites online  ·  Drag to rotate  ·  Scroll to zoom  ·  Click node to inspect"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                }
              }
            }

            // Attention Sites List (if any site or device needs attention)
            Column {
              visible: root.activeIssuesCount > 0
              width: parent.width
              spacing: Style.space(6)

              PanelSectionHeader { width: parent.width; text: "ATTENTION REQUIRED (" + root.activeIssuesCount + ")"; foreground: root.urgent; fontFamily: root.fontFamily }

              Repeater {
                model: root.issuesList.filter(function(i) { return i.active === true })
                BorderSurface {
                  required property var modelData
                  width: content.width
                  implicitHeight: activeIssueRow.implicitHeight + Style.space(12)
                  color: root.card
                  radius: Style.cornerRadius
                  borderSpec: Border.flat(modelData.severity === "critical" ? root.urgent : root.backup, 1)

                  Row {
                    id: activeIssueRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.space(8)
                    spacing: Style.space(9)

                    Text { textFormat: Text.PlainText; text: "\uf071"; color: modelData.severity === "critical" ? root.urgent : root.backup; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }

                    Column {
                      width: parent.width - activeIssuePill.implicitWidth - Style.space(45)
                      Text { textFormat: Text.PlainText; text: Model.safe(modelData.title); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                      Text { textFormat: Text.PlainText; text: Model.safe(modelData.site) + (modelData.model ? " · " + Model.safe(modelData.model) : "") + " · " + (modelData.durationSeconds ? ("Down for " + Model.formatDuration(modelData.durationSeconds)) : "Active"); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    }

                    Rectangle {
                      id: activeIssuePill
                      radius: 3
                      height: Style.space(18)
                      width: activePillLabel.implicitWidth + Style.space(10)
                      color: modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.18)
                      border.width: 1
                      border.color: modelData.severity === "critical" ? root.urgent : root.backup
                      anchors.verticalCenter: parent.verticalCenter
                      Text { textFormat: Text.PlainText; id: activePillLabel; anchors.centerIn: parent; text: "ACTIVE"; color: modelData.severity === "critical" ? root.urgent : root.backup; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                    }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeTab = 2 }
                }
              }
            }
          }

          // TAB 1: SITES (HIGH DENSITY FLEET VIEW)
          Column {
            visible: root.activeTab === 1
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader { width: parent.width; text: root.cloudMode ? "ALL SITES (" + (root.data.sites ? root.data.sites.length : 0) + ")" : "NETWORK DEVICES"; foreground: root.foreground; fontFamily: root.fontFamily }

            Repeater {
              model: root.cloudMode
                ? (root.data.sites || [])
                : (root.data.network && root.data.network.devices ? root.data.network.devices : [])
              BorderSurface {
                required property var modelData
                width: content.width
                implicitHeight: denseSiteRow.implicitHeight + Style.space(16)
                color: root.card
                radius: Style.cornerRadius
                borderSpec: Border.flat(root.outline, 1)

                Row {
                  id: denseSiteRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(9)
                  spacing: Style.space(10)

                  // Status dot
                  Rectangle {
                    width: Style.space(9)
                    height: width
                    radius: width / 2
                    color: root.cloudMode
                      ? Model.siteColor(modelData.status, root.healthy, root.backup, root.urgent)
                      : (modelData.online ? root.healthy : root.urgent)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  // Main site telemetry
                  Column {
                    width: parent.width - Style.space(root.cloudMode ? 240 : 130)
                    spacing: Style.space(2)
                    Row {
                      spacing: Style.space(6)
                      Text { textFormat: Text.PlainText; text: Model.safe(modelData.name, "UniFi Site"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                      Rectangle {
                        visible: root.cloudMode && modelData.gatewayModel !== undefined && modelData.gatewayModel !== ""
                        radius: 3
                        height: Style.space(16)
                        width: gwBadgeText.implicitWidth + Style.space(8)
                        color: root.track
                        border.width: 1
                        border.color: root.outline
                        anchors.verticalCenter: parent.verticalCenter
                        Text { textFormat: Text.PlainText; id: gwBadgeText; anchors.centerIn: parent; text: Model.safe(modelData.gatewayModel); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                      }
                    }
                    Text { textFormat: Text.PlainText;
                      text: root.cloudMode
                        ? (String(modelData.deviceCount || 0) + " dev · " + String(modelData.clientCount || 0) + " cli ( " + (modelData.wifiClients || 0) + " / 󰈀 " + (modelData.wiredClients || 0) + ")" + (modelData.isp ? " · " + Model.safe(modelData.isp) : "") + " · WAN " + Number(modelData.wanUptime || 100).toFixed(1) + "%")
                        : (Model.safe(modelData.model, "") + (modelData.ip ? " · " + Model.safe(modelData.ip) : ""))
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // SSH to Gateway Action Button
                  Rectangle {
                    visible: root.cloudMode && modelData.gatewayIp !== undefined && modelData.gatewayIp !== ""
                    width: sshBtnText.implicitWidth + Style.space(12)
                    height: Style.space(24)
                    radius: 3
                    color: sshMouse.containsMouse ? root.cardHover : root.track
                    border.width: 1
                    border.color: root.outline
                    anchors.verticalCenter: parent.verticalCenter
                    Text { textFormat: Text.PlainText; id: sshBtnText; anchors.centerIn: parent; text: "SSH"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                    MouseArea {
                      id: sshMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var ip = String(modelData.gatewayIp || "").trim()
                        if (ip) {
                          try {
                            Quickshell.execDetached(["xdg-terminal-exec", "--", "ssh", "admin@" + ip])
                          } catch (e) {
                            console.warn("SSH terminal error", e)
                          }
                        }
                      }
                    }
                  }

                  // Status Pill
                  Rectangle {
                    radius: 3
                    height: Style.space(20)
                    width: siteStatusLabel.implicitWidth + Style.space(10)
                    color: root.cloudMode
                      ? (modelData.status === "down" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18) : (modelData.status === "backup" ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.18) : Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.18)))
                      : (modelData.online ? root.track : Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18))
                    border.width: 1
                    border.color: root.cloudMode
                      ? Model.siteColor(modelData.status, root.healthy, root.backup, root.urgent)
                      : (modelData.online ? root.outline : root.urgent)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { textFormat: Text.PlainText;
                      id: siteStatusLabel
                      anchors.centerIn: parent
                      text: root.cloudMode
                        ? String(modelData.statusText || "Online").toUpperCase()
                        : (modelData.online ? "ONLINE" : "OFFLINE")
                      color: root.cloudMode
                        ? Model.siteColor(modelData.status, root.healthy, root.backup, root.urgent)
                        : (modelData.online ? root.dim : root.urgent)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                    }
                  }
                }
                MouseArea { anchors.fill: parent; enabled: root.cloudMode; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.openSite(modelData) }
              }
            }
          }

          // TAB 2: ISSUES & AUDIT TRAIL (HISTORICAL RESOLVED ISSUES GREYED OUT)
          Column {
            visible: root.activeTab === 2
            width: parent.width
            spacing: Style.space(8)

            // Header & Filter bar
            Item {
              width: parent.width
              height: Style.space(24)

              PanelSectionHeader {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(280)
                text: "FLEET ISSUES & EVENT JOURNAL"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              // Filter buttons & Clear button
              Row {
                spacing: Style.space(4)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  width: allFilterText.implicitWidth + Style.space(10)
                  height: Style.space(22)
                  radius: 3
                  color: root.issueFilter === "all" ? root.accent : root.track
                  Text { textFormat: Text.PlainText; id: allFilterText; anchors.centerIn: parent; text: "All (" + root.issuesList.length + ")"; color: root.issueFilter === "all" ? (root.isLightTheme ? "#ffffff" : "#000000") : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: root.issueFilter === "all" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.issueFilter = "all" }
                }

                Rectangle {
                  width: actFilterText.implicitWidth + Style.space(10)
                  height: Style.space(22)
                  radius: 3
                  color: root.issueFilter === "active" ? root.urgent : root.track
                  Text { textFormat: Text.PlainText; id: actFilterText; anchors.centerIn: parent; text: "Active (" + root.activeIssuesCount + ")"; color: root.issueFilter === "active" ? "#ffffff" : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: root.issueFilter === "active" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.issueFilter = "active" }
                }

                Rectangle {
                  width: resFilterText.implicitWidth + Style.space(10)
                  height: Style.space(22)
                  radius: 3
                  color: root.issueFilter === "resolved" ? root.dim : root.track
                  Text { textFormat: Text.PlainText; id: resFilterText; anchors.centerIn: parent; text: "Resolved (" + (root.issuesList.length - root.activeIssuesCount) + ")"; color: root.issueFilter === "resolved" ? "#ffffff" : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: root.issueFilter === "resolved" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.issueFilter = "resolved" }
                }

                Rectangle {
                  width: clearHistoryBtnText.implicitWidth + Style.space(10)
                  height: Style.space(22)
                  radius: 3
                  color: clearHistoryMouse.containsMouse ? root.cardHover : root.track
                  border.width: 1
                  border.color: root.outline
                  Text { textFormat: Text.PlainText; id: clearHistoryBtnText; anchors.centerIn: parent; text: "Clear"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                  MouseArea {
                    id: clearHistoryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      clearHistoryProc.command = [root.helper, "clear-history"]
                      clearHistoryProc.running = true
                    }
                  }
                }
              }
            }

            // Issue list items (Active on top, Resolved greyed out below)
            Repeater {
              model: {
                var list = root.issuesList || []
                if (root.issueFilter === "active") return list.filter(function(i) { return i.active === true })
                if (root.issueFilter === "resolved") return list.filter(function(i) { return i.active !== true })
                return list
              }

              BorderSurface {
                required property var modelData
                readonly property bool isResolved: modelData.active !== true
                width: content.width
                implicitHeight: issueRow.implicitHeight + Style.space(14)
                color: root.card
                radius: Style.cornerRadius
                opacity: isResolved ? 0.62 : 1.0
                borderSpec: Border.flat(isResolved ? root.outline : (modelData.severity === "critical" ? root.urgent : root.backup), 1)

                Row {
                  id: issueRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(9)
                  spacing: Style.space(10)

                  // Status Icon (Warning vs Checkmark)
                  Text {
                    textFormat: Text.PlainText
                    text: isResolved ? "✓" : "\uf071"
                    color: isResolved ? root.dim : (modelData.severity === "critical" ? root.urgent : root.backup)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Column {
                    width: parent.width - issueBadge.implicitWidth - Style.space(45)
                    spacing: Style.space(2)
                    Text {
                      textFormat: Text.PlainText
                      text: Model.safe(modelData.title)
                      color: isResolved ? root.dim : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: !isResolved
                    }
                    Text {
                      textFormat: Text.PlainText
                      text: isResolved
                        ? (Model.safe(modelData.site) + (modelData.resolvedAt ? (" · Resolved " + Model.timeAgo(modelData.resolvedAt)) : "") + (modelData.durationSeconds ? (" · Downtime: " + Model.formatDuration(modelData.durationSeconds)) : ""))
                        : (Model.safe(modelData.site) + (modelData.durationSeconds ? (" · Down for " + Model.formatDuration(modelData.durationSeconds)) : ""))
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // Status Pill (Active Alert vs Greyed-out Resolved)
                  Rectangle {
                    id: issueBadge
                    radius: 3
                    height: Style.space(18)
                    width: issueBadgeText.implicitWidth + Style.space(10)
                    color: isResolved ? root.track : (modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.18))
                    border.width: 1
                    border.color: isResolved ? root.outline : (modelData.severity === "critical" ? root.urgent : root.backup)
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                      textFormat: Text.PlainText
                      id: issueBadgeText
                      anchors.centerIn: parent
                      text: isResolved ? "RESOLVED" : "ACTIVE"
                      color: isResolved ? root.dim : (modelData.severity === "critical" ? root.urgent : root.backup)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                    }
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              visible: (root.issuesList || []).length === 0
              width: parent.width
              text: "No issues reported across your UniFi fleet. All systems operational."
              horizontalAlignment: Text.AlignHCenter
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          // TAB 3: PROTECT CAMERAS
          Column {
            visible: root.activeTab === 3
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader { width: parent.width; text: root.cloudMode ? "PROTECT ACROSS ALL SITES" : "PROTECT CAMERAS"; foreground: root.foreground; fontFamily: root.fontFamily }

            Rectangle {
              visible: root.selectedCameraId !== ""
              width: parent.width
              height: Math.round(width * 9 / 16)
              radius: Style.cornerRadius
              color: Qt.rgba(0, 0, 0, 0.35)
              clip: true
              Image { anchors.fill: parent; source: root.snapshotPath; fillMode: Image.PreserveAspectCrop; cache: false; asynchronous: true }
              Text { textFormat: Text.PlainText; anchors.centerIn: parent; visible: root.snapshotPath === ""; text: root.cloudMode ? "Open Site Manager for live video" : "Loading " + root.selectedCameraName; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
              Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(8)
                width: cameraLabel.implicitWidth + Style.space(12)
                height: cameraLabel.implicitHeight + Style.space(6)
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.62)
                Text { textFormat: Text.PlainText; id: cameraLabel; anchors.centerIn: parent; text: root.selectedCameraName; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: root.data.protect && root.data.protect.cameras ? root.data.protect.cameras : []
                Rectangle {
                  required property var modelData
                  width: Math.max(Style.space(110), Math.floor((content.width - Style.space(18)) / Math.min(4, root.data.protect.cameras.length)))
                  height: Style.space(52)
                  radius: Style.cornerRadius
                  color: String(modelData.id) === root.selectedCameraId ? Style.selectedFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
                  border.width: String(modelData.id) === root.selectedCameraId ? 1 : 0
                  border.color: root.accent
                  Column {
                    anchors.centerIn: parent
                    width: parent.width - Style.space(12)
                    Text { textFormat: Text.PlainText; width: parent.width; text: Model.safe(modelData.name, "Camera"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                    Text { textFormat: Text.PlainText; width: parent.width; text: modelData.online ? "ONLINE" : "OFFLINE"; color: modelData.online ? root.dim : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectCamera(modelData) }
                }
              }
            }
            Text { textFormat: Text.PlainText; visible: !root.data.protect || !root.data.protect.available; width: parent.width; text: root.cloudMode ? "Site Manager did not report Protect devices for this account" : "UniFi Protect is unavailable for this connection"; horizontalAlignment: Text.AlignHCenter; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) }

          Row {
            width: parent.width
            spacing: Style.space(10)
            Text { textFormat: Text.PlainText;
              width: parent.width - disconnectButton.width - Style.space(10)
              text: root.cloudMode ? "UI Account key stored securely in Secret Service" : "Credentials stored securely in Secret Service"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
              id: disconnectButton
              width: disconnectText.implicitWidth + Style.space(18)
              height: Style.space(30)
              radius: Style.cornerRadius
              color: disconnectArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
              Text { textFormat: Text.PlainText; id: disconnectText; anchors.centerIn: parent; text: root.confirmDisconnect ? "Click again to forget" : "Disconnect"; color: root.confirmDisconnect ? root.urgent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              MouseArea {
                id: disconnectArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!root.confirmDisconnect) root.confirmDisconnect = true
                  else disconnectProc.running = true
                }
              }
            }
          }
        }

        Column {
          visible: root.connected && root.inSite
          width: parent.width
          spacing: Style.space(12)

          BorderSurface {
            width: parent.width
            implicitHeight: siteHealthRow.implicitHeight + Style.space(22)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.045)
            radius: Style.cornerRadius
            borderSpec: Border.flat(Model.siteColor(root.selectedSite ? root.selectedSite.status : "up", root.healthy, root.backup, root.urgent), 1)
            Row {
              id: siteHealthRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(11)
              spacing: Style.space(10)
              Rectangle {
                width: Style.space(12)
                height: width
                radius: width / 2
                color: Model.siteColor(root.selectedSite ? root.selectedSite.status : "up", root.healthy, root.backup, root.urgent)
                anchors.verticalCenter: parent.verticalCenter
              }
              Column {
                width: parent.width - Style.space(32)
                Text { textFormat: Text.PlainText; text: Model.safe(root.selectedSite ? root.selectedSite.statusText : "", "Online"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                Text { textFormat: Text.PlainText;
                  text: (root.selectedSite && root.selectedSite.isp ? Model.safe(root.selectedSite.isp, "") + "  ·  " : "") + "Live data from this UniFi console"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          Text { textFormat: Text.PlainText;
            visible: root.siteLoading
            width: parent.width
            text: "Loading live site data…"
            horizontalAlignment: Text.AlignHCenter
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Row {
            visible: root.siteData && root.siteData.ok === true
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: root.siteProtectInstalled ? 2 : 1
              Rectangle {
                required property int index
                width: Math.floor((content.width - (root.siteProtectInstalled ? Style.space(6) : 0)) / (root.siteProtectInstalled ? 2 : 1))
                height: Style.space(34)
                radius: Style.cornerRadius
                color: root.siteTab === index ? Style.selectedFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
                border.width: root.siteTab === index ? 1 : 0
                border.color: root.accent
                Text { textFormat: Text.PlainText;
                  anchors.centerIn: parent
                  text: index === 0 ? "Network" : "Protect"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: root.siteTab === index
                }
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.siteTab = index }
              }
            }
          }

          Row {
            visible: root.siteData && root.siteData.ok === true
            width: parent.width
            spacing: Style.space(8)
            Repeater {
              model: [
                { label: "DEVICES", value: root.siteData.network ? root.siteData.network.deviceCount || 0 : 0 },
                { label: "CLIENTS", value: root.siteData.network ? root.siteData.network.clientCount || 0 : 0 },
                { label: "OFFLINE", value: root.siteData.network ? root.siteData.network.offlineCount || 0 : 0 },
                { label: "CAMERAS", value: root.siteProtectInstalled && root.siteData.protect ? root.siteData.protect.cameraCount || 0 : 0 }
              ]
              BorderSurface {
                required property var modelData
                width: Math.floor((content.width - Style.space(24)) / 4)
                implicitHeight: siteStat.implicitHeight + Style.space(16)
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
                radius: Style.cornerRadius
                borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10), 1)
                Column {
                  id: siteStat
                  anchors.centerIn: parent
                  spacing: Style.space(2)
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: String(modelData.value); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                }
              }
            }
          }

          Column {
            visible: root.siteData && root.siteData.ok === true && root.siteTab === 0
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader { width: parent.width; text: "LIVE NETWORK DEVICES"; foreground: root.foreground; fontFamily: root.fontFamily }
            Repeater {
              model: root.siteData.network && root.siteData.network.devices ? root.siteData.network.devices : []
              BorderSurface {
                required property var modelData
                width: content.width
                implicitHeight: siteDeviceRow.implicitHeight + Style.space(16)
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
                radius: Style.cornerRadius
                borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.09), 1)
                Row {
                  id: siteDeviceRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(9)
                  spacing: Style.space(10)
                  Rectangle { width: Style.space(9); height: width; radius: width / 2; color: modelData.online ? root.healthy : root.urgent; anchors.verticalCenter: parent.verticalCenter }
                  Column {
                    width: parent.width - Style.space(125)
                    Text { textFormat: Text.PlainText; width: parent.width; text: Model.safe(modelData.name, "UniFi device"); elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                    Text { textFormat: Text.PlainText; width: parent.width; text: Model.safe(modelData.model, "") + (modelData.ip ? "  ·  " + Model.safe(modelData.ip, "") : ""); elide: Text.ElideRight; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  }
                  Text { textFormat: Text.PlainText; text: modelData.online ? (modelData.update ? "UPDATE" : "ONLINE") : "OFFLINE"; color: modelData.online ? root.dim : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                }
              }
            }
            Text { textFormat: Text.PlainText;
              visible: !root.siteData.network || root.siteData.network.devices.length === 0
              width: parent.width
              text: "No Network devices were returned for this site"
              horizontalAlignment: Text.AlignHCenter
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          Column {
            visible: root.siteProtectInstalled && root.siteTab === 1
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader { width: parent.width; text: "LIVE PROTECT CAMERAS"; foreground: root.foreground; fontFamily: root.fontFamily }
            Rectangle {
              visible: root.selectedCameraId !== ""
              width: parent.width
              height: Math.round(width * 9 / 16)
              radius: Style.cornerRadius
              color: Qt.rgba(0, 0, 0, 0.45)
              clip: true
              Image { anchors.fill: parent; source: root.snapshotPath; fillMode: Image.PreserveAspectFit; cache: false; asynchronous: true }
              Text { textFormat: Text.PlainText; anchors.centerIn: parent; visible: root.snapshotPath === ""; text: "Loading " + root.selectedCameraName + "…"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
              Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(8)
                width: liveCameraLabel.implicitWidth + Style.space(14)
                height: liveCameraLabel.implicitHeight + Style.space(7)
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.68)
                Text { textFormat: Text.PlainText; id: liveCameraLabel; anchors.centerIn: parent; text: "LIVE · " + root.selectedCameraName; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: root.siteData.protect && root.siteData.protect.cameras ? root.siteData.protect.cameras : []
                Rectangle {
                  required property var modelData
                  width: Math.floor((content.width - Style.space(18)) / 4)
                  height: Style.space(52)
                  radius: Style.cornerRadius
                  color: String(modelData.id) === root.selectedCameraId ? Style.selectedFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
                  border.width: String(modelData.id) === root.selectedCameraId ? 1 : 0
                  border.color: root.accent
                  Column {
                    anchors.centerIn: parent
                    width: parent.width - Style.space(10)
                    Text { textFormat: Text.PlainText; width: parent.width; text: Model.safe(modelData.name, "Camera"); elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    Text { textFormat: Text.PlainText; width: parent.width; text: modelData.online ? "ONLINE" : "OFFLINE"; horizontalAlignment: Text.AlignHCenter; color: modelData.online ? root.healthy : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectCamera(modelData) }
                }
              }
            }
            Text { textFormat: Text.PlainText;
              visible: root.siteProtectInstalled && root.siteData.protect.cameras.length === 0
              width: parent.width
              text: "Protect is installed, but no cameras were returned"
              horizontalAlignment: Text.AlignHCenter
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function tab(index: int): void {
      root.activeTab = Math.max(0, Math.min(2, index))
      root.open()
    }
    function status(): string {
      return JSON.stringify({
        opened: root.opened,
        hasBar: root.bar !== null,
        rootWindow: root.QsWindow.window !== null,
        buttonWindow: button.QsWindow.window !== null,
        buttonParentIsRoot: button.parent === root,
        contentParentExists: content.parent !== null,
        contentWidth: content.width,
        popupVisible: popup.visible,
        popupOpen: popup.open,
        popupWidth: popup.width,
        popupHeight: popup.height,
        contentHeight: content.implicitHeight,
        downSiteCount: root.siteDownCount,
        pendingDownCount: root.countPendingSites()
      })
    }
  }
}
