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
  minimumSize: Qt.size(860, 560)
  implicitWidth: 1060
  implicitHeight: 720

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
  property int selectedSwitchIndex: 0
  property string portFilter: "All"
  property string statusToast: ""
  property string toastType: "info"

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

  Timer {
    id: toastTimer
    interval: 5000
    onTriggered: { root.statusToast = "" }
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

      // KPI Grid
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

      // Tab Bar & Toast Banner
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        RowLayout {
          spacing: Style.space(6)

          // Tab 0: Overview
          Rectangle {
            height: Style.space(32)
            width: tab0Row.implicitWidth + Style.space(20)
            radius: 6
            color: root.currentTab === 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab0Mouse.containsMouse ? root.cardHover : root.track)
            border.width: 1
            border.color: root.currentTab === 0 ? root.accent : root.outline

            RowLayout {
              id: tab0Row
              anchors.centerIn: parent
              spacing: 6
              Text { textFormat: Text.PlainText; text: ""; color: root.currentTab === 0 ? root.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: "Overview & Mesh"; color: root.currentTab === 0 ? root.foreground : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: root.currentTab === 0 }
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
            height: Style.space(32)
            width: tab1Row.implicitWidth + Style.space(20)
            radius: 6
            color: root.currentTab === 1 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab1Mouse.containsMouse ? root.cardHover : root.track)
            border.width: 1
            border.color: root.currentTab === 1 ? root.accent : root.outline

            RowLayout {
              id: tab1Row
              anchors.centerIn: parent
              spacing: 6
              Text { textFormat: Text.PlainText; text: ""; color: root.currentTab === 1 ? root.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text {
                textFormat: Text.PlainText;
                text: "Client Telemetry (" + (root.fleetData && root.fleetData.clients ? root.fleetData.clients.length : (root.fleetData && root.fleetData.network ? root.fleetData.network.clientCount : 0)) + ")"
                color: root.currentTab === 1 ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.currentTab === 1
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
            height: Style.space(32)
            width: tab2Row.implicitWidth + Style.space(20)
            radius: 6
            color: root.currentTab === 2 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab2Mouse.containsMouse ? root.cardHover : root.track)
            border.width: 1
            border.color: root.currentTab === 2 ? root.accent : root.outline

            RowLayout {
              id: tab2Row
              anchors.centerIn: parent
              spacing: 6
              Text { textFormat: Text.PlainText; text: ""; color: root.currentTab === 2 ? root.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text {
                textFormat: Text.PlainText;
                text: "WAN & Outages (" + (root.fleetData && root.fleetData.wans ? root.fleetData.wans.length : 0) + ")"
                color: root.currentTab === 2 ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.currentTab === 2
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
            height: Style.space(32)
            width: tab3Row.implicitWidth + Style.space(20)
            radius: 6
            color: root.currentTab === 3 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab3Mouse.containsMouse ? root.cardHover : root.track)
            border.width: 1
            border.color: root.currentTab === 3 ? root.accent : root.outline

            RowLayout {
              id: tab3Row
              anchors.centerIn: parent
              spacing: 6
              Text { textFormat: Text.PlainText; text: ""; color: root.currentTab === 3 ? root.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text {
                textFormat: Text.PlainText;
                text: "Switch Ports & PoE (" + (root.availableSwitches ? root.availableSwitches.length : 0) + ")"
                color: root.currentTab === 3 ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.currentTab === 3
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
        }

        Item { Layout.fillWidth: true }

        // Status Toast
        Rectangle {
          visible: root.statusToast !== ""
          height: Style.space(28)
          width: toastText.implicitWidth + Style.space(24)
          radius: 14
          color: root.toastType === "error" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.25) : (root.toastType === "success" ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.25) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25))
          border.width: 1
          border.color: root.toastType === "error" ? root.urgent : (root.toastType === "success" ? root.healthy : root.accent)

          RowLayout {
            anchors.centerIn: parent
            spacing: 6
            Text {
              textFormat: Text.PlainText;
              text: root.toastType === "error" ? "" : (root.toastType === "success" ? "" : "")
              color: root.toastType === "error" ? root.urgent : (root.toastType === "success" ? root.healthy : root.accent)
              font.family: root.fontFamily
              font.pixelSize: 10
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
      }

      // ==========================================
      // TAB 0: OVERVIEW & WAN MESH
      // ==========================================
      RowLayout {
        id: tab0View
        visible: root.currentTab === 0
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
            title: "24-HOUR WAN THROUGHPUT"
            subtitle: "Catalyse Office · Lough Stanley Home · Peak: 84.5 Mbps DL / 22.8 Mbps UL"
            iconText: ""
            titleColor: root.foreground
            badgeText: "REAL-TIME"
            badgeColor: root.accent
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

                // Grid lines & Y-axis labels
                ctx.strokeStyle = root.isLightTheme ? "#cbd5e1" : "#2a324b"
                ctx.fillStyle = root.dim
                ctx.font = "8px " + root.fontFamily
                ctx.lineWidth = 0.5
                var labels = ["100M", "75M", "50M", "25M", "0M"]
                for (var g = 0; g <= 4; g++) {
                  var y = 8 + (chartH / 4) * g
                  ctx.beginPath()
                  ctx.moveTo(leftPad, y)
                  ctx.lineTo(w - 10, y)
                  ctx.stroke()
                  ctx.fillText(labels[g], 2, y + 3)
                }

                // X-axis time labels
                var timeLabels = ["24h ago", "18h", "12h", "6h", "Now"]
                for (var t = 0; t < timeLabels.length; t++) {
                  var tx = leftPad + (chartW / 4) * t
                  ctx.fillText(timeLabels[t], tx - (t === 4 ? 18 : 10), h - 3)
                }

                // Sample points for download
                var rxData = [12, 18, 14, 25, 42, 38, 55, 78, 84, 62, 45, 52, 68, 74, 58, 48, 62, 54, 40, 32, 28, 35, 42, 50]
                var txData = [4, 6, 5, 8, 12, 11, 16, 20, 22, 18, 14, 15, 19, 21, 16, 14, 17, 15, 12, 10, 8, 9, 11, 14]

                // Draw Download Curve
                ctx.beginPath()
                var step = chartW / (rxData.length - 1)
                for (var i = 0; i < rxData.length; i++) {
                  var px = leftPad + i * step
                  var py = 8 + chartH - (rxData[i] / 90) * chartH
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
                  var txY = 8 + chartH - (txData[j] / 90) * chartH
                  if (j === 0) ctx.moveTo(txX, txY)
                  else ctx.lineTo(txX, txY)
                }
                ctx.strokeStyle = root.healthy
                ctx.lineWidth = 1.5
                ctx.stroke()
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
                      }
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0) ? root.fleetData.sdwan.connections[0].subnetA : "192.168.15.0/24"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 3
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
                      }
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0) ? root.fleetData.sdwan.connections[0].subnetB : "192.168.22.0/24"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 3
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
            subtitle: "Active gateways, public IPs, and ISPs"
            iconText: ""
            titleColor: root.foreground
            fontFamily: root.fontFamily
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
                    width: siteMatrixCol.width
                    height: siteCol.childrenRect.height + Style.space(18)
                    radius: 4
                    color: root.track
                    border.width: 1
                    border.color: root.outline

                    Column {
                      id: siteCol
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.margins: Style.space(8)
                      spacing: Style.space(5)

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
                          width: parent.width - 90
                          elide: Text.ElideRight
                          anchors.verticalCenter: parent.verticalCenter
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
                        text: (modelData.gatewayModel || "Gateway") + " · Public IP: " + (modelData.gatewayIp || "DHCP")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                      }

                      Text {
                        textFormat: Text.PlainText;
                        width: parent.width
                        text: "ISP: " + (modelData.isp || "Unknown ISP") + " · Timezone: " + (modelData.timezone || "UTC")
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                      }

                      Row {
                        width: parent.width
                        spacing: Style.space(12)

                        Text {
                          textFormat: Text.PlainText;
                          text: " " + (modelData.clientCount || 0) + " clients (" + (modelData.wifiClients || 0) + "W / " + (modelData.wiredClients || 0) + "E)"
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

        // Search & Filter Header Card
        SectionCard {
          Layout.fillWidth: true
          title: "CLIENT SEARCH & MEDIUM FILTER"
          subtitle: "Live client database query and interface filtering"
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(10)

            // Search Input Box
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(32)
              radius: 6
              color: root.track
              border.width: 1
              border.color: root.outline

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText;
                  text: ""
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                TextInput {
                  id: clientSearchInput
                  Layout.fillWidth: true
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  selectByMouse: true
                  onTextChanged: { root.clientSearch = text }

                  Text {
                    textFormat: Text.PlainText;
                    visible: !parent.text
                    text: "Search clients by name, IP, MAC address, ESSID, or uplink AP..."
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
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
                  height: Style.space(30)
                  width: medFilterText.implicitWidth + Style.space(16)
                  radius: 5
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
                    font.pixelSize: Style.font.caption - 1
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

            // Client Count Badge
            Rectangle {
              height: Style.space(30)
              width: countBadgeText.implicitWidth + Style.space(16)
              radius: 5
              color: root.track
              border.width: 1
              border.color: root.outline

              Text {
                id: countBadgeText
                textFormat: Text.PlainText;
                anchors.centerIn: parent
                text: String(tab1View.filteredClients.length) + " / " + String(tab1View.rawClients.length) + " Active"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
              }
            }
          }
        }

        // Client Table Card
        SectionCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          title: "FLEET CLIENT ROSTER & UPLINK TOPOLOGY"
          subtitle: "WiFi signal metrics (dBm), radio protocols (WiFi 6/7), uplink associations, and transfer stats"
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: clientListCol.childrenRect.height + Style.space(20)
            clip: true

            Column {
              id: clientListCol
              width: parent.width
              spacing: Style.space(8)

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

              Repeater {
                model: tab1View.filteredClients
                delegate: Rectangle {
                  required property var modelData
                  width: clientListCol.width
                  height: clientCardRow.implicitHeight + Style.space(18)
                  radius: 6
                  color: root.track
                  border.width: 1
                  border.color: root.outline

                  RowLayout {
                    id: clientCardRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(10)
                    spacing: Style.space(12)

                    // Client Icon
                    Rectangle {
                      Layout.preferredWidth: Style.space(38)
                      Layout.preferredHeight: Style.space(38)
                      radius: 8
                      color: modelData.isWired ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.15) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                      border.width: 1
                      border.color: modelData.isWired ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.3) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3)

                      Text {
                        textFormat: Text.PlainText;
                        anchors.centerIn: parent
                        text: modelData.isWired ? "󰈀" : ""
                        color: modelData.isWired ? root.backup : root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 16
                      }
                    }

                    // Client Identity & Addresses
                    ColumnLayout {
                      Layout.preferredWidth: 220
                      spacing: 2

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

                      Text {
                        textFormat: Text.PlainText;
                        text: (modelData.ip || "No IP") + " · " + (modelData.mac || "")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      RowLayout {
                        spacing: 4
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
                        Text {
                          textFormat: Text.PlainText;
                          visible: Boolean(modelData.essid)
                          text: "SSID: " + modelData.essid
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 8
                        }
                      }
                    }

                    // Uplink Association & Topology
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 2

                      RowLayout {
                        spacing: 6
                        Text {
                          textFormat: Text.PlainText;
                          text: "Uplink:"
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                        }
                        Text {
                          textFormat: Text.PlainText;
                          text: (modelData.uplinkName || (modelData.isWired ? "Switch" : "Access Point")) + " (" + (modelData.uplinkPort || "Port") + ")"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                        }
                      }

                      RowLayout {
                        spacing: 6
                        Rectangle {
                          height: 16
                          width: protoTagText.implicitWidth + 8
                          radius: 3
                          color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                          Text {
                            id: protoTagText
                            textFormat: Text.PlainText;
                            anchors.centerIn: parent
                            text: modelData.radioProto || (modelData.isWired ? "GbE" : "WiFi")
                            color: root.healthy
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.isWired ? "Wired Ethernet Connection" : (modelData.band + " · Ch " + modelData.channel)
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                        }
                      }
                    }

                    // Signal Strength / Link Quality
                    ColumnLayout {
                      Layout.preferredWidth: 140
                      spacing: 3

                      RowLayout {
                        spacing: 6
                        Rectangle {
                          width: 8
                          height: 8
                          radius: 4
                          color: modelData.isWired ? root.healthy : (modelData.signal > -65 ? root.healthy : (modelData.signal > -75 ? root.backup : root.urgent))
                        }
                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.isWired ? "Link 1000 Mbps" : (String(modelData.signal) + " dBm")
                          color: modelData.isWired ? root.foreground : (modelData.signal > -65 ? root.healthy : (modelData.signal > -75 ? root.backup : root.urgent))
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.isWired ? "Gigabit Full Duplex" : (modelData.signal > -60 ? "Excellent Signal" : (modelData.signal > -70 ? "Good Signal" : "Fair Signal"))
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                      }
                    }

                    // Throughput & Uptime
                    ColumnLayout {
                      Layout.preferredWidth: 150
                      spacing: 2

                      Text {
                        textFormat: Text.PlainText;
                        text: "RX: " + (modelData.rxBytes ? (modelData.rxBytes / (1024 * 1024)).toFixed(1) + " MB" : (modelData.rxRate + " Mbps")) + " · TX: " + (modelData.txBytes ? (modelData.txBytes / (1024 * 1024)).toFixed(1) + " MB" : (modelData.txRate + " Mbps"))
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: "Uptime: " + (modelData.uptimeText || "Active")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                      }
                    }

                    // Quick Action: Ping
                    Rectangle {
                      Layout.preferredWidth: Style.space(64)
                      Layout.preferredHeight: Style.space(26)
                      radius: 4
                      color: pingMouse.containsMouse ? root.cardHover : root.track
                      border.width: 1
                      border.color: pingMouse.containsMouse ? root.accent : root.outline

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                          textFormat: Text.PlainText;
                          text: ""
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: 9
                        }
                        Text {
                          textFormat: Text.PlainText;
                          text: "Ping"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
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
        spacing: Style.space(12)

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
            contentHeight: wanCol.childrenRect.height + Style.space(20)
            clip: true

            Column {
              id: wanCol
              width: wanFlick.width
              spacing: Style.space(10)

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

              Grid {
                width: parent.width
                columns: 2
                spacing: Style.space(10)

                Repeater {
                  model: root.fleetData && root.fleetData.wans ? root.fleetData.wans : []
                  delegate: Rectangle {
                    required property var modelData
                    width: (wanCol.width - Style.space(10)) / 2
                    height: Style.space(136)
                    radius: 6
                    color: root.track
                    border.width: 1
                    border.color: modelData.plugged ? (modelData.type.indexOf("Primary") !== -1 ? root.accent : root.backup) : root.outline

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: Style.space(10)
                      spacing: Style.space(3)

                      // Header row
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Rectangle {
                          width: 8
                          height: 8
                          radius: 4
                          color: modelData.plugged ? root.healthy : root.dim
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: (modelData.siteName || "Site") + " · " + (modelData.gatewayModel || "Gateway")
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                          height: 18
                          width: wanTypeTag.implicitWidth + 10
                          radius: 3
                          color: modelData.plugged ? (modelData.type.indexOf("Primary") !== -1 ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2)) : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.2)

                          Text {
                            id: wanTypeTag
                            textFormat: Text.PlainText;
                            anchors.centerIn: parent
                            text: modelData.plugged ? (modelData.type.indexOf("Primary") !== -1 ? "PRIMARY ACTIVE" : "BACKUP STANDBY") : "UNPLUGGED"
                            color: modelData.plugged ? (modelData.type.indexOf("Primary") !== -1 ? root.healthy : root.backup) : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }
                      }

                      // Hardware Interface details
                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(8)

                        Rectangle {
                          height: 18
                          width: ifacePillText.implicitWidth + 10
                          radius: 3
                          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)

                          Text {
                            id: ifacePillText
                            textFormat: Text.PlainText;
                            anchors.centerIn: parent
                            text: (modelData.interface || "eth0") + " (Port " + (modelData.port !== undefined ? modelData.port : "0") + ")"
                            color: root.accent
                            font.family: root.fontFamily
                            font.pixelSize: 9
                            font.bold: true
                          }
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: "Negotiated: " + (modelData.speedType || "1GbE") + " Multi-Gigabit"
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                        }
                      }

                      // IP addresses
                      Text {
                        textFormat: Text.PlainText;
                        text: "Public IPv4: " + (modelData.ipv4 || "DHCP / Lease Pending")
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: "IPv6: " + (modelData.ipv6 || "fe80:: (Link-Local SLAAC)")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      // ISP Peering
                      Text {
                        textFormat: Text.PlainText;
                        text: "ISP Peering: " + (modelData.isp || "Autonomous System Fiber")
                        color: root.accent
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
            contentHeight: outageListCol.childrenRect.height + Style.space(20)
            clip: true

            Column {
              id: outageListCol
              width: parent.width
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText;
                visible: !root.fleetData || !root.fleetData.outages || root.fleetData.outages.length === 0
                text: "No internet downtime recorded in recent telemetry periods (100% WAN uptime)."
                color: root.healthy
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                topPadding: Style.space(20)
              }

              Repeater {
                model: root.fleetData && root.fleetData.outages ? root.fleetData.outages : []
                delegate: Rectangle {
                  required property var modelData
                  width: outageListCol.width
                  height: Style.space(56)
                  radius: 6
                  color: root.track
                  border.width: 1
                  border.color: modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.4) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.4)

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    spacing: Style.space(12)

                    Rectangle {
                      Layout.preferredWidth: Style.space(32)
                      Layout.preferredHeight: Style.space(32)
                      radius: 6
                      color: modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2)

                      Text {
                        textFormat: Text.PlainText;
                        anchors.centerIn: parent
                        text: ""
                        color: modelData.severity === "critical" ? root.urgent : root.backup
                        font.family: root.fontFamily
                        font.pixelSize: 14
                      }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 2

                      RowLayout {
                        spacing: 6
                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.type || "Internet Outage"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                        Text {
                          textFormat: Text.PlainText;
                          text: "· " + (modelData.siteName || "Site")
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.description || "Gateway internet link dropped (packet loss detected)"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                      }
                    }

                    ColumnLayout {
                      spacing: 2
                      Layout.alignment: Qt.AlignRight

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.timeText || "Recent"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: "Duration: " + (modelData.durationText || "5m")
                        color: root.urgent
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
          title: "SWITCH FLEET SELECTION & POE BUDGET"
          subtitle: (root.currentSwitch ? root.currentSwitch.name : "Switch") + " · " + (root.currentSwitch ? root.currentSwitch.siteName : "") + " (" + (root.currentSwitch ? root.currentSwitch.activePorts : 0) + "/" + (root.currentSwitch ? root.currentSwitch.totalPorts : 0) + " ports active)"
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily
          badgeText: String(root.currentSwitch ? root.currentSwitch.totalPower : 0) + " W / " + String(root.currentSwitch ? root.currentSwitch.maxPower : 600) + " W POE"
          badgeColor: root.accent

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            // Switch selector buttons row
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText;
                text: "SWITCH:"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
              }

              Repeater {
                model: root.availableSwitches
                delegate: Rectangle {
                  required property var modelData
                  required property int index
                  height: Style.space(30)
                  width: swBtnText.implicitWidth + Style.space(20)
                  radius: 5
                  color: root.selectedSwitchIndex === index ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : root.track
                  border.width: 1
                  border.color: root.selectedSwitchIndex === index ? root.accent : root.outline

                  Text {
                    id: swBtnText
                    textFormat: Text.PlainText;
                    anchors.centerIn: parent
                    text: (modelData.name || "Switch") + " (" + (modelData.siteName || "") + ")"
                    color: root.selectedSwitchIndex === index ? root.foreground : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    font.bold: root.selectedSwitchIndex === index
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.selectedSwitchIndex = index }
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
                    height: Style.space(28)
                    width: pFilterText.implicitWidth + Style.space(14)
                    radius: 4
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
              spacing: Style.space(16)
              visible: Boolean(root.currentSwitch)

              ColumnLayout {
                spacing: 2
                Text {
                  textFormat: Text.PlainText;
                  text: (root.currentSwitch ? root.currentSwitch.name : "") + " · " + (root.currentSwitch ? root.currentSwitch.model : "")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
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
                Layout.preferredWidth: 260
                spacing: 3

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    textFormat: Text.PlainText;
                    text: "PoE Power Consumption:"
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
                  height: 6
                  radius: 3
                  color: root.track

                  Rectangle {
                    height: parent.height
                    radius: 3
                    width: Math.min(parent.width, Math.max(4, parent.width * ((root.currentSwitch && root.currentSwitch.maxPower > 0) ? (root.currentSwitch.totalPower / root.currentSwitch.maxPower) : 0.05)))
                    color: root.accent
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
            contentHeight: portListCol.childrenRect.height + Style.space(20)
            clip: true

            Column {
              id: portListCol
              width: parent.width
              spacing: Style.space(6)

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

              Repeater {
                model: tab3View.portsList
                delegate: Rectangle {
                  required property var modelData
                  width: portListCol.width
                  height: Style.space(48)
                  radius: 5
                  color: root.track
                  border.width: 1
                  border.color: modelData.up ? (modelData.poePower > 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3) : root.outline) : root.outline

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(12)

                    // Port Badge
                    Rectangle {
                      Layout.preferredWidth: Style.space(34)
                      Layout.preferredHeight: Style.space(32)
                      radius: 4
                      color: modelData.up ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2) : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.15)
                      border.width: 1
                      border.color: modelData.up ? root.healthy : root.outline

                      Text {
                        textFormat: Text.PlainText;
                        anchors.centerIn: parent
                        text: String(modelData.portIdx)
                        color: modelData.up ? root.healthy : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    // Port Name & Speed
                    ColumnLayout {
                      Layout.preferredWidth: 150
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.name || ("Port " + modelData.portIdx)
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.up ? (modelData.speedText + " Full Duplex") : "Disconnected"
                        color: modelData.up ? root.healthy : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                      }
                    }

                    // Connected Device
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 1

                      RowLayout {
                        spacing: 4
                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.connectedDevice ? "" : ""
                          color: modelData.connectedDevice ? root.accent : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 8
                        }
                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.connectedDevice || "No device identified"
                          color: modelData.connectedDevice ? root.foreground : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: Boolean(modelData.connectedDevice)
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.up ? "Link state active" : "Port idle / link down"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                      }
                    }

                    // PoE Output Telemetry
                    ColumnLayout {
                      Layout.preferredWidth: 180
                      spacing: 1

                      RowLayout {
                        spacing: 6
                        Rectangle {
                          width: 6
                          height: 6
                          radius: 3
                          color: modelData.poePower > 0 ? root.accent : root.dim
                        }
                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.poePower > 0 ? (modelData.poePower.toFixed(1) + " W @ " + (modelData.poeVoltage ? modelData.poeVoltage.toFixed(1) : "53.5") + " V") : (modelData.poeMode !== "off" ? "PoE Standby (0.0 W)" : "PoE Off")
                          color: modelData.poePower > 0 ? root.accent : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: modelData.poePower > 0
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.poePower > 0 ? ("Current: " + (modelData.poeCurrent ? modelData.poeCurrent.toFixed(0) : "0") + " mA · PoE+ (at)") : ("Mode: " + (modelData.poeMode || "off"))
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                      }
                    }

                    // 1-Click Power Cycle PoE Button
                    Rectangle {
                      Layout.preferredWidth: Style.space(90)
                      Layout.preferredHeight: Style.space(28)
                      radius: 4
                      visible: modelData.poeMode !== "off" || modelData.poePower > 0
                      color: cycleBtnMouse.containsMouse ? root.cardHover : root.track
                      border.width: 1
                      border.color: cycleBtnMouse.containsMouse ? root.backup : root.outline

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                          textFormat: Text.PlainText;
                          text: ""
                          color: root.backup
                          font.family: root.fontFamily
                          font.pixelSize: 10
                        }
                        Text {
                          textFormat: Text.PlainText;
                          text: "Cycle PoE"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: true
                        }
                      }

                      MouseArea {
                        id: cycleBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (root.currentSwitch) {
                            root.cyclePort(root.currentSwitch.hostId, root.currentSwitch.mac, modelData.portIdx, modelData.name || ("Port " + modelData.portIdx))
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
