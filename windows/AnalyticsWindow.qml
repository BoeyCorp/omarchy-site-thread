import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import ".."

FloatingWindow {
  id: root
  title: "UniFi SiteThread — Fleet Analytics & Telemetry"
  color: root.background
  minimumSize: Qt.size(860, 560)
  implicitWidth: 1040
  implicitHeight: 700

  property var fleetData: null
  property color foreground: (Color.popups && Color.popups.foreground) ? Color.popups.foreground : (Color.foreground || "#D8DEE9")
  property color background: (Color.popups && Color.popups.background) ? Color.popups.background : (Color.background || "#1E1E2E")
  property color accent: Color.accent || "#89B4FA"
  property color healthy: "#10B981"
  property color backup: "#F59E0B"
  property color urgent: "#FF4D5A"
  property string fontFamily: Style.font.family

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
      spacing: Style.space(14)

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
            text: "Aggregate WAN Uptime, Traffic Throughput, Client Distribution & ISP Status"
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

      // Main Analytics Split
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
            iconText: ""
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
    }
  }
}
