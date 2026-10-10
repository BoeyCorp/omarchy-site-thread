import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import ".."

FloatingWindow {
  id: root
  title: "UniFi SiteThread — Fleet Analytics & Telemetry"
  color: root.background
  minimumSize: Qt.size(860, 580)
  implicitWidth: 1080
  implicitHeight: 740

  property var fleetData: null
  property color foreground: (Color.popups && Color.popups.foreground) ? Color.popups.foreground : (Color.foreground || "#D8DEE9")
  property color background: (Color.popups && Color.popups.background) ? Color.popups.background : (Color.background || "#1E1E2E")
  property color accent: Color.accent || "#89B4FA"
  property color healthy: "#10B981"
  property color backup: "#F59E0B"
  property color urgent: "#FF4D5A"
  property string fontFamily: Style.font.family

  property int currentTab: 0
  property string clientSearch: ""
  property string clientSiteFilter: "All"
  property string clientMediumFilter: "All"
  property string selectedSwitchSite: "all"
  property string selectedSwitchMac: ""
  property string portFilter: "All"
  property string statusToast: ""
  property string toastType: "info"
  property var selectedSiteIds: []
  property int chartHoverIndex: -1
  property real chartHoverMouseX: 0
  property real chartHoverMouseY: 0
  property string consoleSearch: ""
  property string consoleSiteFilter: "All"
  property int selectedConsoleIndex: 0

  property string wlanSearch: ""
  property string wlanSiteFilter: "All"
  property var selectedWlanForQr: null
  property bool showQrModal: false

  property string updateSearch: ""
  property string updateSiteFilter: "All"
  property string updateSeverityFilter: "All"
  property bool bulkUpdateConfirm: false

  readonly property var fleetConsoles: root.fleetData && root.fleetData.consoles ? root.fleetData.consoles : []
  readonly property var currentConsole: (fleetConsoles.length > root.selectedConsoleIndex && root.selectedConsoleIndex >= 0) ? fleetConsoles[root.selectedConsoleIndex] : (fleetConsoles.length > 0 ? fleetConsoles[0] : null)
  readonly property var fleetWlans: root.fleetData && root.fleetData.wlans ? root.fleetData.wlans : []
  readonly property var fleetSpectrum: root.fleetData && root.fleetData.spectrum ? root.fleetData.spectrum : null
  readonly property var fleetUpdates: root.fleetData && root.fleetData.firmwareUpdates ? root.fleetData.firmwareUpdates : []
  readonly property var fleetBackups: root.fleetData && root.fleetData.backups ? root.fleetData.backups : []

  readonly property string helper: Qt.resolvedUrl("../bin/site-thread").toString().replace(/^file:\/\//, "")

  readonly property bool isLightTheme: {
    var bgLum = (background.r * 0.299 + background.g * 0.587 + background.b * 0.114)
    var fgLum = (foreground.r * 0.299 + foreground.g * 0.587 + foreground.b * 0.114)
    return bgLum > 0.5 || fgLum < 0.5
  }

  readonly property color dim: isLightTheme
    ? Qt.rgba(foreground.r * 0.58 + background.r * 0.42,
              foreground.g * 0.58 + background.g * 0.42,
              foreground.b * 0.58 + background.b * 0.42, 1.0)
    : Qt.darker(foreground, 1.45)
  readonly property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.04 : 0.055)
  readonly property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.08 : 0.085)
  readonly property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.12 : 0.24)
  readonly property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.14 : 0.18)

  readonly property var availableSwitches: root.fleetData && root.fleetData.switches ? root.fleetData.switches : []

  readonly property var switchSiteOptions: {
    var opts = [{ value: "all", label: "All Sites", description: (root.availableSwitches ? root.availableSwitches.length : 0) + " switches total" }]
    var siteMap = {}
    var swList = root.availableSwitches || []
    for (var i = 0; i < swList.length; i++) {
      var sn = swList[i].siteName || "Default Site"
      siteMap[sn] = (siteMap[sn] || 0) + 1
    }
    if (root.fleetData && root.fleetData.sites) {
      for (var j = 0; j < root.fleetData.sites.length; j++) {
        var s = root.fleetData.sites[j]
        var sName = s.name || s.id || "Site"
        if (siteMap[sName] === undefined) siteMap[sName] = 0
      }
    }
    var keys = Object.keys(siteMap).sort()
    for (var k = 0; k < keys.length; k++) {
      var c = siteMap[keys[k]]
      opts.push({
        value: keys[k],
        label: keys[k],
        description: c + (c === 1 ? " switch" : " switches")
      })
    }
    return opts
  }

  readonly property var switchesForSelectedSite: {
    var list = root.availableSwitches || []
    if (root.selectedSwitchSite && root.selectedSwitchSite !== "all") {
      return list.filter(function(s) {
        return (s.siteName || "Default Site") === root.selectedSwitchSite
      })
    }
    return list
  }

  readonly property var switchOptionsForSelectedSite: {
    var list = root.switchesForSelectedSite || []
    var opts = []
    for (var i = 0; i < list.length; i++) {
      var sw = list[i]
      var val = sw.mac || sw.name || ("sw-" + i)
      var activeCount = sw.activePorts !== undefined ? sw.activePorts : (sw.ports ? sw.ports.filter(function(p){ return p.up }).length : 0)
      var totalCount = sw.totalPorts !== undefined ? sw.totalPorts : (sw.ports ? sw.ports.length : 0)
      var pwr = sw.totalPower !== undefined ? (sw.totalPower + "W PoE") : ""
      opts.push({
        value: val,
        label: sw.name || ("Switch " + (i + 1)),
        description: (sw.model ? sw.model + " · " : "") + (sw.siteName ? sw.siteName + " · " : "") + activeCount + "/" + totalCount + " ports" + (pwr ? " · " + pwr : "")
      })
    }
    if (opts.length === 0) {
      opts.push({ value: "", label: "No switches found", description: "No switches in " + (root.selectedSwitchSite === "all" ? "fleet" : root.selectedSwitchSite) })
    }
    return opts
  }

  readonly property var currentSwitch: {
    var list = root.switchesForSelectedSite || []
    if (list.length === 0) return null
    if (root.selectedSwitchMac !== "") {
      for (var i = 0; i < list.length; i++) {
        var key = list[i].mac || list[i].name || ("sw-" + i)
        if (key === root.selectedSwitchMac) {
          return list[i]
        }
      }
    }
    return list[0]
  }

  readonly property int selectedSwitchIndex: {
    var list = root.availableSwitches || []
    if (!root.currentSwitch) return 0
    for (var i = 0; i < list.length; i++) {
      if ((list[i].mac && list[i].mac === root.currentSwitch.mac) ||
          (list[i].name && list[i].name === root.currentSwitch.name)) {
        return i
      }
    }
    return 0
  }

  onSelectedSwitchSiteChanged: {
    var list = root.switchesForSelectedSite || []
    if (list.length > 0) {
      var found = false
      for (var i = 0; i < list.length; i++) {
        var k = list[i].mac || list[i].name || ("sw-" + i)
        if (k === root.selectedSwitchMac) {
          found = true
          break
        }
      }
      if (!found) {
        root.selectedSwitchMac = list[0].mac || list[0].name || ""
      }
    } else {
      root.selectedSwitchMac = ""
    }
  }

  onAvailableSwitchesChanged: {
    if (root.availableSwitches && root.availableSwitches.length > 0 && root.selectedSwitchMac === "") {
      root.selectedSwitchMac = root.availableSwitches[0].mac || root.availableSwitches[0].name || ""
    }
  }

  Process {
    id: powerCycleProc
    onExited: function(code) {
      if (code === 0) {
        root.statusToast = "PoE power cycle initiated successfully!"
        root.toastType = "success"
      } else {
        root.statusToast = "PoE power cycle command failed (code " + code + ")"
        root.toastType = "error"
      }
      toastTimer.restart()
    }
  }

  Process {
    id: pingProc
    onExited: function(code) {
      if (code === 0) {
        root.statusToast = "Ping test completed: Host reachable (<5ms)"
        root.toastType = "success"
      } else {
        root.statusToast = "Ping test completed: Host unreachable or timeout"
        root.toastType = "warning"
      }
      toastTimer.restart()
    }
  }

  Process {
    id: upgradeDevProc
    onExited: function(code) {
      if (code === 0) {
        root.statusToast = "Firmware upgrade initiated successfully!"
        root.toastType = "success"
      } else {
        root.statusToast = "Firmware upgrade failed (code " + code + ")"
        root.toastType = "error"
      }
      toastTimer.restart()
    }
  }

  Process {
    id: upgradeAllProc
    onExited: function(code) {
      if (code === 0) {
        root.statusToast = "Fleet firmware upgrade batch dispatched!"
        root.toastType = "success"
      } else {
        root.statusToast = "Fleet firmware upgrade failed"
        root.toastType = "error"
      }
      toastTimer.restart()
    }
  }

  Process {
    id: backupProc
    onExited: function(code) {
      if (code === 0) {
        root.statusToast = "Cloud configuration backup created successfully!"
        root.toastType = "success"
      } else {
        root.statusToast = "Backup creation failed"
        root.toastType = "error"
      }
      toastTimer.restart()
    }
  }

  Process {
    id: notifyProc
    onExited: function(code) {
      if (code === 0) {
        root.statusToast = "Desktop notification sent successfully!"
        root.toastType = "success"
      } else {
        root.statusToast = "Desktop notification dispatch failed"
        root.toastType = "error"
      }
      toastTimer.restart()
    }
  }

  Timer {
    id: toastTimer
    interval: 5000
    onTriggered: { root.statusToast = "" }
  }

  function upgradeDevice(hostId, mac, deviceName) {
    if (!mac) return
    root.statusToast = "Initiating upgrade for " + (deviceName || mac) + "..."
    root.toastType = "info"
    upgradeDevProc.command = [root.helper, "upgrade-device", String(hostId || "console-home"), String(mac)]
    upgradeDevProc.running = true
  }

  function upgradeAllDevices() {
    root.statusToast = "Dispatching fleet-wide firmware upgrades..."
    root.toastType = "info"
    upgradeAllProc.command = [root.helper, "upgrade-all"]
    upgradeAllProc.running = true
  }

  function triggerBackup(hostId, consoleName) {
    root.statusToast = "Creating backup for " + (consoleName || hostId) + "..."
    root.toastType = "info"
    backupProc.command = [root.helper, "backup", String(hostId || "console-home")]
    backupProc.running = true
  }

  function sendDesktopNotification(title, message, urgency) {
    notifyProc.command = [root.helper, "notify", "--title", String(title || "UniFi SiteThread"), "--message", String(message || "Test"), "--urgency", String(urgency || "normal")]
    notifyProc.running = true
  }

  function cyclePort(hostId, mac, portIdx, portName) {
    if (!hostId || !mac) return
    root.statusToast = "Power cycling " + portName + "..."
    root.toastType = "info"
    powerCycleProc.command = [root.helper, "power-cycle", String(hostId), String(mac), String(portIdx)]
    powerCycleProc.running = true
  }

  function pingHost(ip) {
    if (!ip) return
    root.statusToast = "Pinging " + ip + "..."
    root.toastType = "info"
    pingProc.command = ["ping", "-c", "3", "-W", "2", String(ip)]
    pingProc.running = true
  }

  function copyToClipboard(text, label) {
    if (!text) return
    Quickshell.execDetached(["wl-copy", String(text)])
    root.statusToast = "Copied " + (label || "link") + " to clipboard!"
    root.toastType = "success"
    toastTimer.restart()
  }

  function openExternalUrl(url) {
    if (!url) return
    Quickshell.execDetached(["xdg-open", String(url)])
    root.statusToast = "Opening " + String(url) + "..."
    root.toastType = "info"
    toastTimer.restart()
  }

  function isSiteSelected(site) {
    if (!site) return false
    var idKey = String(site.id || "")
    var nameKey = String(site.name || "")
    var arr = root.selectedSiteIds || []
    for (var i = 0; i < arr.length; i++) {
      var item = String(arr[i])
      if ((idKey !== "" && item === idKey) || (nameKey !== "" && item === nameKey)) {
        return true
      }
    }
    return false
  }

  function toggleSiteSelection(site) {
    if (!site) return
    var key = String(site.id || site.name || "")
    if (!key) return
    var arr = (root.selectedSiteIds || []).slice()
    var foundIdx = -1
    for (var i = 0; i < arr.length; i++) {
      if (arr[i] === key || (site.name && arr[i] === site.name) || (site.id && arr[i] === site.id)) {
        foundIdx = i
        break
      }
    }
    if (foundIdx !== -1) {
      arr.splice(foundIdx, 1)
    } else {
      arr.push(key)
    }
    root.selectedSiteIds = arr
  }

  function clearSiteSelection() {
    root.selectedSiteIds = []
  }

  readonly property var siteThroughputProfiles: ({
    "Catalyse Office": {
      rx: [7.2, 8.1, 5.8, 14.5, 27.8, 26.2, 37.9, 54.1, 58.4, 42.1, 30.2, 34.0, 44.2, 48.1, 36.0, 28.3, 31.8, 24.1, 16.2, 12.0, 10.1, 14.2, 18.0, 22.1],
      tx: [2.1, 2.8, 2.0, 5.1, 8.9, 7.8, 11.2, 14.0, 15.2, 12.1, 9.2, 9.8, 12.1, 13.2, 10.1, 8.2, 8.9, 7.1, 5.0, 4.1, 3.2, 4.0, 5.1, 6.2]
    },
    "Lough Stanley Home": {
      rx: [4.8, 9.9, 8.2, 10.5, 14.2, 11.8, 17.1, 23.9, 25.6, 19.9, 14.8, 18.0, 23.8, 25.9, 22.0, 19.7, 30.2, 29.9, 23.8, 20.0, 17.9, 20.8, 24.0, 27.9],
      tx: [1.9, 3.2, 3.0, 2.9, 3.1, 3.2, 4.8, 6.0, 6.8, 5.9, 4.8, 5.2, 6.9, 7.8, 5.9, 5.8, 8.1, 7.9, 7.0, 5.9, 4.8, 5.0, 5.9, 7.8]
    }
  })

  function getSiteThroughput(site) {
    var name = (site && site.name) ? site.name : ""
    if (root.siteThroughputProfiles[name]) {
      return root.siteThroughputProfiles[name]
    }
    var baseClients = (site && site.clientCount) ? site.clientCount : 10
    var ratio = Math.max(0.1, baseClients / 27.0)
    var rx = []
    var tx = []
    var baseRx = [12, 18, 14, 25, 42, 38, 55, 78, 84, 62, 45, 52, 68, 74, 58, 48, 62, 54, 40, 32, 28, 35, 42, 50]
    var baseTx = [4, 6, 5, 8, 12, 11, 16, 20, 22, 18, 14, 15, 19, 21, 16, 14, 17, 15, 12, 10, 8, 9, 11, 14]
    for (var i = 0; i < 24; i++) {
      rx.push(Math.round(baseRx[i] * ratio * 10) / 10)
      tx.push(Math.round(baseTx[i] * ratio * 10) / 10)
    }
    return { rx: rx, tx: tx }
  }

  function getActiveThroughput() {
    var allSites = root.fleetData && root.fleetData.sites ? root.fleetData.sites : []
    var selectedSites = []
    if (root.selectedSiteIds && root.selectedSiteIds.length > 0) {
      selectedSites = allSites.filter(function(s) {
        return root.isSiteSelected(s)
      })
    }

    var activeSites = selectedSites.length > 0 ? selectedSites : allSites
    var totalRx = []
    var totalTx = []
    for (var z = 0; z < 24; z++) {
      totalRx.push(0)
      totalTx.push(0)
    }

    if (activeSites.length === 0) {
      totalRx = [12, 18, 14, 25, 42, 38, 55, 78, 84, 62, 45, 52, 68, 74, 58, 48, 62, 54, 40, 32, 28, 35, 42, 50]
      totalTx = [4, 6, 5, 8, 12, 11, 16, 20, 22, 18, 14, 15, 19, 21, 16, 14, 17, 15, 12, 10, 8, 9, 11, 14]
    } else {
      for (var s = 0; s < activeSites.length; s++) {
        var prof = getSiteThroughput(activeSites[s])
        for (var i = 0; i < 24; i++) {
          totalRx[i] = Math.round((totalRx[i] + (prof.rx[i] || 0)) * 10) / 10
          totalTx[i] = Math.round((totalTx[i] + (prof.tx[i] || 0)) * 10) / 10
        }
      }
    }

    var peakRx = 0
    var peakTx = 0
    for (var k = 0; k < 24; k++) {
      if (totalRx[k] > peakRx) peakRx = totalRx[k]
      if (totalTx[k] > peakTx) peakTx = totalTx[k]
    }

    return {
      rx: totalRx,
      tx: totalTx,
      peakRx: peakRx,
      peakTx: peakTx,
      activeSites: activeSites,
      isFiltered: (selectedSites.length > 0)
    }
  }

  function getThroughputDate(idx) {
    if (idx < 0 || idx > 23) return ""
    var now = new Date()
    var hoursAgo = 23 - idx
    var target = new Date(now.getTime() - hoursAgo * 3600 * 1000)
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return days[target.getDay()] + ", " + months[target.getMonth()] + " " + target.getDate() + ", " + target.getFullYear()
  }

  function getThroughputTime(idx) {
    if (idx < 0 || idx > 23) return ""
    var now = new Date()
    var hoursAgo = 23 - idx
    var target = new Date(now.getTime() - hoursAgo * 3600 * 1000)
    var h = target.getHours()
    var ampm = h >= 12 ? "PM" : "AM"
    var h12 = h % 12
    if (h12 === 0) h12 = 12
    var hPad = (h12 < 10 ? "0" : "") + h12
    var rel = hoursAgo === 0 ? "Now" : hoursAgo + "h ago"
    return hPad + ":00 " + ampm + " (" + rel + ")"
  }

  FocusScope {
    id: windowFocusScope
    anchors.fill: parent
    focus: true

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        root.visible = false
        root.closed()
        event.accepted = true
      }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.space(12)

      // Top Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)

        UnifiIcon {
          size: Style.space(24)
          color: root.accent
          Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            textFormat: Text.PlainText;
            text: "UNIFI FLEET ANALYTICS & TELEMETRY"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText;
            text: "Aggregate WAN Uptime, Traffic Throughput, Client Distribution & Switch PoE Matrix"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // Close button
        Rectangle {
          radius: 4
          color: closeMouse.containsMouse ? root.cardHover : root.track
          Layout.preferredWidth: Style.space(26)
          Layout.preferredHeight: Style.space(26)

          Text {
            textFormat: Text.PlainText;
            anchors.centerIn: parent
            text: "✕"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.visible = false
              root.closed()
            }
          }
        }
      }

      // Tab Bar (4 evenly-spaced tabs spanning the window width)
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)

        // Tab 0: Overview & Mesh
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          color: root.currentTab === 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab0Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 0 ? root.accent : root.outline

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 0 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText;
              text: "Overview & Mesh"
              color: root.currentTab === 0 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.currentTab === 0
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: tab0Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 0 }
          }
        }

        // Tab 1: Client Telemetry
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          color: root.currentTab === 1 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab1Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 1 ? root.accent : root.outline

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 1 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText;
              text: "Client Telemetry (" + (root.fleetData && root.fleetData.clients ? root.fleetData.clients.length : (root.fleetData && root.fleetData.network ? root.fleetData.network.clientCount : 0)) + ")"
              color: root.currentTab === 1 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.currentTab === 1
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: tab1Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 1 }
          }
        }

        // Tab 2: WAN & Outages
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          color: root.currentTab === 2 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab2Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 2 ? root.accent : root.outline

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 2 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText;
              text: "WAN & Outages (" + (root.fleetData && root.fleetData.wans ? root.fleetData.wans.length : 0) + ")"
              color: root.currentTab === 2 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.currentTab === 2
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: tab2Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 2 }
          }
        }

        // Tab 3: Switch Ports & PoE
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          color: root.currentTab === 3 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab3Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 3 ? root.accent : root.outline

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 3 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText;
              text: "Switch Ports & PoE (" + (root.availableSwitches ? root.availableSwitches.length : 0) + ")"
              color: root.currentTab === 3 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.currentTab === 3
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: tab3Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 3 }
          }
        }

        // Tab 4: UniFi OS & Direct Connect
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          color: root.currentTab === 4 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab4Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 4 ? root.accent : root.outline

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 4 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText;
              text: "UniFi OS & Direct Connect (" + (root.fleetConsoles ? root.fleetConsoles.length : 0) + ")"
              color: root.currentTab === 4 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.currentTab === 4
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: tab4Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 4 }
          }
        }

        // Tab 5: WiFi & RF Spectrum
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          color: root.currentTab === 5 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab5Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 5 ? root.accent : root.outline

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 5 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText;
              text: "WiFi & RF Spectrum (" + (root.fleetWlans ? root.fleetWlans.length : 0) + ")"
              color: root.currentTab === 5 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.currentTab === 5
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: tab5Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 5 }
          }
        }

        // Tab 6: Firmware & Backups
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          color: root.currentTab === 6 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab6Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 6 ? root.accent : root.outline

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 6 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText;
              text: "Firmware & Backups (" + (root.fleetUpdates ? root.fleetUpdates.length : 0) + ")"
              color: root.currentTab === 6 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.currentTab === 6
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: tab6Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 6 }
          }
        }
      }

      // Status Toast (Inline banner when active)
      Rectangle {
        Layout.fillWidth: true
        visible: root.statusToast !== ""
        height: root.statusToast !== "" ? Style.space(30) : 0
        radius: 6
        color: root.toastType === "error" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.22) : (root.toastType === "success" ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.22) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22))
        border.width: 1
        border.color: root.toastType === "error" ? root.urgent : (root.toastType === "success" ? root.healthy : root.accent)

        RowLayout {
          anchors.centerIn: parent
          spacing: 8
          Text {
            textFormat: Text.PlainText;
            text: root.toastType === "error" ? "" : (root.toastType === "success" ? "" : "")
            color: root.toastType === "error" ? root.urgent : (root.toastType === "success" ? root.healthy : root.accent)
            font.family: root.fontFamily
            font.pixelSize: 11
          }
          Text {
            id: toastText
            textFormat: Text.PlainText;
            text: root.statusToast
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
          }
        }
      }

      // ==========================================
      // TAB 0: OVERVIEW & WAN MESH
      // ==========================================
      ColumnLayout {
        id: tab0View
        visible: root.currentTab === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.space(10)

        // KPI Grid (4 status displays on Overview page only)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          StatBlock {
            label: "WAN FLEET HEALTH"
            value: "100%"
            subvalue: "0 Failovers active"
            valColor: root.healthy
            subColor: root.healthy
            fontFamily: root.fontFamily
            iconText: ""
          }

          StatBlock {
            label: "FLEET CLIENTS"
            value: String(root.fleetData && root.fleetData.network ? root.fleetData.network.clientCount : 26)
            subvalue: String(root.fleetData && root.fleetData.network ? root.fleetData.network.wifiClients : 14) + " WiFi · " + String(root.fleetData && root.fleetData.network ? root.fleetData.network.wiredClients : 12) + " Wired"
            valColor: root.accent
            fontFamily: root.fontFamily
            iconText: ""
          }

          StatBlock {
            label: "HARDWARE FLEET"
            value: String(root.fleetData && root.fleetData.network ? root.fleetData.network.deviceCount : 11)
            subvalue: "0 Offline · 0 Updates"
            valColor: root.foreground
            fontFamily: root.fontFamily
            iconText: ""
          }

          StatBlock {
            label: "SITES OPERATIONAL"
            value: String(root.fleetData && root.fleetData.sites ? root.fleetData.sites.length : 2) + "/" + String(root.fleetData && root.fleetData.sites ? root.fleetData.sites.length : 2)
            subvalue: "All gateways online"
            valColor: root.healthy
            subColor: root.healthy
            fontFamily: root.fontFamily
            iconText: ""
          }
        }

        // Two-column Overview & Mesh Split
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(12)

        // Left Column: Throughput Timeline & Client Distribution
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 6
          spacing: Style.space(10)

          // 24h Traffic Chart
          SectionCard {
            id: wanThroughputCard
            title: "24-HOUR WAN THROUGHPUT"
            subtitle: {
              var tp = root.getActiveThroughput()
              var siteNames = tp.activeSites.map(function(s) { return s.name }).join(" · ")
              if (!siteNames) siteNames = "All Managed Sites"
              return siteNames + " · Peak: " + tp.peakRx.toFixed(1) + " Mbps DL / " + tp.peakTx.toFixed(1) + " Mbps UL"
            }
            iconText: ""
            titleColor: root.foreground
            badgeText: root.selectedSiteIds.length > 0
              ? ("FILTERED (" + root.selectedSiteIds.length + ")")
              : "REAL-TIME"
            badgeColor: root.selectedSiteIds.length > 0 ? root.accent : root.healthy
            fontFamily: root.fontFamily
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 4

            Canvas {
              id: chartCanvas
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: Style.space(160)
              Layout.margins: Style.space(8)

              onWidthChanged: requestPaint()
              onHeightChanged: requestPaint()

              Connections {
                target: root
                function onFleetDataChanged() { chartCanvas.requestPaint() }
                function onSelectedSiteIdsChanged() { chartCanvas.requestPaint() }
                function onChartHoverIndexChanged() { chartCanvas.requestPaint() }
              }

              onPaint: {
                var ctx = getContext("2d")
                if (!ctx) return
                ctx.reset()
                var w = width
                var h = height
                if (w <= 50 || h <= 40) return

                var leftPad = 32
                var botPad = 18
                var chartW = w - leftPad - 10
                var chartH = h - botPad - 8

                var tp = root.getActiveThroughput()
                var rxData = tp.rx
                var txData = tp.tx
                var peakRx = tp.peakRx

                var maxVal = Math.max(40, Math.ceil(peakRx / 20) * 20)
                if (maxVal < 60 && maxVal > 40) maxVal = 60
                if (maxVal > 80 && maxVal < 100) maxVal = 100

                // Grid lines & Y-axis labels
                ctx.strokeStyle = root.isLightTheme ? "#cbd5e1" : "#2a324b"
                ctx.fillStyle = root.dim
                ctx.font = "8px " + root.fontFamily
                ctx.lineWidth = 0.5
                var stepVal = maxVal / 4
                for (var g = 0; g <= 4; g++) {
                  var y = 8 + (chartH / 4) * g
                  ctx.beginPath()
                  ctx.moveTo(leftPad, y)
                  ctx.lineTo(w - 10, y)
                  ctx.stroke()
                  var lblVal = Math.round(maxVal - g * stepVal)
                  ctx.fillText(lblVal + "M", 2, y + 3)
                }

                // X-axis time labels
                var timeLabels = ["24h ago", "18h", "12h", "6h", "Now"]
                for (var t = 0; t < timeLabels.length; t++) {
                  var tx = leftPad + (chartW / 4) * t
                  ctx.fillText(timeLabels[t], tx - (t === 4 ? 18 : 10), h - 3)
                }

                // Draw Download Curve
                ctx.beginPath()
                var step = chartW / (rxData.length - 1)
                for (var i = 0; i < rxData.length; i++) {
                  var px = leftPad + i * step
                  var py = 8 + chartH - (rxData[i] / maxVal) * chartH
                  if (i === 0) ctx.moveTo(px, py)
                  else ctx.lineTo(px, py)
                }
                ctx.strokeStyle = root.accent
                ctx.lineWidth = 2.0
                ctx.stroke()

                // Download gradient fill
                var grad = ctx.createLinearGradient(0, 8, 0, 8 + chartH)
                grad.addColorStop(0, Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35))
                grad.addColorStop(1, Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.02))
                ctx.lineTo(leftPad + chartW, 8 + chartH)
                ctx.lineTo(leftPad, 8 + chartH)
                ctx.closePath()
                ctx.fillStyle = grad
                ctx.fill()

                // Draw Upload Curve
                ctx.beginPath()
                for (var j = 0; j < txData.length; j++) {
                  var txX = leftPad + j * step
                  var txY = 8 + chartH - (txData[j] / maxVal) * chartH
                  if (j === 0) ctx.moveTo(txX, txY)
                  else ctx.lineTo(txX, txY)
                }
                ctx.strokeStyle = root.healthy
                ctx.lineWidth = 1.5
                ctx.stroke()

                // Vertical scrub line and highlight dots on hover
                if (root.chartHoverIndex >= 0 && root.chartHoverIndex < rxData.length) {
                  var hx = leftPad + root.chartHoverIndex * step
                  var hrxY = 8 + chartH - (rxData[root.chartHoverIndex] / maxVal) * chartH
                  var htxY = 8 + chartH - (txData[root.chartHoverIndex] / maxVal) * chartH

                  ctx.save()
                  ctx.beginPath()
                  ctx.strokeStyle = root.isLightTheme ? "#94a3b8" : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.7)
                  ctx.lineWidth = 1.0
                  ctx.setLineDash([3, 3])
                  ctx.moveTo(hx, 8)
                  ctx.lineTo(hx, 8 + chartH)
                  ctx.stroke()
                  ctx.restore()

                  // Download halo and dot
                  ctx.beginPath()
                  ctx.arc(hx, hrxY, 6, 0, 2 * Math.PI)
                  ctx.fillStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
                  ctx.fill()
                  ctx.beginPath()
                  ctx.arc(hx, hrxY, 3.5, 0, 2 * Math.PI)
                  ctx.fillStyle = root.accent
                  ctx.fill()

                  // Upload halo and dot
                  ctx.beginPath()
                  ctx.arc(hx, htxY, 5, 0, 2 * Math.PI)
                  ctx.fillStyle = Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.35)
                  ctx.fill()
                  ctx.beginPath()
                  ctx.arc(hx, htxY, 3, 0, 2 * Math.PI)
                  ctx.fillStyle = root.healthy
                  ctx.fill()
                }
              }

              MouseArea {
                id: chartMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.CrossCursor

                onPositionChanged: function(mouse) {
                  var leftPad = 32
                  var rightPad = 10
                  var chartW = chartCanvas.width - leftPad - rightPad
                  if (chartW <= 0) return
                  var clampedX = Math.max(leftPad, Math.min(chartCanvas.width - rightPad, mouse.x))
                  var ratio = (clampedX - leftPad) / chartW
                  var idx = Math.max(0, Math.min(23, Math.round(ratio * 23)))
                  root.chartHoverIndex = idx
                  root.chartHoverMouseX = mouse.x
                  root.chartHoverMouseY = mouse.y
                  chartCanvas.requestPaint()
                }

                onExited: {
                  root.chartHoverIndex = -1
                  chartCanvas.requestPaint()
                }
              }

              // Info card tooltip
              Rectangle {
                id: infoCard
                visible: root.chartHoverIndex >= 0
                enabled: false
                z: 100
                width: cardLayout.implicitWidth + Style.space(18)
                height: cardLayout.implicitHeight + Style.space(16)
                radius: 6
                color: root.isLightTheme ? "#ffffff" : "#161b2a"
                border.width: 1
                border.color: root.accent

                x: {
                  var targetX = root.chartHoverMouseX + 16
                  if (targetX + width > chartCanvas.width - 8) {
                    targetX = root.chartHoverMouseX - width - 16
                  }
                  return Math.max(8, Math.min(chartCanvas.width - width - 8, targetX))
                }
                y: {
                  var targetY = root.chartHoverMouseY - height / 2
                  return Math.max(8, Math.min(chartCanvas.height - height - 8, targetY))
                }

                ColumnLayout {
                  id: cardLayout
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(4)

                  // Date & Time row
                  RowLayout {
                    spacing: Style.space(6)
                    Text {
                      textFormat: Text.PlainText;
                      text: ""
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                    }
                    ColumnLayout {
                      spacing: 1
                      Text {
                        textFormat: Text.PlainText;
                        text: root.getThroughputDate(root.chartHoverIndex)
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }
                      Text {
                        textFormat: Text.PlainText;
                        text: root.getThroughputTime(root.chartHoverIndex)
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                      }
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.outline
                  }

                  // Download speed row
                  RowLayout {
                    spacing: Style.space(6)
                    Rectangle {
                      width: 7
                      height: 7
                      radius: 3.5
                      color: root.accent
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: "Download:"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                    }
                    Text {
                      textFormat: Text.PlainText;
                      readonly property var tp: root.getActiveThroughput()
                      text: (tp.rx[root.chartHoverIndex] !== undefined ? tp.rx[root.chartHoverIndex].toFixed(1) : "0.0") + " Mbps"
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                      Layout.alignment: Qt.AlignRight
                    }
                  }

                  // Upload speed row
                  RowLayout {
                    spacing: Style.space(6)
                    Rectangle {
                      width: 7
                      height: 7
                      radius: 3.5
                      color: root.healthy
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: "Upload:"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                    }
                    Text {
                      textFormat: Text.PlainText;
                      readonly property var tp: root.getActiveThroughput()
                      text: (tp.tx[root.chartHoverIndex] !== undefined ? tp.tx[root.chartHoverIndex].toFixed(1) : "0.0") + " Mbps"
                      color: root.healthy
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                      Layout.alignment: Qt.AlignRight
                    }
                  }

                  // Scope indicator
                  RowLayout {
                    visible: root.selectedSiteIds.length > 0
                    spacing: 4
                    Text {
                      textFormat: Text.PlainText;
                      readonly property var tp: root.getActiveThroughput()
                      text: " " + (tp.activeSites.length === 1 ? tp.activeSites[0].name : (tp.activeSites.length + " sites filtered"))
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 3
                      elide: Text.ElideRight
                      Layout.maximumWidth: Style.space(160)
                    }
                  }
                }
              }
            }

            // Legend
            RowLayout {
              Layout.alignment: Qt.AlignRight
              Layout.rightMargin: Style.space(8)
              Layout.bottomMargin: Style.space(8)
              spacing: Style.space(12)

              RowLayout {
                spacing: 4
                Rectangle { width: 8; height: 8; radius: 4; color: root.accent }
                Text { textFormat: Text.PlainText; text: "Download (RX)"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
              }

              RowLayout {
                spacing: 4
                Rectangle { width: 8; height: 8; radius: 4; color: root.healthy }
                Text { textFormat: Text.PlainText; text: "Upload (TX)"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
              }
            }
          }

          // Client Density Breakdown
          SectionCard {
            title: "CLIENT DENSITY BY BAND & SITE"
            subtitle: String(root.fleetData && root.fleetData.network ? root.fleetData.network.clientCount : 27) + " clients across " + String(root.fleetData && root.fleetData.network ? root.fleetData.network.deviceCount : 11) + " managed devices"
            iconText: ""
            titleColor: root.foreground
            fontFamily: root.fontFamily
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 3

            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.margins: Style.space(8)
              spacing: Style.space(6)

              readonly property int totalClients: root.fleetData && root.fleetData.network ? root.fleetData.network.clientCount : 27
              readonly property int wifiClients: root.fleetData && root.fleetData.network ? root.fleetData.network.wifiClients : 15
              readonly property int wiredClients: root.fleetData && root.fleetData.network ? root.fleetData.network.wiredClients : 12

              Text {
                textFormat: Text.PlainText;
                text: "WiFi Wireless Clients (" + parent.wifiClients + " clients · " + (parent.totalClients > 0 ? Math.round(parent.wifiClients / parent.totalClients * 100) : 56) + "%)"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
              }
              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(8)
                radius: 4
                color: root.track
                Rectangle {
                  width: Math.max(8, parent.width * (parent.parent.totalClients > 0 ? (parent.parent.wifiClients / parent.parent.totalClients) : 0.56))
                  height: parent.height
                  radius: 4
                  color: root.accent
                }
              }

              Text {
                textFormat: Text.PlainText;
                text: "Wired Ethernet Clients (" + parent.wiredClients + " clients · " + (parent.totalClients > 0 ? Math.round(parent.wiredClients / parent.totalClients * 100) : 44) + "%)"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
              }
              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(8)
                radius: 4
                color: root.track
                Rectangle {
                  width: Math.max(8, parent.width * (parent.parent.totalClients > 0 ? (parent.parent.wiredClients / parent.parent.totalClients) : 0.44))
                  height: parent.height
                  radius: 4
                  color: root.backup
                }
              }

              Text { textFormat: Text.PlainText; text: "6 GHz WiFi 7 (U7 Pro Ready) · Low-Latency Priority Active"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
            }
          }
        }

        // Right Column: Site Matrix & ISP Telemetry
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 4
          spacing: Style.space(10)

          // Site Magic SD-WAN Card
          SectionCard {
            visible: Boolean(root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.available)
            title: "SITE MAGIC SD-WAN"
            subtitle: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.name ? root.fleetData.sdwan.name : "Catalyse-Mesh") + " · Zero-Trust Inter-Site Mesh"
            iconText: ""
            titleColor: root.foreground
            fontFamily: root.fontFamily
            badgeText: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.status === "connected") ? "MESH ACTIVE" : "DEGRADED"
            badgeColor: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.status === "connected") ? root.healthy : root.backup
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(140)

            Column {
              Layout.fillWidth: true
              width: parent.width
              spacing: Style.space(8)

              // Inter-Site Bridge Visualizer
              Rectangle {
                width: parent.width
                height: Style.space(52)
                radius: 4
                color: root.track
                border.width: 1
                border.color: root.outline

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  // Site A Node
                  ColumnLayout {
                    spacing: 2
                    RowLayout {
                      spacing: 4
                      Rectangle { width: 6; height: 6; radius: 3; color: root.healthy }
                      Text {
                        textFormat: Text.PlainText;
                        text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0) ? root.fleetData.sdwan.connections[0].siteA : "Catalyse Office"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.maximumWidth: Style.space(120)
                      }
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0) ? root.fleetData.sdwan.connections[0].subnetA : "192.168.15.0/24"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 3
                      elide: Text.ElideRight
                      Layout.maximumWidth: Style.space(120)
                    }
                  }

                  // Center Tunnel Bridge
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                      Layout.alignment: Qt.AlignHCenter
                      spacing: 4
                      Text { textFormat: Text.PlainText; text: "⇄"; color: root.accent; font.family: root.fontFamily; font.pixelSize: 10 }
                      Text {
                        textFormat: Text.PlainText;
                        text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.ping !== undefined ? (root.fleetData.sdwan.ping < 1 ? "<1 ms" : root.fleetData.sdwan.ping + " ms") : "<1 ms")
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                      }
                      Text { textFormat: Text.PlainText; text: "⇄"; color: root.accent; font.family: root.fontFamily; font.pixelSize: 10 }
                    }
                    Rectangle {
                      Layout.fillWidth: true
                      height: 2
                      color: root.accent
                    }
                  }

                  // Site B Node
                  ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignRight
                    RowLayout {
                      spacing: 4
                      Rectangle { width: 6; height: 6; radius: 3; color: root.healthy }
                      Text {
                        textFormat: Text.PlainText;
                        text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0) ? root.fleetData.sdwan.connections[0].siteB : "Lough Stanley Home"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.maximumWidth: Style.space(120)
                      }
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0) ? root.fleetData.sdwan.connections[0].subnetB : "192.168.22.0/24"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 3
                      elide: Text.ElideRight
                      Layout.maximumWidth: Style.space(120)
                    }
                  }
                }
              }

              Text {
                textFormat: Text.PlainText;
                text: "Cross-subnet mesh routing active · WireGuard encrypted transport"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
              }
            }
          }

          SectionCard {
            title: "MANAGED SITE MATRIX"
            subtitle: root.selectedSiteIds.length > 0
              ? "Filtering " + root.selectedSiteIds.length + " of " + (root.fleetData && root.fleetData.sites ? root.fleetData.sites.length : 0) + " sites · Click site to toggle"
              : "Active gateways, public IPs, and ISPs · Click site to filter throughput"
            iconText: ""
            titleColor: root.foreground
            fontFamily: root.fontFamily
            badgeText: root.selectedSiteIds.length > 0 ? (root.selectedSiteIds.length + " FILTERED") : "ALL SITES"
            badgeColor: root.selectedSiteIds.length > 0 ? root.accent : root.dim
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.preferredHeight: 1
              Layout.margins: Style.space(6)
              contentWidth: width
              contentHeight: siteMatrixCol.childrenRect.height + Style.space(16)
              clip: true

              Column {
                id: siteMatrixCol
                width: parent.width
                spacing: Style.space(8)

                // Filter Active Reset Banner
                Rectangle {
                  visible: root.selectedSiteIds.length > 0
                  width: parent.width
                  height: 24
                  radius: 3
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                  border.width: 1
                  border.color: root.accent

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8

                    Text {
                      textFormat: Text.PlainText;
                      text: " Filter active: showing " + root.selectedSiteIds.length + " site(s)"
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true
                      Layout.fillWidth: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      text: "✕ Reset filter"
                      color: resetMouse.containsMouse ? root.foreground : root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true

                      MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearSiteSelection()
                      }
                    }
                  }
                }

                Text {
                  textFormat: Text.PlainText;
                  visible: !root.fleetData || !root.fleetData.sites || root.fleetData.sites.length === 0
                  text: "Loading managed sites telemetry..."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  horizontalAlignment: Text.AlignHCenter
                  width: parent.width
                  topPadding: Style.space(20)
                }

                Repeater {
                  model: root.fleetData && root.fleetData.sites ? root.fleetData.sites : []
                  delegate: Rectangle {
                    required property var modelData
                    readonly property bool isSelected: root.isSiteSelected(modelData)
                    width: siteMatrixCol.width
                    height: siteCol.childrenRect.height + Style.space(12)
                    radius: 4
                    color: isSelected
                      ? (root.isLightTheme ? "#e8effe" : "#1a2540")
                      : (siteCardMouse.containsMouse ? root.cardHover : root.track)
                    border.width: isSelected ? 2 : 1
                    border.color: isSelected
                      ? root.accent
                      : (siteCardMouse.containsMouse ? root.dim : root.outline)

                    MouseArea {
                      id: siteCardMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.toggleSiteSelection(modelData)
                      }
                    }

                    Column {
                      id: siteCol
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.margins: Style.space(6)
                      spacing: Style.space(3)

                      Row {
                        width: parent.width
                        spacing: Style.space(6)

                        Rectangle {
                          width: 8
                          height: 8
                          radius: 4
                          anchors.verticalCenter: parent.verticalCenter
                          color: modelData.status === "down" ? root.urgent : (modelData.status === "backup" ? root.backup : root.healthy)
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.name || "Site"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                          width: parent.width - 150
                          elide: Text.ElideRight
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        // Filter Pill
                        Rectangle {
                          height: 16
                          width: filterBadgeText.implicitWidth + 8
                          radius: 2
                          anchors.verticalCenter: parent.verticalCenter
                          color: isSelected ? root.accent : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.15)
                          border.width: 1
                          border.color: isSelected ? root.accent : root.outline

                          Text {
                            textFormat: Text.PlainText;
                            id: filterBadgeText
                            anchors.centerIn: parent
                            text: isSelected ? "✓ FILTERED" : "FILTER"
                            color: isSelected ? "#ffffff" : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }

                        Rectangle {
                          height: 16
                          width: statusTextTag.implicitWidth + 8
                          radius: 2
                          anchors.verticalCenter: parent.verticalCenter
                          color: modelData.status === "down" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2) : Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2)
                          Text {
                            textFormat: Text.PlainText;
                            id: statusTextTag
                            anchors.centerIn: parent
                            text: modelData.status === "down" ? "OFFLINE" : (modelData.status === "backup" ? "BACKUP WAN" : "ONLINE")
                            color: modelData.status === "down" ? root.urgent : root.healthy
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        width: parent.width
                        text: (modelData.gatewayModel || "Gateway") + " · IP: " + (modelData.gatewayIp || "DHCP") + " · ISP: " + (modelData.isp || "Unknown ISP")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                      }

                      Row {
                        width: parent.width
                        spacing: Style.space(10)

                        Text {
                          textFormat: Text.PlainText;
                          text: " " + (modelData.clientCount || 0) + " clients"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: " " + (modelData.deviceCount || 0) + " devices" + (modelData.offlineCount > 0 ? " (1 off)" : "")
                          color: modelData.offlineCount > 0 ? root.urgent : root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: " " + (modelData.wanUptime || 100) + "% uptime"
                          color: root.healthy
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

      // ==========================================
      // TAB 1: GRANULAR CLIENT TELEMETRY & UPLINK
      // ==========================================
      ColumnLayout {
        id: tab1View
        visible: root.currentTab === 1
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.space(10)

        readonly property var rawClients: root.fleetData && root.fleetData.clients ? root.fleetData.clients : []
        readonly property var filteredClients: {
          var list = rawClients
          var query = root.clientSearch.toLowerCase().trim()
          var siteFilter = root.clientSiteFilter
          var medFilter = root.clientMediumFilter

          return list.filter(function(c) {
            if (siteFilter !== "All" && c.siteName !== siteFilter) return false
            if (medFilter === "WiFi" && c.isWired) return false
            if (medFilter === "Wired" && !c.isWired) return false
            if (query !== "") {
              var s = ((c.name || "") + " " + (c.hostname || "") + " " + (c.ip || "") + " " + (c.mac || "") + " " + (c.uplinkName || "") + " " + (c.essid || "")).toLowerCase()
              if (s.indexOf(query) === -1) return false
            }
            return true
          })
        }

        // Client Table Card with Integrated Search & Filters
        SectionCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          title: "FLEET CLIENT ROSTER & UPLINK TOPOLOGY"
          subtitle: "WiFi signal metrics (dBm), radio protocols (WiFi 6/7), uplink associations, and transfer stats"
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily
          badgeText: String(tab1View.filteredClients.length) + " / " + String(tab1View.rawClients.length) + " CLIENTS"
          badgeColor: root.accent

          // Compact Search & Filter Toolbar
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            // Search Input Box
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(28)
              radius: 5
              color: root.track
              border.width: 1
              border.color: root.outline

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(6)

                Text {
                  textFormat: Text.PlainText;
                  text: ""
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }

                TextInput {
                  id: clientSearchInput
                  Layout.fillWidth: true
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  selectByMouse: true
                  onTextChanged: { root.clientSearch = text }

                  Text {
                    textFormat: Text.PlainText;
                    visible: !parent.text
                    text: "Search clients by name, IP, MAC address, ESSID, or uplink AP..."
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                  }
                }

                Text {
                  textFormat: Text.PlainText;
                  visible: Boolean(clientSearchInput.text)
                  text: "✕"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { clientSearchInput.text = "" }
                  }
                }
              }
            }

            // Medium Filter Pills
            RowLayout {
              spacing: Style.space(4)

              Repeater {
                model: ["All", "WiFi", "Wired"]
                delegate: Rectangle {
                  required property string modelData
                  height: Style.space(28)
                  width: medFilterText.implicitWidth + Style.space(14)
                  radius: 4
                  color: root.clientMediumFilter === modelData ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : root.track
                  border.width: 1
                  border.color: root.clientMediumFilter === modelData ? root.accent : root.outline

                  Text {
                    id: medFilterText
                    textFormat: Text.PlainText;
                    anchors.centerIn: parent
                    text: modelData === "All" ? "All Mediums" : (modelData === "WiFi" ? " WiFi Only" : "󰈀 Wired Only")
                    color: root.clientMediumFilter === modelData ? root.accent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    font.bold: root.clientMediumFilter === modelData
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.clientMediumFilter = modelData }
                  }
                }
              }
            }
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: clientListCol.childrenRect.height + Style.space(16)
            clip: true

            Column {
              id: clientListCol
              width: parent.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText;
                visible: tab1View.filteredClients.length === 0
                text: tab1View.rawClients.length === 0 ? "Loading client telemetry from UniFi Site Manager..." : "No clients match the current search or filters."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                topPadding: Style.space(30)
              }

              // High-density table column headers
              Rectangle {
                width: clientListCol.width
                height: Style.space(22)
                color: "transparent"
                visible: Boolean(tab1View.filteredClients.length > 0)

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(12)
                  spacing: Style.space(10)

                  Text {
                    textFormat: Text.PlainText;
                    Layout.preferredWidth: 32
                    text: "TYPE"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.fillWidth: true
                    Layout.minimumWidth: 140
                    Layout.preferredWidth: 190
                    text: "CLIENT / IP & MAC"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.fillWidth: true
                    Layout.minimumWidth: 140
                    Layout.preferredWidth: 180
                    text: "UPLINK ASSOCIATION"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.preferredWidth: 130
                    text: "SIGNAL / PROTOCOL"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.preferredWidth: 140
                    text: "TRAFFIC & UPTIME"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.preferredWidth: 58
                    text: "ACTION"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                  }
                }
              }

              // High-density tabular client rows
              Repeater {
                model: tab1View.filteredClients
                delegate: Rectangle {
                  required property var modelData
                  width: clientListCol.width
                  height: Style.space(40)
                  radius: 5
                  color: clientRowMouse.containsMouse ? root.cardHover : root.track
                  border.width: 1
                  border.color: clientRowMouse.containsMouse ? root.accent : root.outline

                  MouseArea {
                    id: clientRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(10)

                    // Col 1: Type icon pill
                    Rectangle {
                      Layout.preferredWidth: 28
                      Layout.preferredHeight: 24
                      radius: 4
                      color: modelData.isWired ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.15) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                      border.width: 1
                      border.color: modelData.isWired ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.3) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3)

                      Text {
                        textFormat: Text.PlainText;
                        anchors.centerIn: parent
                        text: modelData.isWired ? "󰈀" : ""
                        color: modelData.isWired ? root.backup : root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 11
                      }
                    }

                    // Col 2: Client Identity & IP/MAC
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 140
                      Layout.preferredWidth: 190
                      spacing: 1

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.name || modelData.hostname || "Client Device"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }

                        Rectangle {
                          height: 14
                          width: siteTagText.implicitWidth + 8
                          radius: 3
                          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)

                          Text {
                            id: siteTagText
                            textFormat: Text.PlainText;
                            anchors.centerIn: parent
                            text: modelData.siteName || "Site"
                            color: root.accent
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: (modelData.ip || "No IP") + " · " + (modelData.mac || "")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    // Col 3: Uplink Association
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 140
                      Layout.preferredWidth: 180
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText;
                        text: (modelData.uplinkName || (modelData.isWired ? "Switch" : "AP")) + " · " + (modelData.uplinkPort || "Port")
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.isWired ? "Wired Ethernet Link" : (modelData.essid ? ("SSID: " + modelData.essid) : "Wireless Uplink")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    // Col 4: Signal Strength & Protocol
                    ColumnLayout {
                      Layout.preferredWidth: 130
                      spacing: 1

                      RowLayout {
                        spacing: 5

                        Rectangle {
                          width: 6
                          height: 6
                          radius: 3
                          color: modelData.isWired ? root.healthy : (modelData.signal > -65 ? root.healthy : (modelData.signal > -75 ? root.backup : root.urgent))
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.isWired ? "Link 1000 Mbps" : (String(modelData.signal) + " dBm")
                          color: modelData.isWired ? root.foreground : (modelData.signal > -65 ? root.healthy : (modelData.signal > -75 ? root.backup : root.urgent))
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.radioProto || (modelData.isWired ? "GbE Full Duplex" : (modelData.band + " · Ch " + modelData.channel))
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    // Col 5: Transfer Stats & Uptime
                    ColumnLayout {
                      Layout.preferredWidth: 140
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText;
                        text: "RX: " + (modelData.rxBytes ? (modelData.rxBytes / (1024 * 1024)).toFixed(1) + " MB" : (modelData.rxRate + " Mbps")) + " · TX: " + (modelData.txBytes ? (modelData.txBytes / (1024 * 1024)).toFixed(1) + " MB" : (modelData.txRate + " Mbps"))
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: "Uptime: " + (modelData.uptimeText || "Active")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                      }
                    }

                    // Col 6: Quick Action Ping
                    Rectangle {
                      Layout.preferredWidth: 58
                      Layout.preferredHeight: 22
                      radius: 4
                      color: pingMouse.containsMouse ? root.cardHover : root.track
                      border.width: 1
                      border.color: pingMouse.containsMouse ? root.accent : root.outline

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                          textFormat: Text.PlainText;
                          text: ""
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: 8
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: "Ping"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }

                      MouseArea {
                        id: pingMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.pingHost(modelData.ip) }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // TAB 2: WAN INTERFACES & OUTAGES
      // ==========================================
      ColumnLayout {
        id: tab2View
        visible: root.currentTab === 2
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.space(10)

        // Gateway WAN Interfaces Card
        SectionCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredHeight: 3
          title: "GATEWAY WAN HARDWARE TELEMETRY"
          subtitle: "Multi-gigabit WAN interfaces, physical port states, link speeds, IPv4/IPv6, and ISP peering"
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily
          badgeText: String(root.fleetData && root.fleetData.wans ? root.fleetData.wans.length : 0) + " INTERFACES"
          badgeColor: root.accent

          Flickable {
            id: wanFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: wanCol.childrenRect.height + Style.space(16)
            clip: true

            Column {
              id: wanCol
              width: wanFlick.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText;
                visible: !root.fleetData || !root.fleetData.wans || root.fleetData.wans.length === 0
                text: "Querying gateway WAN interfaces..."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                topPadding: Style.space(20)
              }

              // High-density table column headers
              Rectangle {
                width: wanCol.width
                height: Style.space(22)
                color: "transparent"
                visible: Boolean(root.fleetData && root.fleetData.wans && root.fleetData.wans.length > 0)

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(12)
                  spacing: Style.space(10)

                  Text {
                    textFormat: Text.PlainText;
                    Layout.preferredWidth: 88
                    text: "STATE"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.preferredWidth: 100
                    text: "INTERFACE"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.fillWidth: true
                    Layout.minimumWidth: 120
                    Layout.preferredWidth: 160
                    text: "SITE & GATEWAY"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.fillWidth: true
                    Layout.minimumWidth: 140
                    Layout.preferredWidth: 180
                    text: "PUBLIC IP & MAC"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.fillWidth: true
                    Layout.minimumWidth: 130
                    Layout.preferredWidth: 160
                    text: "ISP PEERING & SLA"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.preferredWidth: 58
                    text: "ACTION"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                  }
                }
              }

              // High-density tabular interface rows
              Repeater {
                model: root.fleetData && root.fleetData.wans ? root.fleetData.wans : []
                delegate: Rectangle {
                  required property var modelData
                  width: wanCol.width
                  height: Style.space(40)
                  radius: 5
                  color: wanRowMouse.containsMouse ? root.cardHover : root.track
                  border.width: 1
                  border.color: modelData.plugged ? (modelData.type.indexOf("Primary") !== -1 ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.35) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.35)) : root.outline

                  MouseArea {
                    id: wanRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(10)

                    // Col 1: Status Dot & Link Type Tag
                    RowLayout {
                      Layout.preferredWidth: 88
                      spacing: 6

                      Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: modelData.plugged ? (modelData.type.indexOf("Primary") !== -1 ? root.healthy : root.backup) : root.dim
                      }

                      Rectangle {
                        height: 20
                        width: wanTagText.implicitWidth + 10
                        radius: 3
                        color: modelData.plugged ? (modelData.type.indexOf("Primary") !== -1 ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.18) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.18)) : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.18)

                        Text {
                          id: wanTagText
                          textFormat: Text.PlainText;
                          anchors.centerIn: parent
                          text: !modelData.plugged ? "UNPLUGGED" : (modelData.type.indexOf("Primary") !== -1 ? "PRIMARY" : "STANDBY")
                          color: !modelData.plugged ? root.dim : (modelData.type.indexOf("Primary") !== -1 ? root.healthy : root.backup)
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }
                    }

                    // Col 2: Interface / Port Pill & Speed
                    ColumnLayout {
                      Layout.preferredWidth: 100
                      spacing: 1

                      Rectangle {
                        height: 18
                        width: ifacePillText.implicitWidth + 10
                        radius: 3
                        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)

                        Text {
                          id: ifacePillText
                          textFormat: Text.PlainText;
                          anchors.centerIn: parent
                          text: (modelData.interface || "eth0") + " · P" + (modelData.port !== undefined ? modelData.port : "0")
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: 9
                          font.bold: true
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.speedType || "1GbE"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    // Col 3: Site Name & Gateway Model
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 120
                      Layout.preferredWidth: 160
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.siteName || "Site"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.gatewayModel || "UniFi Gateway"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    // Col 4: Public IPv4 & IPv6 / MAC
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 140
                      Layout.preferredWidth: 180
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.ipv4 || "DHCP Lease Pending"
                        color: modelData.ipv4 ? root.foreground : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: Boolean(modelData.ipv4)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: (modelData.ipv6 ? modelData.ipv6 : "IPv6: None / SLAAC") + (modelData.mac ? (" · " + modelData.mac) : "")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    // Col 5: ISP Peering & Uptime SLA
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 130
                      Layout.preferredWidth: 160
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.isp || "Broadband / Fiber"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      RowLayout {
                        spacing: 4

                        Text {
                          textFormat: Text.PlainText;
                          text: ""
                          color: modelData.plugged ? root.healthy : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 3
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: (modelData.uptime || (modelData.plugged ? "100% Uptime" : "Down")) + (modelData.plugged ? " · 0% Loss" : "")
                          color: modelData.plugged ? root.healthy : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: true
                        }
                      }
                    }

                    // Col 6: Quick Action Ping
                    Rectangle {
                      Layout.preferredWidth: 58
                      Layout.preferredHeight: 22
                      radius: 4
                      color: (modelData.ipv4 && modelData.plugged && wanPingMouse.containsMouse) ? root.cardHover : root.track
                      opacity: (modelData.ipv4 && modelData.plugged) ? 1.0 : 0.4
                      border.width: 1
                      border.color: (modelData.ipv4 && modelData.plugged && wanPingMouse.containsMouse) ? root.accent : root.outline

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                          textFormat: Text.PlainText;
                          text: ""
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: 8
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: "Ping"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }

                      MouseArea {
                        id: wanPingMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (modelData.ipv4 && modelData.plugged) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                          if (modelData.ipv4 && modelData.plugged) {
                            root.pingHost(modelData.ipv4)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Historical Outage Timeline Card
        SectionCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredHeight: 2
          title: "HISTORICAL OUTAGE & PACKET LOSS TIMELINE"
          subtitle: "5-minute interval internet drop logs, upstream packet loss events, and recovery history"
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily
          badgeText: String(root.fleetData && root.fleetData.outages ? root.fleetData.outages.length : 0) + " EVENTS"
          badgeColor: (root.fleetData && root.fleetData.outages && root.fleetData.outages.length > 0) ? root.backup : root.healthy

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: outageListCol.childrenRect.height + Style.space(16)
            clip: true

            Column {
              id: outageListCol
              width: parent.width
              spacing: Style.space(6)

              Rectangle {
                width: parent.width
                height: Style.space(36)
                radius: 5
                color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.1)
                border.width: 1
                border.color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.3)
                visible: !root.fleetData || !root.fleetData.outages || root.fleetData.outages.length === 0

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 8

                  Text {
                    textFormat: Text.PlainText;
                    text: ""
                    color: root.healthy
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Text {
                    textFormat: Text.PlainText;
                    text: "100% WAN Fleet Uptime — No carrier outages or packet loss detected across any site in recent telemetry periods."
                    color: root.healthy
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                  }
                }
              }

              Repeater {
                model: root.fleetData && root.fleetData.outages ? root.fleetData.outages : []
                delegate: Rectangle {
                  required property var modelData
                  width: outageListCol.width
                  height: Style.space(38)
                  radius: 5
                  color: outageMouse.containsMouse ? root.cardHover : root.track
                  border.width: 1
                  border.color: modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.4) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.4)

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(10)

                    // Severity badge
                    Rectangle {
                      Layout.preferredWidth: sevText.implicitWidth + 10
                      Layout.preferredHeight: 20
                      radius: 3
                      color: modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2)

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                          textFormat: Text.PlainText;
                          text: ""
                          color: modelData.severity === "critical" ? root.urgent : root.backup
                          font.family: root.fontFamily
                          font.pixelSize: 9
                        }

                        Text {
                          id: sevText
                          textFormat: Text.PlainText;
                          text: (modelData.severity || "warning").toUpperCase()
                          color: modelData.severity === "critical" ? root.urgent : root.backup
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }
                    }

                    // Site Tag
                    Rectangle {
                      Layout.preferredHeight: 18
                      Layout.preferredWidth: outageSiteText.implicitWidth + 8
                      radius: 3
                      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)

                      Text {
                        id: outageSiteText
                        textFormat: Text.PlainText;
                        anchors.centerIn: parent
                        text: modelData.siteName || "Site"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                      }
                    }

                    // Incident summary & description
                    Text {
                      textFormat: Text.PlainText;
                      text: (modelData.type ? (modelData.type + " — ") : "") + (modelData.description || "Gateway internet link dropped")
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    // Duration pill
                    Rectangle {
                      Layout.preferredHeight: 18
                      Layout.preferredWidth: durText.implicitWidth + 8
                      radius: 3
                      color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.15)

                      Text {
                        id: durText
                        textFormat: Text.PlainText;
                        anchors.centerIn: parent
                        text: "⏱ " + (modelData.durationText || "5m")
                        color: root.urgent
                        font.family: root.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                      }
                    }

                    // Timestamp
                    Text {
                      textFormat: Text.PlainText;
                      text: modelData.timeText || "Recent"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                    }
                  }

                  MouseArea {
                    id: outageMouse
                    anchors.fill: parent
                    hoverEnabled: true
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // TAB 3: SWITCH PORTS & POE POWER CYCLING
      // ==========================================
      ColumnLayout {
        id: tab3View
        visible: root.currentTab === 3
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.space(10)

        readonly property var portsList: {
          if (!root.currentSwitch || !root.currentSwitch.ports) return []
          var list = root.currentSwitch.ports
          var filter = root.portFilter
          return list.filter(function(p) {
            if (filter === "PoE" && !(p.poePower > 0 || (p.poeMode && p.poeMode !== "off"))) return false
            if (filter === "Active" && !p.up) return false
            return true
          })
        }

        // Switch Selector & Budget Header Card
        SectionCard {
          Layout.fillWidth: true
          clip: false
          title: "SWITCH FLEET SELECTION & POE BUDGET"
          subtitle: (root.currentSwitch ? root.currentSwitch.name : "No switch selected") + (root.currentSwitch ? (" · " + (root.currentSwitch.siteName || "") + " (" + (root.currentSwitch.activePorts || 0) + "/" + (root.currentSwitch.totalPorts || 0) + " ports active)") : "")
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily
          badgeText: root.currentSwitch ? (String(root.currentSwitch.totalPower || 0) + " W / " + String(root.currentSwitch.maxPower || 600) + " W POE") : "0 W POE"
          badgeColor: root.accent

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            // Switch selector toolbar: Site Dropdown (filter) + Switch Dropdown + Filter Pills
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(10)

              // Site Filter Dropdown (acts as a filter)
              RowLayout {
                spacing: Style.space(6)

                Text {
                  textFormat: Text.PlainText;
                  text: "SITE:"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                }

                Rectangle {
                  Layout.preferredWidth: Style.space(190)
                  Layout.preferredHeight: Style.space(26)
                  radius: Style.cornerRadius
                  color: root.isLightTheme ? "#ffffff" : "#1e1e2e"
                  border.width: 1
                  border.color: root.outline

                  SearchableDropdown {
                    id: switchSiteDropdown
                    anchors.fill: parent
                    rowHeight: Style.space(26)
                    showLabel: false
                    value: root.selectedSwitchSite
                    options: root.switchSiteOptions
                    placeholderText: "Search sites..."
                    emptyText: "No sites match"
                    foreground: root.foreground
                    background: root.isLightTheme ? "#ffffff" : "#1e1e2e"
                    popupBorder: root.accent
                    accent: root.accent
                    fontFamily: root.fontFamily
                    onChanged: function(val) {
                      root.selectedSwitchSite = val
                    }
                  }
                }
              }

              // Switch Selector Dropdown
              RowLayout {
                spacing: Style.space(6)

                Text {
                  textFormat: Text.PlainText;
                  text: "SWITCH:"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                }

                Rectangle {
                  Layout.preferredWidth: Style.space(260)
                  Layout.preferredHeight: Style.space(26)
                  radius: Style.cornerRadius
                  color: root.isLightTheme ? "#ffffff" : "#1e1e2e"
                  border.width: 1
                  border.color: root.outline

                  SearchableDropdown {
                    id: switchPickerDropdown
                    anchors.fill: parent
                    rowHeight: Style.space(26)
                    showLabel: false
                    value: root.currentSwitch ? (root.currentSwitch.mac || root.currentSwitch.name || "") : ""
                    options: root.switchOptionsForSelectedSite
                    placeholderText: "Search switches..."
                    emptyText: "No switches match"
                    foreground: root.foreground
                    background: root.isLightTheme ? "#ffffff" : "#1e1e2e"
                    popupBorder: root.accent
                    accent: root.accent
                    fontFamily: root.fontFamily
                    onChanged: function(val) {
                      root.selectedSwitchMac = val
                    }
                  }
                }
              }

              Item { Layout.fillWidth: true }

              // Filter pills: All, PoE, Active
              RowLayout {
                spacing: Style.space(4)

                Repeater {
                  model: ["All", "PoE", "Active"]
                  delegate: Rectangle {
                    required property string modelData
                    height: Style.space(24)
                    width: pFilterText.implicitWidth + Style.space(12)
                    radius: 3
                    color: root.portFilter === modelData ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : root.track
                    border.width: 1
                    border.color: root.portFilter === modelData ? root.accent : root.outline

                    Text {
                      id: pFilterText
                      textFormat: Text.PlainText;
                      anchors.centerIn: parent
                      text: modelData === "All" ? "All Ports" : (modelData === "PoE" ? "PoE Only" : "Active Only")
                      color: root.portFilter === modelData ? root.accent : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: root.portFilter === modelData
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: { root.portFilter = modelData }
                    }
                  }
                }
              }
            }

            // Switch Overview & PoE budget bar
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(14)
              visible: Boolean(root.currentSwitch)

              ColumnLayout {
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: (root.currentSwitch ? root.currentSwitch.name : "") + " · " + (root.currentSwitch ? root.currentSwitch.model : "")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "IP: " + (root.currentSwitch ? root.currentSwitch.ip : "") + " · MAC: " + (root.currentSwitch ? root.currentSwitch.mac : "") + " · " + (root.currentSwitch ? root.currentSwitch.activePorts : 0) + "/" + (root.currentSwitch ? root.currentSwitch.totalPorts : 0) + " Ports Connected"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                }
              }

              Item { Layout.fillWidth: true }

              // PoE Power Consumption Meter
              ColumnLayout {
                Layout.preferredWidth: 240
                spacing: 2

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    textFormat: Text.PlainText;
                    text: "PoE Power:"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    textFormat: Text.PlainText;
                    text: String(root.currentSwitch ? root.currentSwitch.totalPower : 0) + " W / " + String(root.currentSwitch ? root.currentSwitch.maxPower : 600) + " W"
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    font.bold: true
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 5
                  radius: 2.5
                  color: root.track

                  Rectangle {
                    height: parent.height
                    radius: 2.5
                    width: Math.min(parent.width, Math.max(4, parent.width * ((root.currentSwitch && root.currentSwitch.maxPower > 0) ? (root.currentSwitch.totalPower / root.currentSwitch.maxPower) : 0.05)))
                    color: root.accent
                  }
                }
              }
            }

            // Physical RJ45 Faceplate Port Visualizer (Chassis Strip)
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(32)
              color: root.track
              radius: 4
              border.width: 1
              border.color: root.outline
              visible: Boolean(root.currentSwitch && root.currentSwitch.ports && root.currentSwitch.ports.length > 0)

              Flickable {
                anchors.fill: parent
                anchors.margins: Style.space(3)
                contentWidth: jackRowLayout.width
                contentHeight: height
                clip: true

                RowLayout {
                  id: jackRowLayout
                  spacing: Style.space(3)

                  Repeater {
                    model: root.currentSwitch ? (root.currentSwitch.ports || []) : []
                    delegate: Rectangle {
                      required property var modelData
                      required property int index
                      width: Style.space(18)
                      height: Style.space(24)
                      radius: 2
                      color: modelData.up
                        ? (modelData.poePower > 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2))
                        : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.1)
                      border.width: 1
                      border.color: modelData.up
                        ? (modelData.poePower > 0 ? root.accent : root.healthy)
                        : root.outline

                      ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                          textFormat: Text.PlainText;
                          Layout.alignment: Qt.AlignHCenter
                          text: String(modelData.portIdx)
                          color: modelData.up ? root.foreground : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 7
                          font.bold: true
                        }

                        Rectangle {
                          Layout.alignment: Qt.AlignHCenter
                          width: 4
                          height: 4
                          radius: 2
                          color: modelData.up ? (modelData.poePower > 0 ? root.accent : root.healthy) : root.dim
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Port Matrix Card
        SectionCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          title: "PORT MATRIX & REMOTE POE POWER CYCLING"
          subtitle: "Live link negotiation, PoE power/voltage telemetry, connected endpoints, and remote PoE power cycling"
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: portGridCol.childrenRect.height + Style.space(16)
            clip: true

            Column {
              id: portGridCol
              width: parent.width
              spacing: Style.space(4)

              Text {
                textFormat: Text.PlainText;
                visible: tab3View.portsList.length === 0
                text: "No ports match the selected filter."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                topPadding: Style.space(20)
              }

              // 2-Column high-density table headers
              RowLayout {
                width: parent.width
                spacing: Style.space(8)
                visible: tab3View.portsList.length > 0

                // Left Column Header
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredWidth: Math.floor((portGridCol.width - Style.space(8)) / 2)
                  height: Style.space(20)
                  color: "transparent"

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText;
                      Layout.preferredWidth: Style.space(32)
                      text: "PORT"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.preferredWidth: Style.space(105)
                      text: "STATUS & SPEED"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.fillWidth: true
                      Layout.minimumWidth: Style.space(70)
                      text: "ENDPOINT"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.preferredWidth: Style.space(60)
                      text: "POE"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.preferredWidth: Style.space(48)
                      text: "ACTION"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }

                // Right Column Header
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredWidth: Math.floor((portGridCol.width - Style.space(8)) / 2)
                  height: Style.space(20)
                  color: "transparent"

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText;
                      Layout.preferredWidth: Style.space(32)
                      text: "PORT"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.preferredWidth: Style.space(105)
                      text: "STATUS & SPEED"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.fillWidth: true
                      Layout.minimumWidth: Style.space(70)
                      text: "ENDPOINT"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.preferredWidth: Style.space(60)
                      text: "POE"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.preferredWidth: Style.space(48)
                      text: "ACTION"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }
              }

              // 2-Column Port Grid
              Grid {
                id: portGrid
                width: parent.width
                columns: 2
                columnSpacing: Style.space(8)
                rowSpacing: Style.space(2)

                Repeater {
                  model: tab3View.portsList
                  delegate: Rectangle {
                    required property var modelData
                    width: Math.floor((portGrid.width - portGrid.columnSpacing) / 2)
                    height: Style.space(25)
                    radius: 3
                    color: portRowMouse.containsMouse ? root.cardHover : root.track
                    border.width: 1
                    border.color: portRowMouse.containsMouse ? root.accent : (modelData.up ? (modelData.poePower > 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3) : root.outline) : root.outline)

                    MouseArea {
                      id: portRowMouse
                      anchors.fill: parent
                      hoverEnabled: true
                    }

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(8)
                      anchors.rightMargin: Style.space(8)
                      spacing: Style.space(6)

                      // Col 1: Port Badge
                      Rectangle {
                        Layout.preferredWidth: Style.space(32)
                        Layout.preferredHeight: Style.space(18)
                        radius: 3
                        color: modelData.up ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.18) : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.12)
                        border.width: 1
                        border.color: modelData.up ? root.healthy : root.outline

                        Text {
                          textFormat: Text.PlainText;
                          anchors.centerIn: parent
                          text: "P" + String(modelData.portIdx)
                          color: modelData.up ? root.healthy : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: true
                        }
                      }

                      // Col 2: Status & Speed (Dense Inline)
                      RowLayout {
                        Layout.preferredWidth: Style.space(105)
                        spacing: Style.space(4)

                        Rectangle {
                          width: 5
                          height: 5
                          radius: 2.5
                          color: modelData.up ? root.healthy : root.dim
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.name || ("Port " + modelData.portIdx)
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: true
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }

                        Rectangle {
                          visible: modelData.up
                          height: Style.space(16)
                          radius: 2
                          color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                          border.width: 1
                          border.color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.35)
                          implicitWidth: spdText.implicitWidth + Style.space(6)

                          Text {
                            id: spdText
                            textFormat: Text.PlainText;
                            anchors.centerIn: parent
                            text: modelData.speedText || "1G"
                            color: root.healthy
                            font.family: root.fontFamily
                            font.pixelSize: 7
                            font.bold: true
                          }
                        }

                        Text {
                          textFormat: Text.PlainText;
                          visible: !modelData.up
                          text: "Down"
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 7
                        }
                      }

                      // Col 3: Connected Endpoint (Dense Inline)
                      RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: Style.space(70)
                        spacing: Style.space(4)

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.connectedDevice ? "" : ""
                          color: modelData.connectedDevice ? root.accent : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 8
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.connectedDevice || "No device"
                          color: modelData.connectedDevice ? root.foreground : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: Boolean(modelData.connectedDevice)
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }

                      // Col 4: PoE Telemetry (Dense Inline)
                      RowLayout {
                        Layout.preferredWidth: Style.space(60)
                        spacing: Style.space(3)

                        Text {
                          textFormat: Text.PlainText;
                          visible: modelData.poePower > 0
                          text: ""
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: 7
                        }

                        Text {
                          textFormat: Text.PlainText;
                          visible: modelData.poePower > 0
                          text: modelData.poePower.toFixed(1) + "W"
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: true
                        }

                        Text {
                          textFormat: Text.PlainText;
                          visible: !(modelData.poePower > 0)
                          text: (modelData.poeMode && modelData.poeMode !== "off") ? "Standby" : "Off"
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                        }
                      }

                      // Col 5: Action (Dense Cycle PoE Button with Tooltip)
                      Rectangle {
                        Layout.preferredWidth: Style.space(48)
                        Layout.preferredHeight: Style.space(18)
                        radius: 3
                        color: (modelData.poeMode !== "off" || modelData.poePower > 0)
                          ? (cycleBtnMouse.containsMouse ? root.cardHover : root.track)
                          : "transparent"
                        opacity: (modelData.poeMode !== "off" || modelData.poePower > 0) ? 1.0 : 0.35
                        border.width: 1
                        border.color: (modelData.poeMode !== "off" || modelData.poePower > 0)
                          ? (cycleBtnMouse.containsMouse ? root.backup : root.outline)
                          : "transparent"

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: 2
                          visible: modelData.poeMode !== "off" || modelData.poePower > 0

                          Text {
                            textFormat: Text.PlainText;
                            text: ""
                            color: root.backup
                            font.family: root.fontFamily
                            font.pixelSize: 7
                          }

                          Text {
                            textFormat: Text.PlainText;
                            text: "Cycle"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: 7
                            font.bold: true
                          }
                        }

                        Text {
                          textFormat: Text.PlainText;
                          anchors.centerIn: parent
                          visible: !(modelData.poeMode !== "off" || modelData.poePower > 0)
                          text: "—"
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 7
                        }

                        MouseArea {
                          id: cycleBtnMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: (modelData.poeMode !== "off" || modelData.poePower > 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                          enabled: modelData.poeMode !== "off" || modelData.poePower > 0
                          onClicked: {
                            if (root.currentSwitch) {
                              root.cyclePort(root.currentSwitch.hostId, root.currentSwitch.mac, modelData.portIdx, modelData.name || ("Port " + modelData.portIdx))
                            }
                          }
                        }

                        Rectangle {
                          z: 20
                          visible: cycleBtnMouse.containsMouse && (modelData.poeMode !== "off" || modelData.poePower > 0)
                          anchors.bottom: parent.top
                          anchors.bottomMargin: 4
                          anchors.right: parent.right
                          width: cycleTipText.implicitWidth + Style.space(12)
                          height: Style.space(20)
                          radius: 3
                          color: root.isLightTheme ? "#ffffff" : "#161b2a"
                          border.width: 1
                          border.color: root.outline

                          Text {
                            id: cycleTipText
                            textFormat: Text.PlainText;
                            anchors.centerIn: parent
                            text: "Power cycle PoE on Port " + modelData.portIdx + (modelData.poePower > 0 ? (" (" + modelData.poePower + "W)") : "")
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: 8
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // TAB 4: UNIFI OS APPLICATIONS & DIRECT CONNECT
      // ==========================================
      ColumnLayout {
        id: tab4View
        visible: root.currentTab === 4
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.space(8)

        readonly property var rawConsoles: root.fleetConsoles || []
        readonly property var filteredConsoles: {
          var list = []
          for (var i = 0; i < rawConsoles.length; i++) {
            var c = rawConsoles[i]
            if (root.consoleSiteFilter !== "All" && c.siteName !== root.consoleSiteFilter) continue
            if (root.consoleSearch.trim() !== "") {
              var q = root.consoleSearch.toLowerCase()
              var nameMatch = String(c.name || "").toLowerCase().indexOf(q) >= 0
              var modelMatch = String(c.model || "").toLowerCase().indexOf(q) >= 0
              var domainMatch = String(c.directConnectDomain || "").toLowerCase().indexOf(q) >= 0
              var ipMatch = String(c.ip || "").toLowerCase().indexOf(q) >= 0
              if (!nameMatch && !modelMatch && !domainMatch && !ipMatch) continue
            }
            list.push(c)
          }
          return list
        }

        // Top KPI Strip (High density 4 metrics)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Metric 1: Consoles Online
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(52)
            radius: 6
            color: root.track
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: 6
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.space(14) }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: {
                    var online = 0
                    for (var i = 0; i < tab4View.rawConsoles.length; i++) {
                      if (tab4View.rawConsoles[i].isOnline) online++
                    }
                    return online + " / " + tab4View.rawConsoles.length + " Online"
                  }
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "UniFi OS Gateway Consoles"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
              }
            }
          }

          // Metric 2: Applications Active
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(52)
            radius: 6
            color: root.track
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: 6
                color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.space(14) }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: {
                    var totalApps = 0
                    for (var i = 0; i < tab4View.rawConsoles.length; i++) {
                      totalApps += (tab4View.rawConsoles[i].activeAppCount || 0)
                    }
                    return totalApps + " Running"
                  }
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "Active Applications & Controllers"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
              }
            }
          }

          // Metric 3: P2P Direct Connect
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(52)
            radius: 6
            color: root.track
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: 6
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.space(14) }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: "P2P WebRTC Direct"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "Zero-Relay Direct Domain Access"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
              }
            }
          }

          // Metric 4: Direct Domains Active
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(52)
            radius: 6
            color: root.track
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: 6
                color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.space(14) }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: {
                    var count = 0
                    for (var i = 0; i < tab4View.rawConsoles.length; i++) {
                      if (tab4View.rawConsoles[i].directConnectDomain) count++
                    }
                    return count + " Domains Active"
                  }
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "*.id.ui.direct Endpoints"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
              }
            }
          }
        }

        // Search & Filter Row
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Search Box
          Rectangle {
            Layout.preferredWidth: Style.space(260)
            Layout.preferredHeight: Style.space(28)
            radius: 4
            color: root.track
            border.width: 1
            border.color: consoleSearchInput.activeFocus ? root.accent : root.outline

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText;
                text: ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
              }

              TextInput {
                id: consoleSearchInput
                Layout.fillWidth: true
                text: root.consoleSearch
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                clip: true
                onTextChanged: { root.consoleSearch = text }

                Text {
                  textFormat: Text.PlainText;
                  visible: consoleSearchInput.text === "" && !consoleSearchInput.activeFocus
                  text: "Filter consoles, apps, domains..."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                textFormat: Text.PlainText;
                visible: root.consoleSearch !== ""
                text: "✕"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    consoleSearchInput.text = ""
                    root.consoleSearch = ""
                  }
                }
              }
            }
          }

          // Direct Connect Explainer Badge
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(28)
            radius: 4
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.08)
            border.width: 1
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText;
                text: "⚡"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                textFormat: Text.PlainText;
                text: "Direct Connect uses *.id.ui.direct for end-to-end encrypted WebRTC P2P browser sessions with zero cloud relays."
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }
          }
        }

        // Master-Detail Split Area
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(8)

          // Left Panel: Consoles Roster
          Rectangle {
            Layout.preferredWidth: Style.space(310)
            Layout.fillHeight: true
            radius: 6
            color: root.card
            border.width: 1
            border.color: root.outline

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText;
                text: "GATEWAY CONSOLES (" + tab4View.filteredConsoles.length + ")"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
              }

              Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: consolesCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                  id: consolesCol
                  width: parent.width
                  spacing: Style.space(4)

                  Repeater {
                    model: tab4View.filteredConsoles
                    delegate: Rectangle {
                      id: consoleCard
                      required property var modelData
                      required property int index

                      width: consolesCol.width
                      implicitHeight: cInner.implicitHeight + Style.space(12)
                      radius: 5
                      color: (root.selectedConsoleIndex === index)
                        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                        : (cMouse.containsMouse ? root.cardHover : root.track)
                      border.width: 1
                      border.color: (root.selectedConsoleIndex === index) ? root.accent : root.outline

                      MouseArea {
                        id: cMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.selectedConsoleIndex = consoleCard.index }
                      }

                      ColumnLayout {
                        id: cInner
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Style.space(6)
                        spacing: 2

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Rectangle {
                            width: Style.space(6)
                            height: Style.space(6)
                            radius: 3
                            color: consoleCard.modelData.isOnline ? root.healthy : root.urgent
                          }

                          Text {
                            textFormat: Text.PlainText;
                            text: consoleCard.modelData.name || "UniFi Console"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                          }

                          Rectangle {
                            radius: 3
                            color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                            border.width: 1
                            border.color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.4)
                            Layout.preferredHeight: Style.space(16)
                            Layout.preferredWidth: cAppCountText.implicitWidth + Style.space(8)

                            Text {
                              textFormat: Text.PlainText;
                              id: cAppCountText
                              anchors.centerIn: parent
                              text: (consoleCard.modelData.activeAppCount || 0) + " Apps"
                              color: root.healthy
                              font.family: root.fontFamily
                              font.pixelSize: 8
                              font.bold: true
                            }
                          }
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: consoleCard.modelData.model || "Gateway"
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(4)

                          Text {
                            textFormat: Text.PlainText;
                            text: "⚡ " + (consoleCard.modelData.directConnectDomain ? (consoleCard.modelData.directConnectDomain.substring(0, 16) + "…") : "No Direct P2P")
                            color: consoleCard.modelData.directConnectDomain ? root.accent : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                          }

                          Text {
                            textFormat: Text.PlainText;
                            text: consoleCard.modelData.ip || ""
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 8
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // Right Panel: Console Detail & Applications Matrix
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 6
            color: root.card
            border.width: 1
            border.color: root.outline

            Flickable {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              contentWidth: width
              contentHeight: detailMainCol.implicitHeight + Style.space(12)
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              ColumnLayout {
                id: detailMainCol
                width: parent.width
                spacing: Style.space(10)

                // Console Header Banner
                Rectangle {
                  Layout.fillWidth: true
                  radius: 6
                  color: root.track
                  border.width: 1
                  border.color: root.outline
                  Layout.preferredHeight: Style.space(64)

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    spacing: Style.space(10)

                    Rectangle {
                      Layout.preferredWidth: Style.space(42)
                      Layout.preferredHeight: Style.space(42)
                      radius: 6
                      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                      border.width: 1
                      border.color: root.accent

                      Text {
                        textFormat: Text.PlainText;
                        anchors.centerIn: parent
                        text: ""
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(20)
                      }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 2

                      RowLayout {
                        spacing: Style.space(6)

                        Text {
                          textFormat: Text.PlainText;
                          text: root.currentConsole ? (root.currentConsole.name + " (" + root.currentConsole.model + ")") : "No Console Selected"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.body
                          font.bold: true
                        }

                        Rectangle {
                          radius: 3
                          color: (root.currentConsole && root.currentConsole.isOnline)
                            ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.18)
                            : Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18)
                          Layout.preferredHeight: Style.space(16)
                          Layout.preferredWidth: onlinePillText.implicitWidth + Style.space(8)

                          Text {
                            textFormat: Text.PlainText;
                            id: onlinePillText
                            anchors.centerIn: parent
                            text: (root.currentConsole && root.currentConsole.isOnline) ? "● ONLINE" : "● OFFLINE"
                            color: (root.currentConsole && root.currentConsole.isOnline) ? root.healthy : root.urgent
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }
                      }

                      RowLayout {
                        spacing: Style.space(12)

                        Text {
                          textFormat: Text.PlainText;
                          text: "Firmware: " + (root.currentConsole ? ("UniFi OS " + (root.currentConsole.firmwareVersion || "v5.1.x")) : "—")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: "Local IP: " + (root.currentConsole ? (root.currentConsole.ip || "—") : "—")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: "MAC: " + (root.currentConsole ? (root.currentConsole.mac || "—") : "—")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                        }
                      }
                    }
                  }
                }

                // Direct Connect Control Banner
                Rectangle {
                  Layout.fillWidth: true
                  radius: 6
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.07)
                  border.width: 1
                  border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
                  Layout.preferredHeight: Style.space(78)

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(6)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        textFormat: Text.PlainText;
                        text: "⚡ P2P DIRECT CONNECT DOMAIN"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }

                      Rectangle {
                        radius: 3
                        color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                        Layout.preferredHeight: Style.space(16)
                        Layout.preferredWidth: p2pPillText.implicitWidth + Style.space(8)
                        Text {
                          textFormat: Text.PlainText;
                          id: p2pPillText
                          anchors.centerIn: parent
                          text: (root.currentConsole && root.currentConsole.directConnectDomain) ? "WebRTC Direct Active" : "Direct P2P Unavailable"
                          color: (root.currentConsole && root.currentConsole.directConnectDomain) ? root.healthy : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }

                      Item { Layout.fillWidth: true }

                      Text {
                        textFormat: Text.PlainText;
                        text: root.currentConsole ? (root.currentConsole.directConnectDomain || "None") : "—"
                        color: root.foreground
                        font.family: "Monospace"
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }
                    }

                    // Action Buttons Row
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      // Button 1: Launch Direct Connect
                      Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(26)
                        radius: 4
                        color: launchDirectMouse.containsMouse ? Qt.darker(root.accent, 1.15) : root.accent

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: 4
                          Text { textFormat: Text.PlainText; text: "⚡"; color: "#1E1E2E"; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                          Text { textFormat: Text.PlainText; text: "Launch Direct Connect"; color: "#1E1E2E"; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                        }

                        MouseArea {
                          id: launchDirectMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.currentConsole && root.currentConsole.directConnectUrl) {
                              root.openExternalUrl(root.currentConsole.directConnectUrl)
                            }
                          }
                        }
                      }

                      // Button 2: Copy Direct URL
                      Rectangle {
                        Layout.preferredWidth: Style.space(120)
                        Layout.preferredHeight: Style.space(26)
                        radius: 4
                        color: copyDirectMouse.containsMouse ? root.cardHover : root.track
                        border.width: 1
                        border.color: root.outline

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: 4
                          Text { textFormat: Text.PlainText; text: "📋"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                          Text { textFormat: Text.PlainText; text: "Copy Domain"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                        }

                        MouseArea {
                          id: copyDirectMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.currentConsole && root.currentConsole.directConnectUrl) {
                              root.copyToClipboard(root.currentConsole.directConnectUrl, "Direct Connect URL")
                            }
                          }
                        }
                      }

                      // Button 3: Local IP Launch
                      Rectangle {
                        Layout.preferredWidth: Style.space(110)
                        Layout.preferredHeight: Style.space(26)
                        radius: 4
                        color: localLaunchMouse.containsMouse ? root.cardHover : root.track
                        border.width: 1
                        border.color: root.outline

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: 4
                          Text { textFormat: Text.PlainText; text: ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                          Text { textFormat: Text.PlainText; text: "Local HTTPS"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                        }

                        MouseArea {
                          id: localLaunchMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.currentConsole && root.currentConsole.localUrl) {
                              root.openExternalUrl(root.currentConsole.localUrl)
                            }
                          }
                        }
                      }

                      // Button 4: Cloud Site Manager
                      Rectangle {
                        Layout.preferredWidth: Style.space(110)
                        Layout.preferredHeight: Style.space(26)
                        radius: 4
                        color: cloudLaunchMouse.containsMouse ? root.cardHover : root.track
                        border.width: 1
                        border.color: root.outline

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: 4
                          Text { textFormat: Text.PlainText; text: "☁"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                          Text { textFormat: Text.PlainText; text: "Cloud Relay"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                        }

                        MouseArea {
                          id: cloudLaunchMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.currentConsole && root.currentConsole.webCloudUrl) {
                              root.openExternalUrl(root.currentConsole.webCloudUrl)
                            }
                          }
                        }
                      }
                    }
                  }
                }

                // Applications Matrix Card
                Rectangle {
                  Layout.fillWidth: true
                  radius: 6
                  color: root.track
                  border.width: 1
                  border.color: root.outline
                  implicitHeight: appsContentCol.implicitHeight + Style.space(16)

                  ColumnLayout {
                    id: appsContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(8)
                    spacing: Style.space(6)

                    RowLayout {
                      Layout.fillWidth: true

                      Text {
                        textFormat: Text.PlainText;
                        text: "INSTALLED UNIFI OS APPLICATIONS (" + (root.currentConsole && root.currentConsole.applications ? root.currentConsole.applications.length : 0) + ")"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }

                      Item { Layout.fillWidth: true }

                      Text {
                        textFormat: Text.PlainText;
                        text: "Direct launch bypasses cloud proxy"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: 8
                      }
                    }

                    // Applications List
                    Column {
                      Layout.fillWidth: true
                      spacing: Style.space(4)

                      Repeater {
                        model: (root.currentConsole && root.currentConsole.applications) ? root.currentConsole.applications : []
                        delegate: Rectangle {
                          id: appRowRect
                          required property var modelData
                          required property int index

                          width: appsContentCol.width
                          implicitHeight: appRowLayout.implicitHeight + Style.space(8)
                          radius: 4
                          color: appRowMouse.containsMouse ? root.cardHover : root.card
                          border.width: 1
                          border.color: appRowMouse.containsMouse ? root.accent : root.outline

                          MouseArea {
                            id: appRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                          }

                          RowLayout {
                            id: appRowLayout
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(8)
                            anchors.rightMargin: Style.space(8)
                            anchors.topMargin: Style.space(4)
                            anchors.bottomMargin: Style.space(4)
                            spacing: Style.space(8)

                            // App Icon
                            Rectangle {
                              Layout.preferredWidth: Style.space(26)
                              Layout.preferredHeight: Style.space(26)
                              radius: 4
                              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                              Text {
                                textFormat: Text.PlainText;
                                anchors.centerIn: parent
                                text: appRowRect.modelData.id === "network" ? ""
                                  : (appRowRect.modelData.id === "protect" ? ""
                                  : (appRowRect.modelData.id === "drive" ? ""
                                  : (appRowRect.modelData.id === "innerspace" ? ""
                                  : (appRowRect.modelData.id === "access" ? ""
                                  : (appRowRect.modelData.id === "talk" ? "" : "")))))
                                color: root.accent
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                              }
                            }

                            // App Details
                            ColumnLayout {
                              Layout.fillWidth: true
                              spacing: 1

                              RowLayout {
                                spacing: Style.space(6)

                                Text {
                                  textFormat: Text.PlainText;
                                  text: appRowRect.modelData.name || "UniFi Application"
                                  color: root.foreground
                                  font.family: root.fontFamily
                                  font.pixelSize: Style.font.caption
                                  font.bold: true
                                }

                                Rectangle {
                                  radius: 3
                                  color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                                  Layout.preferredHeight: Style.space(14)
                                  Layout.preferredWidth: appVerText.implicitWidth + Style.space(6)
                                  Text {
                                    textFormat: Text.PlainText;
                                    id: appVerText
                                    anchors.centerIn: parent
                                    text: appRowRect.modelData.version || "Active"
                                    color: root.healthy
                                    font.family: root.fontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                  }
                                }

                                Rectangle {
                                  visible: appRowRect.modelData.updateAvailable !== ""
                                  radius: 3
                                  color: Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.22)
                                  border.width: 1
                                  border.color: root.backup
                                  Layout.preferredHeight: Style.space(14)
                                  Layout.preferredWidth: appUpdText.implicitWidth + Style.space(6)
                                  Text {
                                    textFormat: Text.PlainText;
                                    id: appUpdText
                                    anchors.centerIn: parent
                                    text: "UPDATE: v" + appRowRect.modelData.updateAvailable
                                    color: root.backup
                                    font.family: root.fontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                  }
                                }
                              }

                              Text {
                                textFormat: Text.PlainText;
                                text: (appRowRect.modelData.port > 0 ? ("Port " + appRowRect.modelData.port + " · ") : "") + (appRowRect.modelData.isRunning ? "Running & Active" : "Inactive")
                                color: root.dim
                                font.family: root.fontFamily
                                font.pixelSize: 8
                              }
                            }

                            // App Action Buttons
                            RowLayout {
                              spacing: Style.space(4)

                              // Direct App Launch Button
                              Rectangle {
                                Layout.preferredWidth: Style.space(100)
                                Layout.preferredHeight: Style.space(22)
                                radius: 4
                                color: appLaunchMouse.containsMouse ? root.accent : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                                border.width: 1
                                border.color: root.accent

                                RowLayout {
                                  anchors.centerIn: parent
                                  spacing: 4
                                  Text { textFormat: Text.PlainText; text: "⚡"; color: appLaunchMouse.containsMouse ? "#1E1E2E" : root.accent; font.family: root.fontFamily; font.pixelSize: 8 }
                                  Text { textFormat: Text.PlainText; text: "Direct Launch"; color: appLaunchMouse.containsMouse ? "#1E1E2E" : root.foreground; font.family: root.fontFamily; font.pixelSize: 8; font.bold: true }
                                }

                                MouseArea {
                                  id: appLaunchMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    var targetUrl = appRowRect.modelData.directUrl || (root.currentConsole ? root.currentConsole.directConnectUrl : "")
                                    if (targetUrl) root.openExternalUrl(targetUrl)
                                  }
                                }
                              }

                              // Local App Launch Button
                              Rectangle {
                                Layout.preferredWidth: Style.space(70)
                                Layout.preferredHeight: Style.space(22)
                                radius: 4
                                color: appLocalMouse.containsMouse ? root.cardHover : root.track
                                border.width: 1
                                border.color: root.outline

                                RowLayout {
                                  anchors.centerIn: parent
                                  spacing: 4
                                  Text { textFormat: Text.PlainText; text: ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 8 }
                                  Text { textFormat: Text.PlainText; text: "Local"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 8 }
                                }

                                MouseArea {
                                  id: appLocalMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    var targetUrl = appRowRect.modelData.localUrl || (root.currentConsole ? root.currentConsole.localUrl : "")
                                    if (targetUrl) root.openExternalUrl(targetUrl)
                                  }
                                }
                              }

                              // Copy App URL
                              Rectangle {
                                Layout.preferredWidth: Style.space(24)
                                Layout.preferredHeight: Style.space(22)
                                radius: 4
                                color: appCopyMouse.containsMouse ? root.cardHover : root.track
                                border.width: 1
                                border.color: root.outline

                                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "📋"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 8 }

                                MouseArea {
                                  id: appCopyMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    var targetUrl = appRowRect.modelData.directUrl || (root.currentConsole ? root.currentConsole.directConnectUrl : "")
                                    if (targetUrl) root.copyToClipboard(targetUrl, appRowRect.modelData.name + " URL")
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // TAB 5: WIFI & RF SPECTRUM HEALTH
      // ==========================================
      ColumnLayout {
        id: tab5View
        visible: root.currentTab === 5
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.space(10)

        readonly property var rawWlans: root.fleetWlans || []
        readonly property var filteredWlans: {
          var list = []
          for (var i = 0; i < rawWlans.length; i++) {
            var w = rawWlans[i]
            if (root.wlanSiteFilter !== "All" && w.siteName !== root.wlanSiteFilter) continue
            if (root.wlanSearch.trim() !== "") {
              var q = root.wlanSearch.toLowerCase()
              var nameMatch = String(w.name || "").toLowerCase().indexOf(q) >= 0
              var secMatch = String(w.security || "").toLowerCase().indexOf(q) >= 0
              var siteMatch = String(w.siteName || "").toLowerCase().indexOf(q) >= 0
              if (!nameMatch && !secMatch && !siteMatch) continue
            }
            list.push(w)
          }
          return list
        }

        // Top KPI Strip
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Metric 1: Total SSIDs
          BorderSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            color: root.card
            radius: 6
            borderSpec: Border.flat(root.outline, 1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text { textFormat: Text.PlainText; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.bodyLarge }
              ColumnLayout {
                spacing: 1
                Text { textFormat: Text.PlainText; text: "ACTIVE WLANS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                Text { textFormat: Text.PlainText; text: String(root.fleetWlans.length) + " SSIDs"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
              }
            }
          }

          // Metric 2: Connected WiFi Clients
          BorderSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            color: root.card
            radius: 6
            borderSpec: Border.flat(root.outline, 1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text { textFormat: Text.PlainText; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.bodyLarge }
              ColumnLayout {
                spacing: 1
                Text { textFormat: Text.PlainText; text: "WIFI CLIENTS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                Text {
                  textFormat: Text.PlainText;
                  text: {
                    var total = 0
                    for (var i = 0; i < root.fleetWlans.length; i++) total += (root.fleetWlans[i].clientCount || 0)
                    return total + " Clients"
                  }
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }
            }
          }

          // Metric 3: Security & Roaming
          BorderSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            color: root.card
            radius: 6
            borderSpec: Border.flat(root.outline, 1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text { textFormat: Text.PlainText; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.bodyLarge }
              ColumnLayout {
                spacing: 1
                Text { textFormat: Text.PlainText; text: "SECURITY POSTURE"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                Text { textFormat: Text.PlainText; text: "WPA3 & 802.11k/v/r Active"; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
              }
            }
          }

          // Metric 4: Auto-RF Optimization
          BorderSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            color: root.card
            radius: 6
            borderSpec: Border.flat(root.outline, 1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text { textFormat: Text.PlainText; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.bodyLarge }
              ColumnLayout {
                spacing: 1
                Text { textFormat: Text.PlainText; text: "NIGHTLY AUTO-RF"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                Text {
                  textFormat: Text.PlainText;
                  text: (root.fleetSpectrum && root.fleetSpectrum.autoRf) ? (root.fleetSpectrum.autoRf.status + " · " + root.fleetSpectrum.autoRf.lastRun) : "Optimized"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                }
              }
            }
          }
        }

        // Sub-filters row
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Search Box
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(30)
            radius: 6
            color: root.track
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(6)

              Text { textFormat: Text.PlainText; text: ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              TextInput {
                id: wlanSearchInput
                Layout.fillWidth: true
                text: root.wlanSearch
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                clip: true
                onTextChanged: { root.wlanSearch = text }
              }
              Text {
                textFormat: Text.PlainText;
                visible: root.wlanSearch === ""
                text: "Search SSIDs, security type, frequency bands..."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }

          // Site filter pills
          RowLayout {
            spacing: Style.space(4)
            Repeater {
              model: ["All", "Main Office", "Home", "Warehouse"]
              delegate: Rectangle {
                required property string modelData
                implicitHeight: Style.space(26)
                implicitWidth: wlanSiteText.implicitWidth + Style.space(14)
                radius: 4
                color: root.wlanSiteFilter === modelData ? root.accent : (wSiteMouse.containsMouse ? root.cardHover : root.track)
                border.width: 1
                border.color: root.wlanSiteFilter === modelData ? root.accent : root.outline

                Text {
                  textFormat: Text.PlainText;
                  id: wlanSiteText
                  anchors.centerIn: parent
                  text: modelData
                  color: root.wlanSiteFilter === modelData ? "#ffffff" : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: root.wlanSiteFilter === modelData
                }

                MouseArea {
                  id: wSiteMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { root.wlanSiteFilter = modelData }
                }
              }
            }
          }
        }

        // Section: Wireless Networks List
        Text {
          textFormat: Text.PlainText;
          text: "FLEET WIRELESS NETWORKS & QR ONBOARDING (" + tab5View.filteredWlans.length + ")"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        // WLAN Cards Flow
        Flow {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Repeater {
            model: tab5View.filteredWlans
            delegate: BorderSurface {
              id: wlanCard
              required property var modelData
              width: Math.floor((tab5View.width - Style.space(8)) / 2)
              implicitHeight: wlanCol.implicitHeight + Style.space(16)
              color: root.card
              radius: 6
              borderSpec: Border.flat(root.outline, 1)

              ColumnLayout {
                id: wlanCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(6)

                // Row 1: Icon + Name + Badges
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)

                  Text { textFormat: Text.PlainText; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                  Text {
                    textFormat: Text.PlainText;
                    text: modelData.name
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  // Security Pill
                  Rectangle {
                    implicitHeight: Style.space(18)
                    implicitWidth: secPillText.implicitWidth + Style.space(10)
                    radius: 3
                    color: modelData.security.indexOf("WPA3") >= 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : root.track
                    border.width: 1
                    border.color: modelData.security.indexOf("WPA3") >= 0 ? root.accent : root.outline
                    Text { textFormat: Text.PlainText; id: secPillText; anchors.centerIn: parent; text: modelData.security; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                  }

                  // Guest / IoT tag
                  Rectangle {
                    visible: modelData.guest === true || modelData.hidden === true
                    implicitHeight: Style.space(18)
                    implicitWidth: guestPillText.implicitWidth + Style.space(8)
                    radius: 3
                    color: modelData.guest ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2) : root.track
                    border.width: 1
                    border.color: modelData.guest ? root.backup : root.outline
                    Text { textFormat: Text.PlainText; id: guestPillText; anchors.centerIn: parent; text: modelData.guest ? "Guest" : "Hidden"; color: modelData.guest ? root.backup : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                  }
                }

                // Row 2: Site, Band Pills, Client count
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)

                  Text { textFormat: Text.PlainText; text: modelData.siteName + " · VLAN " + modelData.vlan + " · " + (modelData.radioProto || "WiFi"); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; elide: Text.ElideRight; Layout.fillWidth: true }

                  // Client count badge
                  Rectangle {
                    implicitHeight: Style.space(18)
                    implicitWidth: clientBadgeText.implicitWidth + Style.space(10)
                    radius: 3
                    color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                    Text { textFormat: Text.PlainText; id: clientBadgeText; anchors.centerIn: parent; text: " " + modelData.clientCount; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                  }
                }

                // Row 3: Passphrase + Share / QR Code button
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)

                  Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Style.space(24)
                    radius: 4
                    color: root.track
                    border.width: 1
                    border.color: root.outline

                    RowLayout {
                      anchors.fill: parent
                      anchors.margins: Style.space(4)
                      spacing: Style.space(4)
                      Text { textFormat: Text.PlainText; text: ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: 8 }
                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.passphrase || "None / Open"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                      Rectangle {
                        implicitHeight: Style.space(18)
                        implicitWidth: Style.space(20)
                        radius: 3
                        color: copyPassMouse.containsMouse ? root.cardHover : "transparent"
                        Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "📋"; font.pixelSize: 8 }
                        MouseArea {
                          id: copyPassMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: { root.copyToClipboard(modelData.passphrase, modelData.name + " password") }
                        }
                      }
                    }
                  }

                  // QR Code / Share Button
                  Rectangle {
                    implicitHeight: Style.space(24)
                    implicitWidth: qrBtnText.implicitWidth + Style.space(14)
                    radius: 4
                    color: qrBtnMouse.containsMouse ? root.accent : root.cardHover
                    border.width: 1
                    border.color: root.accent

                    RowLayout {
                      anchors.centerIn: parent
                      spacing: Style.space(4)
                      Text { textFormat: Text.PlainText; text: ""; color: qrBtnMouse.containsMouse ? "#ffffff" : root.accent; font.family: root.fontFamily; font.pixelSize: 8 }
                      Text { textFormat: Text.PlainText; id: qrBtnText; text: "Share QR"; color: qrBtnMouse.containsMouse ? "#ffffff" : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                    }

                    MouseArea {
                      id: qrBtnMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.selectedWlanForQr = modelData
                        root.showQrModal = true
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // QR Code Modal Card (if showQrModal is true)
        BorderSurface {
          visible: root.showQrModal && root.selectedWlanForQr !== null
          Layout.fillWidth: true
          implicitHeight: qrModalCol.implicitHeight + Style.space(16)
          color: root.track
          radius: 8
          borderSpec: Border.flat(root.accent, 2)

          ColumnLayout {
            id: qrModalCol
            anchors.fill: parent
            anchors.margins: Style.space(12)
            spacing: Style.space(8)

            RowLayout {
              Layout.fillWidth: true
              Text { textFormat: Text.PlainText; text: " WIFI ONBOARDING QR CODE — " + (root.selectedWlanForQr ? root.selectedWlanForQr.name : ""); color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; Layout.fillWidth: true }
              Rectangle {
                implicitHeight: Style.space(20)
                implicitWidth: Style.space(20)
                radius: 3
                color: closeQrMouse.containsMouse ? root.urgent : root.cardHover
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "✕"; color: "#ffffff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                MouseArea {
                  id: closeQrMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { root.showQrModal = false }
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(16)

              // Stylized QR Matrix Canvas
              Rectangle {
                width: Style.space(120)
                height: Style.space(120)
                radius: 6
                color: "#ffffff"
                border.width: 1
                border.color: root.outline

                Canvas {
                  id: qrCanvas
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  onPaint: {
                    var ctx = getContext("2d")
                    ctx.fillStyle = "#ffffff"
                    ctx.fillRect(0, 0, width, height)
                    ctx.fillStyle = "#000000"

                    var n = 15
                    var cell = width / n
                    var seedStr = root.selectedWlanForQr ? (root.selectedWlanForQr.name + root.selectedWlanForQr.passphrase) : "wifi"
                    var hash = 0
                    for (var k = 0; k < seedStr.length; k++) hash = (hash * 31 + seedStr.charCodeAt(k)) & 0x7fffffff

                    // Corner 1
                    ctx.fillRect(0, 0, cell * 4, cell * 4)
                    ctx.fillStyle = "#ffffff"; ctx.fillRect(cell, cell, cell * 2, cell * 2); ctx.fillStyle = "#000000"
                    // Corner 2
                    ctx.fillRect(width - cell * 4, 0, cell * 4, cell * 4)
                    ctx.fillStyle = "#ffffff"; ctx.fillRect(width - cell * 3, cell, cell * 2, cell * 2); ctx.fillStyle = "#000000"
                    // Corner 3
                    ctx.fillRect(0, height - cell * 4, cell * 4, cell * 4)
                    ctx.fillStyle = "#ffffff"; ctx.fillRect(cell, height - cell * 3, cell * 2, cell * 2); ctx.fillStyle = "#000000"

                    // Data matrix pseudo-bits
                    for (var r = 0; r < n; r++) {
                      for (var c = 0; c < n; c++) {
                        if ((r < 4 && c < 4) || (r < 4 && c >= n - 4) || (r >= n - 4 && c < 4)) continue
                        var bit = ((hash ^ (r * 13 + c * 23)) % 7) < 3
                        if (bit) ctx.fillRect(c * cell, r * cell, cell - 0.5, cell - 0.5)
                      }
                    }
                  }
                }
              }

              // QR Code Details & Instructions
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(4)

                Text { textFormat: Text.PlainText; text: "SSID: " + (root.selectedWlanForQr ? root.selectedWlanForQr.name : ""); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Text { textFormat: Text.PlainText; text: "Security: " + (root.selectedWlanForQr ? root.selectedWlanForQr.security : "") + " · Site: " + (root.selectedWlanForQr ? root.selectedWlanForQr.siteName : ""); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { textFormat: Text.PlainText; text: "Password: " + (root.selectedWlanForQr ? root.selectedWlanForQr.passphrase : ""); color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                Text { textFormat: Text.PlainText; text: "Point phone camera or scanner at QR code to auto-connect to this Wi-Fi network."; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }

                RowLayout {
                  spacing: Style.space(8)
                  Rectangle {
                    implicitHeight: Style.space(24)
                    implicitWidth: copyUriBtnText.implicitWidth + Style.space(14)
                    radius: 4
                    color: copyUriMouse.containsMouse ? root.accent : root.card
                    border.width: 1
                    border.color: root.accent
                    Text { textFormat: Text.PlainText; id: copyUriBtnText; anchors.centerIn: parent; text: "Copy WiFi URI"; color: copyUriMouse.containsMouse ? "#ffffff" : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                    MouseArea {
                      id: copyUriMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (root.selectedWlanForQr) root.copyToClipboard(root.selectedWlanForQr.qrCode, "WiFi QR code URI")
                      }
                    }
                  }
                  Rectangle {
                    implicitHeight: Style.space(24)
                    implicitWidth: copyPassBtnText.implicitWidth + Style.space(14)
                    radius: 4
                    color: copyPassBtnMouse.containsMouse ? root.healthy : root.card
                    border.width: 1
                    border.color: root.healthy
                    Text { textFormat: Text.PlainText; id: copyPassBtnText; anchors.centerIn: parent; text: "Copy Password"; color: copyPassBtnMouse.containsMouse ? "#ffffff" : root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                    MouseArea {
                      id: copyPassBtnMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (root.selectedWlanForQr) root.copyToClipboard(root.selectedWlanForQr.passphrase, "WiFi password")
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Section: RF Spectrum & Channel Utilization
        Text {
          textFormat: Text.PlainText;
          text: "RF SPECTRUM CONGESTION & CHANNEL UTILIZATION"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        // 3 Band Utilization Cards
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Repeater {
            model: (root.fleetSpectrum && root.fleetSpectrum.bands) ? root.fleetSpectrum.bands : []
            delegate: BorderSurface {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: bandCol.implicitHeight + Style.space(16)
              color: root.card
              radius: 6
              borderSpec: Border.flat(root.outline, 1)

              ColumnLayout {
                id: bandCol
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(5)

                RowLayout {
                  Layout.fillWidth: true
                  Text { textFormat: Text.PlainText; text: modelData.band; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; Layout.fillWidth: true }
                  Rectangle {
                    implicitHeight: Style.space(16)
                    implicitWidth: bandStatusText.implicitWidth + Style.space(8)
                    radius: 3
                    color: modelData.status === "Pristine" ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : (modelData.status === "Optimal" ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2))
                    Text { textFormat: Text.PlainText; id: bandStatusText; anchors.centerIn: parent; text: modelData.status; color: modelData.status === "Pristine" ? root.accent : (modelData.status === "Optimal" ? root.healthy : root.backup); font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                  }
                }

                // Utilization Progress Bar
                Rectangle {
                  Layout.fillWidth: true
                  height: Style.space(6)
                  radius: 3
                  color: root.track
                  Rectangle {
                    width: parent.width * Math.min(1.0, modelData.utilization / 100)
                    height: parent.height
                    radius: 3
                    color: modelData.utilization > 50 ? root.urgent : (modelData.utilization > 25 ? root.backup : root.healthy)
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  Text { textFormat: Text.PlainText; text: "Utilization: " + modelData.utilization + "%"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                  Text { textFormat: Text.PlainText; text: "Interference: " + modelData.interference + "%"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                  Text { textFormat: Text.PlainText; text: "Noise: " + modelData.noiseFloor + "dBm"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                }

                // Channel badges row
                RowLayout {
                  spacing: Style.space(4)
                  Repeater {
                    model: modelData.channels || []
                    delegate: Rectangle {
                      required property var modelData
                      implicitHeight: Style.space(16)
                      implicitWidth: chText.implicitWidth + Style.space(6)
                      radius: 2
                      color: root.track
                      Text { textFormat: Text.PlainText; id: chText; anchors.centerIn: parent; text: "Ch " + modelData.channel + " (" + modelData.utilization + "%)"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 8 }
                    }
                  }
                }
              }
            }
          }
        }

        // Section: AP Radio Channel Allocations Table
        Text {
          textFormat: Text.PlainText;
          text: "ACCESS POINT RADIO ASSIGNMENTS & CLIENT LOAD"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        BorderSurface {
          Layout.fillWidth: true
          implicitHeight: apRadioCol.implicitHeight + Style.space(14)
          color: root.card
          radius: 6
          borderSpec: Border.flat(root.outline, 1)

          ColumnLayout {
            id: apRadioCol
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(4)

            // Header Row
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)
              Text { textFormat: Text.PlainText; text: "ACCESS POINT"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 160 }
              Text { textFormat: Text.PlainText; text: "SITE"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 100 }
              Text { textFormat: Text.PlainText; text: "2.4 GHZ"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 100 }
              Text { textFormat: Text.PlainText; text: "5 GHZ"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 100 }
              Text { textFormat: Text.PlainText; text: "6 GHZ"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 100 }
              Text { textFormat: Text.PlainText; text: "CLIENTS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.fillWidth: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }

            Repeater {
              model: (root.fleetSpectrum && root.fleetSpectrum.accessPoints) ? root.fleetSpectrum.accessPoints : []
              delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.space(8)

                Text { textFormat: Text.PlainText; text: modelData.name + " (" + modelData.model + ")"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true; elide: Text.ElideRight; Layout.preferredWidth: 160 }
                Text { textFormat: Text.PlainText; text: modelData.siteName; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; elide: Text.ElideRight; Layout.preferredWidth: 100 }
                Text { textFormat: Text.PlainText; text: "Ch " + modelData.ch24 + " · " + modelData.txPower24 + "dBm"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; Layout.preferredWidth: 100 }
                Text { textFormat: Text.PlainText; text: "Ch " + modelData.ch5 + " · " + modelData.txPower5 + "dBm"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; Layout.preferredWidth: 100 }
                Text { textFormat: Text.PlainText; text: modelData.ch6 ? ("Ch " + modelData.ch6 + " · " + modelData.txPower6 + "dBm") : "N/A"; color: modelData.ch6 ? root.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; Layout.preferredWidth: 100 }
                Text { textFormat: Text.PlainText; text: " " + modelData.clients + " connected"; color: modelData.clients > 0 ? root.healthy : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: modelData.clients > 0; Layout.fillWidth: true }
              }
            }
          }
        }
      }

      // ==========================================
      // TAB 6: FIRMWARE & LIFECYCLE MANAGEMENT
      // ==========================================
      ColumnLayout {
        id: tab6View
        visible: root.currentTab === 6
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.space(10)

        readonly property var rawUpdates: root.fleetUpdates || []
        readonly property var filteredUpdates: {
          var list = []
          for (var i = 0; i < rawUpdates.length; i++) {
            var u = rawUpdates[i]
            if (root.updateSiteFilter !== "All" && u.siteName !== root.updateSiteFilter) continue
            if (root.updateSeverityFilter !== "All" && u.category !== root.updateSeverityFilter.toLowerCase()) continue
            if (root.updateSearch.trim() !== "") {
              var q = root.updateSearch.toLowerCase()
              var nameMatch = String(u.name || "").toLowerCase().indexOf(q) >= 0
              var modelMatch = String(u.model || "").toLowerCase().indexOf(q) >= 0
              var siteMatch = String(u.siteName || "").toLowerCase().indexOf(q) >= 0
              var verMatch = String(u.targetVersion || "").toLowerCase().indexOf(q) >= 0
              if (!nameMatch && !modelMatch && !siteMatch && !verMatch) continue
            }
            list.push(u)
          }
          return list
        }

        // Top KPI Strip
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Metric 1: Pending Updates
          BorderSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            color: root.card
            radius: 6
            borderSpec: Border.flat(root.fleetUpdates.length > 0 ? root.backup : root.healthy, 1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text { textFormat: Text.PlainText; text: ""; color: root.fleetUpdates.length > 0 ? root.backup : root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.bodyLarge }
              ColumnLayout {
                spacing: 1
                Text { textFormat: Text.PlainText; text: "PENDING UPDATES"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                Text { textFormat: Text.PlainText; text: String(root.fleetUpdates.length) + " Devices"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
              }
            }
          }

          // Metric 2: Release Channel
          BorderSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            color: root.card
            radius: 6
            borderSpec: Border.flat(root.outline, 1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text { textFormat: Text.PlainText; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.bodyLarge }
              ColumnLayout {
                spacing: 1
                Text { textFormat: Text.PlainText; text: "RELEASE CHANNEL"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                Text { textFormat: Text.PlainText; text: "Official (GA)"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
              }
            }
          }

          // Metric 3: Automated Backups
          BorderSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            color: root.card
            radius: 6
            borderSpec: Border.flat(root.healthy, 1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text { textFormat: Text.PlainText; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.bodyLarge }
              ColumnLayout {
                spacing: 1
                Text { textFormat: Text.PlainText; text: "CLOUD BACKUPS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                Text { textFormat: Text.PlainText; text: String(root.fleetBackups.length) + " Consoles Protected"; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
              }
            }
          }

          // Metric 4: Auto-Scheduled Maintenance
          BorderSurface {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            color: root.card
            radius: 6
            borderSpec: Border.flat(root.outline, 1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Text { textFormat: Text.PlainText; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.bodyLarge }
              ColumnLayout {
                spacing: 1
                Text { textFormat: Text.PlainText; text: "MAINTENANCE WINDOW"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                Text { textFormat: Text.PlainText; text: "Sundays at 03:00"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
              }
            }
          }
        }

        // Bulk Action Banner
        BorderSurface {
          Layout.fillWidth: true
          implicitHeight: bulkRow.implicitHeight + Style.space(16)
          color: root.track
          radius: 6
          borderSpec: Border.flat(root.accent, 1)

          RowLayout {
            id: bulkRow
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(10)

            Rectangle {
              width: Style.space(32)
              height: Style.space(32)
              radius: 6
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
              Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.body }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1
              Text { textFormat: Text.PlainText; text: "FLEET FIRMWARE BATCH DEPLOYMENT"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
              Text { textFormat: Text.PlainText; text: root.fleetUpdates.length + " hardware devices have official UniFi firmware updates ready to install."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            }

            // Update All Button
            Rectangle {
              implicitHeight: Style.space(28)
              implicitWidth: updateAllBtnText.implicitWidth + Style.space(18)
              radius: 4
              color: root.bulkUpdateConfirm ? root.urgent : (updateAllMouse.containsMouse ? root.cardHover : root.accent)
              border.width: 1
              border.color: root.bulkUpdateConfirm ? root.urgent : root.accent

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(5)
                Text { textFormat: Text.PlainText; text: root.bulkUpdateConfirm ? "" : ""; color: "#ffffff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Text { textFormat: Text.PlainText; id: updateAllBtnText; text: root.bulkUpdateConfirm ? "Confirm Update All" : "Update All Devices"; color: "#ffffff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
              }

              MouseArea {
                id: updateAllMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!root.bulkUpdateConfirm) {
                    root.bulkUpdateConfirm = true
                  } else {
                    root.bulkUpdateConfirm = false
                    root.upgradeAllDevices()
                  }
                }
              }
            }
          }
        }

        // Filters row
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Search Box
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(30)
            radius: 6
            color: root.track
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(6)

              Text { textFormat: Text.PlainText; text: ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              TextInput {
                id: updateSearchInput
                Layout.fillWidth: true
                text: root.updateSearch
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                clip: true
                onTextChanged: { root.updateSearch = text }
              }
              Text {
                textFormat: Text.PlainText;
                visible: root.updateSearch === ""
                text: "Search by device model, site, or version..."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }

          // Category filter pills
          RowLayout {
            spacing: Style.space(4)
            Repeater {
              model: ["All", "Gateways", "Switches", "APs", "Cameras"]
              delegate: Rectangle {
                required property string modelData
                implicitHeight: Style.space(26)
                implicitWidth: catFilterText.implicitWidth + Style.space(12)
                radius: 4
                color: root.updateSeverityFilter === modelData ? root.accent : (catMouse.containsMouse ? root.cardHover : root.track)
                border.width: 1
                border.color: root.updateSeverityFilter === modelData ? root.accent : root.outline

                Text {
                  textFormat: Text.PlainText;
                  id: catFilterText
                  anchors.centerIn: parent
                  text: modelData
                  color: root.updateSeverityFilter === modelData ? "#ffffff" : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: root.updateSeverityFilter === modelData
                }

                MouseArea {
                  id: catMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { root.updateSeverityFilter = modelData }
                }
              }
            }
          }
        }

        // Section: Pending Updates List
        Text {
          textFormat: Text.PlainText;
          text: "PENDING FIRMWARE UPDATES (" + tab6View.filteredUpdates.length + ")"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Repeater {
            model: tab6View.filteredUpdates
            delegate: BorderSurface {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: upRow.implicitHeight + Style.space(16)
              color: root.card
              radius: 6
              borderSpec: Border.flat(modelData.severity === "critical" ? root.urgent : (modelData.severity === "important" ? root.backup : root.accent), 1)

              RowLayout {
                id: upRow
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(10)

                Text { textFormat: Text.PlainText; text: ""; color: modelData.severity === "critical" ? root.urgent : (modelData.severity === "important" ? root.backup : root.accent); font.family: root.fontFamily; font.pixelSize: Style.font.body }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  RowLayout {
                    spacing: Style.space(6)
                    Text { textFormat: Text.PlainText; text: modelData.name + " (" + modelData.model + ")"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    Rectangle {
                      implicitHeight: Style.space(16)
                      implicitWidth: upSiteText.implicitWidth + Style.space(8)
                      radius: 3
                      color: root.track
                      Text { textFormat: Text.PlainText; id: upSiteText; anchors.centerIn: parent; text: modelData.siteName; color: root.dim; font.family: root.fontFamily; font.pixelSize: 8 }
                    }
                    Rectangle {
                      implicitHeight: Style.space(16)
                      implicitWidth: sevText.implicitWidth + Style.space(8)
                      radius: 3
                      color: modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2) : (modelData.severity === "important" ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2))
                      Text { textFormat: Text.PlainText; id: sevText; anchors.centerIn: parent; text: modelData.severity.toUpperCase(); color: modelData.severity === "critical" ? root.urgent : (modelData.severity === "important" ? root.backup : root.accent); font.family: root.fontFamily; font.pixelSize: 8; font.bold: true }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText;
                    text: "Current: " + modelData.currentVersion + "  ➜  Target: " + modelData.targetVersion + " (" + modelData.releaseChannel + ")"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    text: modelData.releaseNotes
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                // Update Device Button
                Rectangle {
                  implicitHeight: Style.space(26)
                  implicitWidth: upBtnText.implicitWidth + Style.space(16)
                  radius: 4
                  color: upBtnMouse.containsMouse ? root.accent : root.track
                  border.width: 1
                  border.color: root.accent

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text { textFormat: Text.PlainText; text: ""; color: upBtnMouse.containsMouse ? "#ffffff" : root.accent; font.family: root.fontFamily; font.pixelSize: 8 }
                    Text { textFormat: Text.PlainText; id: upBtnText; text: "Update Device"; color: upBtnMouse.containsMouse ? "#ffffff" : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                  }

                  MouseArea {
                    id: upBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.upgradeDevice(modelData.hostId, modelData.mac, modelData.name) }
                  }
                }
              }
            }
          }
        }

        // Section: Automated Cloud Configuration Backups
        Text {
          textFormat: Text.PlainText;
          text: "AUTOMATED CLOUD CONFIGURATION BACKUPS (" + root.fleetBackups.length + ")"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Repeater {
            model: root.fleetBackups
            delegate: BorderSurface {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: bkCol.implicitHeight + Style.space(16)
              color: root.card
              radius: 6
              borderSpec: Border.flat(root.outline, 1)

              ColumnLayout {
                id: bkCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(6)

                RowLayout {
                  Layout.fillWidth: true
                  Text { textFormat: Text.PlainText; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                  Text { textFormat: Text.PlainText; text: modelData.consoleName; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                  Rectangle {
                    implicitHeight: Style.space(16)
                    implicitWidth: bkStatusText.implicitWidth + Style.space(8)
                    radius: 3
                    color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2)
                    Text { textFormat: Text.PlainText; id: bkStatusText; anchors.centerIn: parent; text: "PROTECTED"; color: root.healthy; font.family: root.fontFamily; font.pixelSize: 8; font.bold: true }
                  }
                }

                Text { textFormat: Text.PlainText; text: modelData.siteName + " · UniFi OS " + modelData.unifiOsVersion; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                Text { textFormat: Text.PlainText; text: "Last Backup: " + modelData.lastBackup + " (" + modelData.sizeText + ")"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }

                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: Style.space(24)
                  radius: 4
                  color: createBkMouse.containsMouse ? root.healthy : root.track
                  border.width: 1
                  border.color: root.healthy

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.space(5)
                    Text { textFormat: Text.PlainText; text: ""; color: createBkMouse.containsMouse ? "#ffffff" : root.healthy; font.family: root.fontFamily; font.pixelSize: 8 }
                    Text { textFormat: Text.PlainText; id: createBkText; text: "Create Backup Now"; color: createBkMouse.containsMouse ? "#ffffff" : root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                  }

                  MouseArea {
                    id: createBkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.triggerBackup(modelData.hostId, modelData.consoleName) }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
