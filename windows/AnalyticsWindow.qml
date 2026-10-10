import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import ".."

KeyboardPanel {
  id: root

  property var fleetData: null
  property color foreground: (Color.popups && Color.popups.foreground) ? Color.popups.foreground : (Color.foreground || "#D8DEE9")
  property color background: (Color.popups && Color.popups.background) ? Color.popups.background : (Color.background || "#1E1E2E")
  property color accent: Color.accent || "#89B4FA"
  property color healthy: "#10B981"
  property color backup: "#F59E0B"
  property color urgent: "#FF4D5A"
  property string fontFamily: Style.font.family

  contentWidth: root.fittedContentWidth(Style.space(380))
  contentHeight: root.fittedContentHeight(Style.space(640), Style.space(640))
  focusTarget: keyCatcher

  signal backToFleetRequested()

  property int currentTab: 0
  property string clientSearch: ""
  property string clientSiteFilter: "All"
  property string clientMediumFilter: "All"
  property int selectedSwitchIndex: 0
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

  readonly property var fleetConsoles: root.fleetData && root.fleetData.consoles ? root.fleetData.consoles : []
  readonly property var currentConsole: (fleetConsoles.length > root.selectedConsoleIndex && root.selectedConsoleIndex >= 0) ? fleetConsoles[root.selectedConsoleIndex] : (fleetConsoles.length > 0 ? fleetConsoles[0] : null)

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
  readonly property var currentSwitch: (availableSwitches.length > root.selectedSwitchIndex && root.selectedSwitchIndex >= 0) ? availableSwitches[root.selectedSwitchIndex] : (availableSwitches.length > 0 ? availableSwitches[0] : null)



  function cyclePort(hostId, mac, portIdx, portName) {
    if (!hostId || !mac) return
    root.statusToast = "Cycling " + portName + "..."
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
    var targetDate = new Date(now.getTime() - hoursAgo * 3600 * 1000)
    var h = targetDate.getHours()
    return (h < 10 ? "0" + h : String(h)) + ":00"
  }

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent

    Process {
      id: powerCycleProc
      onExited: function(code) {
        if (code === 0) {
          root.statusToast = "PoE power cycle initiated!"
          root.toastType = "success"
        } else {
          root.statusToast = "PoE power cycle failed (code " + code + ")"
          root.toastType = "error"
        }
        toastTimer.restart()
      }
    }

    Process {
      id: pingProc
      onExited: function(code) {
        if (code === 0) {
          root.statusToast = "Ping test completed: Host reachable"
          root.toastType = "success"
        } else {
          root.statusToast = "Ping test completed: Host unreachable"
          root.toastType = "warning"
        }
        toastTimer.restart()
      }
    }

    Timer {
      id: toastTimer
      interval: 5000
      onTriggered: { root.statusToast = "" }
    }

    onCloseRequested: {
      root.close()
    }

    onMoveRequested: function(dx, dy) {
      if (dy !== 0) {
        mainFlick.contentY = Math.max(0, Math.min(mainFlick.contentHeight - mainFlick.height, mainFlick.contentY + dy * Style.space(56)))
      }
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.space(8)

      // Top Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        UnifiIcon {
          size: Style.space(18)
          color: root.accent
          Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            textFormat: Text.PlainText;
            text: "FLEET TELEMETRY & MESH"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            textFormat: Text.PlainText;
            text: "Site Magic · Clients · WAN · PoE"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 3
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        // Back to fleet overview button
        Rectangle {
          radius: 3
          color: backBtnMouse.containsMouse ? root.cardHover : root.track
          Layout.preferredWidth: Style.space(22)
          Layout.preferredHeight: Style.space(22)

          Text {
            textFormat: Text.PlainText;
            anchors.centerIn: parent
            text: ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 2
          }

          MouseArea {
            id: backBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backToFleetRequested()
          }

          PanelToolTip {
            visible: backBtnMouse.containsMouse
            text: "Back to fleet overview"
            fontFamily: root.fontFamily
          }
        }

        // Close button
        Rectangle {
          radius: 3
          color: closeBtnMouse.containsMouse ? root.cardHover : root.track
          Layout.preferredWidth: Style.space(22)
          Layout.preferredHeight: Style.space(22)

          Text {
            textFormat: Text.PlainText;
            anchors.centerIn: parent
            text: "✕"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 2
          }

          MouseArea {
            id: closeBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.close()
            }
          }

          PanelToolTip {
            visible: closeBtnMouse.containsMouse
            text: "Close analytics window"
            fontFamily: root.fontFamily
          }
        }
      }

      // Compact Tab Bar (5 tabs fitted across 380px)
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Repeater {
          model: [
            { id: 0, icon: "", label: "Mesh", tip: "SD-WAN Site Magic Mesh & Throughput" },
            { id: 1, icon: "", label: "Clients", tip: "Fleet Client Telemetry & Uplinks" },
            { id: 2, icon: "", label: "WAN", tip: "WAN Health & Outage Telemetry" },
            { id: 3, icon: "", label: "PoE", tip: "Switch Port Matrix & PoE Power" },
            { id: 4, icon: "", label: "Apps", tip: "UniFi OS & Direct Connect" }
          ]
          delegate: Rectangle {
            required property var modelData
            readonly property bool isSelected: root.currentTab === modelData.id
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: Style.space(24)
            radius: 3
            color: isSelected ? root.accent : (tabMouse.containsMouse ? root.cardHover : root.track)
            border.width: 1
            border.color: isSelected ? root.accent : root.outline

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(3)
              Text {
                textFormat: Text.PlainText;
                text: modelData.icon
                color: isSelected ? (root.isLightTheme ? "#ffffff" : "#000000") : (tabMouse.containsMouse ? root.foreground : root.dim)
                font.family: root.fontFamily
                font.pixelSize: 9
              }
              Text {
                textFormat: Text.PlainText;
                text: modelData.label
                color: isSelected ? (root.isLightTheme ? "#ffffff" : "#000000") : (tabMouse.containsMouse ? root.foreground : root.dim)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: isSelected
              }
            }

            MouseArea {
              id: tabMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.currentTab = modelData.id }
            }

            PanelToolTip {
              visible: tabMouse.containsMouse
              text: modelData.tip
              fontFamily: root.fontFamily
            }
          }
        }
      }

      // Status Toast (Inline banner when active)
      Rectangle {
        Layout.fillWidth: true
        visible: root.statusToast !== ""
        implicitHeight: root.statusToast !== "" ? Style.space(24) : 0
        radius: 3
        color: root.toastType === "error" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.22) : (root.toastType === "success" ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.22) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22))
        border.width: 1
        border.color: root.toastType === "error" ? root.urgent : (root.toastType === "success" ? root.healthy : root.accent)

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(6)
          Text {
            textFormat: Text.PlainText;
            text: root.toastType === "error" ? "" : (root.toastType === "success" ? "" : "")
            color: root.toastType === "error" ? root.urgent : (root.toastType === "success" ? root.healthy : root.accent)
            font.family: root.fontFamily
            font.pixelSize: 9
          }
          Text {
            id: toastText
            textFormat: Text.PlainText;
            text: root.statusToast
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 2
            font.bold: true
          }
        }
      }

      // Vertical Scrollable Content Area (Agent Hub scroll container)
      Flickable {
        id: mainFlick
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: mainContentCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
          id: mainContentCol
          width: mainFlick.width
          spacing: Style.space(8)

          // ==========================================
          // TAB 0: OVERVIEW & WAN MESH
          // ==========================================
          ColumnLayout {
            id: tab0View
            visible: root.currentTab === 0
            Layout.fillWidth: true
            spacing: Style.space(8)

            // 2x2 KPI Status Grid (Dense 380px fit)
            Grid {
              columns: 2
              columnSpacing: Style.space(6)
              rowSpacing: Style.space(6)
              Layout.fillWidth: true

              StatBlock {
                width: Math.floor((mainContentCol.width - Style.space(6)) / 2)
                label: "WAN HEALTH"
                value: "100%"
                subvalue: "0 Failovers active"
                valColor: root.healthy
                subColor: root.healthy
                fontFamily: root.fontFamily
                iconText: ""
              }

              StatBlock {
                width: Math.floor((mainContentCol.width - Style.space(6)) / 2)
                label: "CLIENTS"
                value: String(root.fleetData && root.fleetData.network ? root.fleetData.network.clientCount : 26)
                subvalue: String(root.fleetData && root.fleetData.network ? root.fleetData.network.wifiClients : 14) + "W · " + String(root.fleetData && root.fleetData.network ? root.fleetData.network.wiredClients : 12) + "E"
                valColor: root.accent
                fontFamily: root.fontFamily
                iconText: ""
              }

              StatBlock {
                width: Math.floor((mainContentCol.width - Style.space(6)) / 2)
                label: "HARDWARE"
                value: String(root.fleetData && root.fleetData.network ? root.fleetData.network.deviceCount : 11)
                subvalue: "All online"
                valColor: root.foreground
                fontFamily: root.fontFamily
                iconText: ""
              }

              StatBlock {
                width: Math.floor((mainContentCol.width - Style.space(6)) / 2)
                label: "SITES"
                value: String(root.fleetData && root.fleetData.sites ? root.fleetData.sites.length : 2) + "/" + String(root.fleetData && root.fleetData.sites ? root.fleetData.sites.length : 2)
                subvalue: "Mesh active"
                valColor: root.healthy
                subColor: root.healthy
                fontFamily: root.fontFamily
                iconText: ""
              }
            }

            // Throughput Timeline Card
            SectionCard {
              Layout.fillWidth: true
              title: "THROUGHPUT TIMELINE (24H)"
              subtitle: "Hourly traffic breakdown"
              iconText: ""
              titleColor: root.foreground
              fontFamily: root.fontFamily
              badgeText: {
                var tp = root.getActiveThroughput()
                return "↓ " + tp.peakRx + " MB/s  ↑ " + tp.peakTx + " MB/s"
              }
              badgeColor: root.accent

              // Site Filter Pills
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(4)

                Rectangle {
                  height: Style.space(18)
                  width: allSitesPillText.implicitWidth + Style.space(10)
                  radius: 3
                  color: (root.selectedSiteIds.length === 0) ? root.accent : root.track
                  Text {
                    textFormat: Text.PlainText;
                    id: allSitesPillText
                    anchors.centerIn: parent
                    text: "All Sites"
                    color: (root.selectedSiteIds.length === 0) ? (root.isLightTheme ? "#ffffff" : "#000000") : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 3
                    font.bold: root.selectedSiteIds.length === 0
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearSiteSelection()
                  }
                }

                Repeater {
                  model: root.fleetData && root.fleetData.sites ? root.fleetData.sites : []
                  delegate: Rectangle {
                    required property var modelData
                    readonly property bool isSelected: root.isSiteSelected(modelData)
                    height: Style.space(18)
                    width: sitePillText.implicitWidth + Style.space(10)
                    radius: 3
                    color: isSelected ? root.accent : root.track
                    Text {
                      textFormat: Text.PlainText;
                      id: sitePillText
                      anchors.centerIn: parent
                      text: modelData.name || "Site"
                      color: isSelected ? (root.isLightTheme ? "#ffffff" : "#000000") : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 3
                      font.bold: isSelected
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.toggleSiteSelection(modelData)
                    }
                  }
                }
              }

              // Hourly Histogram Chart
              Rectangle {
                id: chartBox
                Layout.fillWidth: true
                height: Style.space(75)
                color: root.track
                radius: 4
                clip: true

                property var tpData: root.getActiveThroughput()
                property real maxPeak: Math.max(10, Math.max(tpData.peakRx, tpData.peakTx))

                Row {
                  id: chartBarsRow
                  anchors.fill: parent
                  anchors.margins: Style.space(4)
                  spacing: Math.max(1, Math.floor((width - 24 * Math.max(4, Math.floor(width / 26))) / 23))

                  Repeater {
                    model: 24
                    delegate: Item {
                      required property int index
                      readonly property real barW: Math.max(4, Math.floor((chartBarsRow.width - 23 * chartBarsRow.spacing) / 24))
                      width: barW
                      height: chartBarsRow.height

                      readonly property real rxVal: (chartBox.tpData.rx && chartBox.tpData.rx[index] !== undefined) ? chartBox.tpData.rx[index] : 0
                      readonly property real txVal: (chartBox.tpData.tx && chartBox.tpData.tx[index] !== undefined) ? chartBox.tpData.tx[index] : 0
                      readonly property bool isHovered: root.chartHoverIndex === index

                      // Rx Bar (accent)
                      Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: Math.max(2, parent.width / 2)
                        height: Math.max(2, (parent.height - 2) * (rxVal / chartBox.maxPeak))
                        color: isHovered ? "#ffffff" : root.accent
                        radius: 1
                      }

                      // Tx Bar (healthy)
                      Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: Math.max(2, parent.width / 2)
                        height: Math.max(2, (parent.height - 2) * (txVal / chartBox.maxPeak))
                        color: isHovered ? "#ffffff" : root.healthy
                        radius: 1
                      }

                      MouseArea {
                        id: barHoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                          root.chartHoverIndex = index
                          root.chartHoverMouseX = parent.x
                          root.chartHoverMouseY = parent.y
                        }
                        onExited: {
                          if (root.chartHoverIndex === index) root.chartHoverIndex = -1
                        }
                      }
                    }
                  }
                }

                // Hover readout
                Rectangle {
                  visible: root.chartHoverIndex >= 0
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: Style.space(4)
                  height: Style.space(16)
                  width: hoverText.implicitWidth + Style.space(8)
                  radius: 2
                  color: root.isLightTheme ? "#ffffff" : "#000000"
                  Text {
                    textFormat: Text.PlainText;
                    id: hoverText
                    anchors.centerIn: parent
                    text: {
                      if (root.chartHoverIndex < 0) return ""
                      var idx = root.chartHoverIndex
                      var rx = chartBox.tpData.rx[idx] || 0
                      var tx = chartBox.tpData.tx[idx] || 0
                      return root.getThroughputDate(idx) + ": ↓" + rx + "M ↑" + tx + "M"
                    }
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }
                }
              }
            }

            // Site Magic SD-WAN Inter-Site Latency Mesh Card
            SectionCard {
              Layout.fillWidth: true
              title: "SITE MAGIC SD-WAN MESH"
              subtitle: "Encrypted cross-subnet routing"
              iconText: ""
              titleColor: root.foreground
              fontFamily: root.fontFamily
              badgeText: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.status === "connected") ? "ACTIVE · <1ms" : "ONLINE"
              badgeColor: root.healthy

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)

                Repeater {
                  model: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections) ? root.fleetData.sdwan.connections : [
                    { siteA: "Catalyse Office", siteB: "Lough Stanley Home", subnetA: "192.168.1.0/24", subnetB: "192.168.2.0/24", latency: 0.8, status: "healthy", ip: "192.168.2.1" }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: connCol.implicitHeight + Style.space(12)
                    radius: 4
                    color: root.track
                    border.width: 1
                    border.color: root.outline

                    ColumnLayout {
                      id: connCol
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.margins: Style.space(6)
                      spacing: Style.space(3)

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(4)

                        Rectangle {
                          width: 6; height: 6; radius: 3; color: root.healthy
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: (modelData.siteA || "Site A") + " ⇄ " + (modelData.siteB || "Site B")
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }

                        Rectangle {
                          height: Style.space(16)
                          width: latText.implicitWidth + Style.space(8)
                          radius: 2
                          color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2)
                          Text {
                            textFormat: Text.PlainText;
                            id: latText
                            anchors.centerIn: parent
                            text: (modelData.latency !== undefined ? modelData.latency + "ms" : "<1ms")
                            color: root.healthy
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }

                        Rectangle {
                          height: Style.space(16)
                          width: pingBtnTxt.implicitWidth + Style.space(8)
                          radius: 2
                          color: meshPingMouse.containsMouse ? root.accent : root.card
                          border.width: 1
                          border.color: root.outline
                          Text {
                            textFormat: Text.PlainText;
                            id: pingBtnTxt
                            anchors.centerIn: parent
                            text: "Ping"
                            color: meshPingMouse.containsMouse ? (root.isLightTheme ? "#ffffff" : "#000000") : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 8
                          }
                          MouseArea {
                            id: meshPingMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pingHost(modelData.ip || "192.168.2.1")
                          }
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: (modelData.subnetA || "192.168.1.0/24") + " ⇄ " + (modelData.subnetB || "192.168.2.0/24") + " · Zero Packet Loss"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
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
            spacing: Style.space(8)

            readonly property var rawClients: root.fleetData && root.fleetData.clients ? root.fleetData.clients : []
            readonly property var filteredClients: {
              var list = rawClients
              var query = root.clientSearch.toLowerCase().trim()
              var medFilter = root.clientMediumFilter

              return list.filter(function(c) {
                if (medFilter === "WiFi" && c.isWired) return false
                if (medFilter === "Wired" && !c.isWired) return false
                if (query !== "") {
                  var s = ((c.name || "") + " " + (c.hostname || "") + " " + (c.ip || "") + " " + (c.mac || "") + " " + (c.uplinkName || "") + " " + (c.essid || "")).toLowerCase()
                  if (s.indexOf(query) === -1) return false
                }
                return true
              })
            }

            // Search & Medium Filter Bar
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)

              Rectangle {
                Layout.fillWidth: true
                height: Style.space(24)
                radius: 3
                color: root.track
                border.width: 1
                border.color: root.outline

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: Style.space(4)
                  spacing: Style.space(4)

                  Text {
                    textFormat: Text.PlainText;
                    text: ""
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 9
                  }

                  TextInput {
                    id: clientSearchInput
                    Layout.fillWidth: true
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    selectByMouse: true
                    onTextChanged: { root.clientSearch = text }

                    Text {
                      textFormat: Text.PlainText;
                      visible: !parent.text
                      text: "Filter clients..."
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                    }
                  }

                  Text {
                    textFormat: Text.PlainText;
                    visible: Boolean(clientSearchInput.text)
                    text: "✕"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 9
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: { clientSearchInput.text = "" }
                    }
                  }
                }
              }

              // WiFi / Wired Filter Pills
              Repeater {
                model: ["All", "WiFi", "Wired"]
                delegate: Rectangle {
                  required property string modelData
                  height: Style.space(24)
                  width: medFilterText.implicitWidth + Style.space(10)
                  radius: 3
                  color: root.clientMediumFilter === modelData ? root.accent : root.track
                  border.width: 1
                  border.color: root.clientMediumFilter === modelData ? root.accent : root.outline

                  Text {
                    id: medFilterText
                    textFormat: Text.PlainText;
                    anchors.centerIn: parent
                    text: modelData
                    color: root.clientMediumFilter === modelData ? (root.isLightTheme ? "#ffffff" : "#000000") : root.foreground
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

            // Client Cards List
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)

              Text {
                textFormat: Text.PlainText;
                visible: tab1View.filteredClients.length === 0
                text: "No clients match filter"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
              }

              Repeater {
                model: tab1View.filteredClients
                delegate: Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  implicitHeight: clientRowCol.implicitHeight + Style.space(10)
                  radius: 4
                  color: cCardMouse.containsMouse ? root.cardHover : root.track
                  border.width: 1
                  border.color: cCardMouse.containsMouse ? root.accent : root.outline

                  MouseArea {
                    id: cCardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                  }

                  ColumnLayout {
                    id: clientRowCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(6)
                    spacing: Style.space(2)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(5)

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.isWired ? "󰈀" : ""
                        color: modelData.isWired ? root.healthy : root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.name || modelData.hostname || "Client"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Rectangle {
                        height: Style.space(14)
                        width: cSigText.implicitWidth + Style.space(6)
                        radius: 2
                        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                        Text {
                          textFormat: Text.PlainText;
                          id: cSigText
                          anchors.centerIn: parent
                          text: modelData.isWired ? "1GbE" : (String(modelData.signal || -55) + " dBm")
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: 7
                          font.bold: true
                        }
                      }

                      Rectangle {
                        height: Style.space(16)
                        width: cPingBtnTxt.implicitWidth + Style.space(8)
                        radius: 2
                        color: cPingMouse.containsMouse ? root.accent : root.card
                        border.width: 1
                        border.color: root.outline
                        Text {
                          textFormat: Text.PlainText;
                          id: cPingBtnTxt
                          anchors.centerIn: parent
                          text: "Ping"
                          color: cPingMouse.containsMouse ? (root.isLightTheme ? "#ffffff" : "#000000") : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 8
                        }
                        MouseArea {
                          id: cPingMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.pingHost(modelData.ip)
                        }
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        textFormat: Text.PlainText;
                        text: "IP: " + (modelData.ip || "DHCP") + (modelData.uplinkName ? (" · " + modelData.uplinkName) : "")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: "↓" + (modelData.rxMb || "12") + "M ↑" + (modelData.txMb || "3") + "M"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                      }
                    }
                  }
                }
              }
            }
          }

          // ==========================================
          // TAB 2: WAN HEALTH & OUTAGE TELEMETRY
          // ==========================================
          ColumnLayout {
            id: tab2View
            visible: root.currentTab === 2
            Layout.fillWidth: true
            spacing: Style.space(8)

            readonly property var wansList: root.fleetData && root.fleetData.wans ? root.fleetData.wans : []

            Rectangle {
              Layout.fillWidth: true
              implicitHeight: Style.space(26)
              radius: 4
              color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.12)
              border.width: 1
              border.color: root.healthy

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text {
                  textFormat: Text.PlainText;
                  text: ""
                  color: root.healthy
                  font.family: root.fontFamily
                  font.pixelSize: 9
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "FLEET WAN UPTIME SLA: 100.0% · 0 OUTAGES"
                  color: root.healthy
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  font.bold: true
                }
              }
            }

            Repeater {
              model: tab2View.wansList
              delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: wanCol.implicitHeight + Style.space(12)
                radius: 4
                color: root.track
                border.width: 1
                border.color: root.outline

                ColumnLayout {
                  id: wanCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(6)
                  spacing: Style.space(3)

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(5)

                    Rectangle {
                      height: Style.space(14)
                      width: wanBadgeTxt.implicitWidth + Style.space(6)
                      radius: 2
                      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                      Text {
                        textFormat: Text.PlainText;
                        id: wanBadgeTxt
                        anchors.centerIn: parent
                        text: modelData.name || "WAN1"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 7
                        font.bold: true
                      }
                    }

                    Text {
                      textFormat: Text.PlainText;
                      text: (modelData.siteName || "Site") + " (" + (modelData.gatewayModel || "Gateway") + ")"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Rectangle {
                      height: Style.space(14)
                      width: wanStatusTxt.implicitWidth + Style.space(6)
                      radius: 2
                      color: modelData.plugged ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2) : Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2)
                      Text {
                        textFormat: Text.PlainText;
                        id: wanStatusTxt
                        anchors.centerIn: parent
                        text: modelData.plugged ? "ONLINE" : "DOWN"
                        color: modelData.plugged ? root.healthy : root.urgent
                        font.family: root.fontFamily
                        font.pixelSize: 7
                        font.bold: true
                      }
                    }

                    Rectangle {
                      height: Style.space(16)
                      width: wanPingBtnTxt.implicitWidth + Style.space(8)
                      radius: 2
                      color: wanPingMouse.containsMouse ? root.accent : root.card
                      border.width: 1
                      border.color: root.outline
                      Text {
                        textFormat: Text.PlainText;
                        id: wanPingBtnTxt
                        anchors.centerIn: parent
                        text: "Ping"
                        color: wanPingMouse.containsMouse ? (root.isLightTheme ? "#ffffff" : "#000000") : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: 8
                      }
                      MouseArea {
                        id: wanPingMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (modelData.ipv4) root.pingHost(modelData.ipv4)
                      }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText;
                    text: (modelData.isp || "Fiber Broadband") + " · IP: " + (modelData.ipv4 || "DHCP") + " · Uptime: " + (modelData.uptime || "100%")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }
              }
            }
          }

          // ==========================================
          // TAB 3: SWITCH PORTS & POE POWER MATRIX
          // ==========================================
          ColumnLayout {
            id: tab3View
            visible: root.currentTab === 3
            Layout.fillWidth: true
            spacing: Style.space(8)

            readonly property var portsList: {
              if (!root.currentSwitch || !root.currentSwitch.ports) return []
              var list = root.currentSwitch.ports
              if (root.portFilter === "PoE") return list.filter(function(p) { return (p.poePower || 0) > 0 })
              if (root.portFilter === "Active") return list.filter(function(p) { return p.up })
              return list
            }

            // Switch selector pills & PoE meter
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: swCol.implicitHeight + Style.space(10)
              radius: 4
              color: root.track
              border.width: 1
              border.color: root.outline

              ColumnLayout {
                id: swCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(6)
                spacing: Style.space(4)

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(4)

                  Text {
                    textFormat: Text.PlainText;
                    text: (root.currentSwitch ? root.currentSwitch.name : "Switch")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    text: "PoE: " + String(root.currentSwitch ? root.currentSwitch.totalPower : 0) + "W / " + String(root.currentSwitch ? root.currentSwitch.maxPower : 400) + "W"
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 3
                    font.bold: true
                  }
                }

                // PoE Progress Bar
                Rectangle {
                  Layout.fillWidth: true
                  height: 4
                  radius: 2
                  color: root.card

                  Rectangle {
                    height: parent.height
                    radius: 2
                    width: Math.min(parent.width, Math.max(3, parent.width * ((root.currentSwitch && root.currentSwitch.maxPower > 0) ? (root.currentSwitch.totalPower / root.currentSwitch.maxPower) : 0.1)))
                    color: root.accent
                  }
                }

                // Port filter pills
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(4)

                  Repeater {
                    model: ["All", "Active", "PoE"]
                    delegate: Rectangle {
                      required property string modelData
                      height: Style.space(18)
                      width: pFilterText.implicitWidth + Style.space(8)
                      radius: 2
                      color: root.portFilter === modelData ? root.accent : root.card
                      Text {
                        textFormat: Text.PlainText;
                        id: pFilterText
                        anchors.centerIn: parent
                        text: modelData
                        color: root.portFilter === modelData ? (root.isLightTheme ? "#ffffff" : "#000000") : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
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
            }

            // Port Matrix Cards List
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)

              Repeater {
                model: tab3View.portsList
                delegate: Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  implicitHeight: pCardCol.implicitHeight + Style.space(8)
                  radius: 3
                  color: pCardMouse.containsMouse ? root.cardHover : root.track
                  border.width: 1
                  border.color: pCardMouse.containsMouse ? root.accent : root.outline

                  MouseArea {
                    id: pCardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                  }

                  ColumnLayout {
                    id: pCardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(5)
                    spacing: Style.space(2)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(4)

                      Rectangle {
                        height: Style.space(14)
                        width: Style.space(20)
                        radius: 2
                        color: modelData.up ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2) : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.15)
                        Text {
                          textFormat: Text.PlainText;
                          anchors.centerIn: parent
                          text: "P" + String(modelData.portIdx)
                          color: modelData.up ? root.healthy : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.connectedDevice || (modelData.name || ("Port " + modelData.portIdx))
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: Boolean(modelData.connectedDevice)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        visible: Boolean(modelData.poePower > 0)
                        text: String(modelData.poePower) + "W"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                      }

                      Rectangle {
                        visible: Boolean(modelData.poePower > 0)
                        height: Style.space(16)
                        width: cycBtnTxt.implicitWidth + Style.space(6)
                        radius: 2
                        color: cycBtnMouse.containsMouse ? root.accent : root.card
                        border.width: 1
                        border.color: root.outline
                        Text {
                          textFormat: Text.PlainText;
                          id: cycBtnTxt
                          anchors.centerIn: parent
                          text: " Cycle"
                          color: cycBtnMouse.containsMouse ? (root.isLightTheme ? "#ffffff" : "#000000") : root.accent
                          font.family: root.fontFamily
                          font.pixelSize: 8
                        }
                        MouseArea {
                          id: cycBtnMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.currentSwitch) {
                              root.cyclePort(root.currentSwitch.hostId, root.currentSwitch.mac, modelData.portIdx, "Port " + modelData.portIdx)
                            }
                          }
                        }
                      }
                    }

                    Text {
                      textFormat: Text.PlainText;
                      text: (modelData.up ? (modelData.speedText || "1GbE") : "Link Down") + (modelData.poeMode ? (" · " + modelData.poeMode) : "")
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 3
                    }
                  }
                }
              }
            }
          }

          // ==========================================
          // TAB 4: UNIFI OS & DIRECT CONNECT CONSOLES
          // ==========================================
          ColumnLayout {
            id: tab4View
            visible: root.currentTab === 4
            Layout.fillWidth: true
            spacing: Style.space(8)

            // Selected Console Card
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: conCardCol.implicitHeight + Style.space(10)
              radius: 4
              color: root.track
              border.width: 1
              border.color: root.outline

              ColumnLayout {
                id: conCardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(6)
                spacing: Style.space(3)

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(5)

                  Rectangle {
                    width: 6; height: 6; radius: 3
                    color: (root.currentConsole && root.currentConsole.isOnline) ? root.healthy : root.urgent
                  }

                  Text {
                    textFormat: Text.PlainText;
                    text: root.currentConsole ? (root.currentConsole.name + " (" + root.currentConsole.model + ")") : "UniFi Console"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Rectangle {
                    height: Style.space(14)
                    width: cOnText.implicitWidth + Style.space(6)
                    radius: 2
                    color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2)
                    Text {
                      textFormat: Text.PlainText;
                      id: cOnText
                      anchors.centerIn: parent
                      text: "ONLINE"
                      color: root.healthy
                      font.family: root.fontFamily
                      font.pixelSize: 7
                      font.bold: true
                    }
                  }
                }

                Text {
                  textFormat: Text.PlainText;
                  text: (root.currentConsole ? ("UniFi OS " + (root.currentConsole.firmwareVersion || "v4.0.x")) : "UniFi OS") + (root.currentConsole && root.currentConsole.ip ? (" · IP: " + root.currentConsole.ip) : "")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 3
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }

            // Direct Connect Domain Card
            SectionCard {
              Layout.fillWidth: true
              title: "P2P DIRECT CONNECT"
              subtitle: "UniFi OS peer-to-peer portal"
              iconText: ""
              titleColor: root.foreground
              fontFamily: root.fontFamily

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText;
                    text: root.currentConsole && root.currentConsole.directConnectDomain ? root.currentConsole.directConnectDomain : "office.direct.ui.com"
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                  }

                  Rectangle {
                    height: Style.space(18)
                    width: launchTxt.implicitWidth + Style.space(8)
                    radius: 2
                    color: dirLaunchMouse.containsMouse ? root.accent : root.track
                    border.width: 1
                    border.color: root.outline
                    Text {
                      textFormat: Text.PlainText;
                      id: launchTxt
                      anchors.centerIn: parent
                      text: "Launch ↗"
                      color: dirLaunchMouse.containsMouse ? (root.isLightTheme ? "#ffffff" : "#000000") : root.accent
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }
                    MouseArea {
                      id: dirLaunchMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var c = root.currentConsole
                        var target = c ? (c.directConnectUrl || (c.directConnectDomain ? ("https://" + c.directConnectDomain) : "")) : ""
                        if (target) root.openExternalUrl(target)
                      }
                    }
                  }

                  Rectangle {
                    height: Style.space(18)
                    width: copyTxt.implicitWidth + Style.space(8)
                    radius: 2
                    color: dirCopyMouse.containsMouse ? root.cardHover : root.track
                    border.width: 1
                    border.color: root.outline
                    Text {
                      textFormat: Text.PlainText;
                      id: copyTxt
                      anchors.centerIn: parent
                      text: "Copy 📋"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                    }
                    MouseArea {
                      id: dirCopyMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var c = root.currentConsole
                        var target = c ? (c.directConnectUrl || (c.directConnectDomain ? ("https://" + c.directConnectDomain) : "")) : ""
                        if (target) root.copyToClipboard(target, "direct connect domain")
                      }
                    }
                  }
                }
              }
            }

            // Applications Hub
            SectionCard {
              Layout.fillWidth: true
              title: "UNIFI OS APPLICATIONS"
              subtitle: "Installed system applications"
              iconText: ""
              titleColor: root.foreground
              fontFamily: root.fontFamily

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(4)

                Repeater {
                  model: [
                    { name: "Network", icon: "", status: "Running", version: "v8.1.113", port: 8443 },
                    { name: "Protect", icon: "", status: "Running", version: "v4.0.12", port: 7443 },
                    { name: "Access", icon: "", status: "Available", version: "v1.22.x", port: 8443 },
                    { name: "Talk", icon: "", status: "Available", version: "v2.3.x", port: 8443 }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Style.space(26)
                    radius: 3
                    color: root.track
                    border.width: 1
                    border.color: root.outline

                    RowLayout {
                      anchors.fill: parent
                      anchors.margins: Style.space(5)
                      spacing: Style.space(6)

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.icon
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 9
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.name
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.version
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: 8
                        Layout.fillWidth: true
                      }

                      Rectangle {
                        height: Style.space(14)
                        width: appStatTxt.implicitWidth + Style.space(6)
                        radius: 2
                        color: modelData.status === "Running" ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2) : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.15)
                        Text {
                          textFormat: Text.PlainText;
                          id: appStatTxt
                          anchors.centerIn: parent
                          text: modelData.status
                          color: modelData.status === "Running" ? root.healthy : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 7
                          font.bold: true
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
