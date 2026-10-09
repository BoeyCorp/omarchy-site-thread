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
            subtitle: "Peak Download: 84.5 Mbps · Peak Upload: 22.8 Mbps"
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
              Layout.minimumHeight: Style.space(140)
              Layout.margins: Style.space(8)
              onPaint: {
                var ctx = getContext("2d")
                if (!ctx) return
                ctx.reset()
                var w = width
                var h = height
                if (w <= 0 || h <= 0) return

                // Grid lines
                ctx.strokeStyle = root.isLightTheme ? "#e2e8f0" : "#2a324b"
                ctx.lineWidth = 0.5
                for (var g = 0; g <= 4; g++) {
                  var y = (h / 4) * g
                  ctx.beginPath()
                  ctx.moveTo(0, y)
                  ctx.lineTo(w, y)
                  ctx.stroke()
                }

                // Sample points for download
                var rxData = [12, 18, 14, 25, 42, 38, 55, 78, 84, 62, 45, 52, 68, 74, 58, 48, 62, 54, 40, 32, 28, 35, 42, 50]
                var txData = [4, 6, 5, 8, 12, 11, 16, 20, 22, 18, 14, 15, 19, 21, 16, 14, 17, 15, 12, 10, 8, 9, 11, 14]

                // Draw Download Curve
                ctx.beginPath()
                var step = w / (rxData.length - 1)
                for (var i = 0; i < rxData.length; i++) {
                  var px = i * step
                  var py = h - (rxData[i] / 90) * h
                  if (i === 0) ctx.moveTo(px, py)
                  else ctx.lineTo(px, py)
                }
                ctx.strokeStyle = root.accent
                ctx.lineWidth = 2.0
                ctx.stroke()

                // Download gradient fill
                var grad = ctx.createLinearGradient(0, 0, 0, h)
                grad.addColorStop(0, Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35))
                grad.addColorStop(1, Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.02))
                ctx.lineTo(w, h)
                ctx.lineTo(0, h)
                ctx.closePath()
                ctx.fillStyle = grad
                ctx.fill()

                // Draw Upload Curve
                ctx.beginPath()
                for (var j = 0; j < txData.length; j++) {
                  var txX = j * step
                  var txY = h - (txData[j] / 90) * h
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
            subtitle: "14 WiFi clients connected across 6 Access Points"
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

              Text { textFormat: Text.PlainText; text: "5 GHz High-Throughput (9 clients · 64%)"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(8)
                radius: 4
                color: root.track
                Rectangle { width: parent.width * 0.64; height: parent.height; radius: 4; color: root.accent }
              }

              Text { textFormat: Text.PlainText; text: "2.4 GHz IoT & Legacy (5 clients · 36%)"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(8)
                radius: 4
                color: root.track
                Rectangle { width: parent.width * 0.36; height: parent.height; radius: 4; color: root.backup }
              }

              Text { textFormat: Text.PlainText; text: "6 GHz WiFi 7 (U7 Pro Ready)"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
            }
          }
        }

        // Right Column: Site Matrix & ISP Telemetry
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 4
          spacing: Style.space(10)

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
              Layout.margins: Style.space(6)
              contentWidth: width
              contentHeight: siteMatrixCol.implicitHeight
              clip: true

              ColumnLayout {
                id: siteMatrixCol
                width: parent.width
                spacing: Style.space(8)

                Repeater {
                  model: root.fleetData && root.fleetData.sites ? root.fleetData.sites : []
                  delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: siteCol.implicitHeight + Style.space(12)
                    radius: 4
                    color: root.track
                    border.width: 1
                    border.color: root.outline

                    ColumnLayout {
                      id: siteCol
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.margins: Style.space(8)
                      spacing: Style.space(4)

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)

                        Rectangle {
                          width: 8; height: 8; radius: 4
                          color: modelData.status === "down" ? root.urgent : (modelData.status === "backup" ? root.backup : root.healthy)
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.name || "Site"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                          Layout.fillWidth: true
                        }

                        Rectangle {
                          height: 14
                          width: statusTextTag.implicitWidth + 8
                          radius: 2
                          color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2)
                          Text {
                            textFormat: Text.PlainText;
                            id: statusTextTag
                            anchors.centerIn: parent
                            text: "ONLINE"
                            color: root.healthy
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: (modelData.gatewayModel || "Gateway") + " · IP: " + (modelData.gatewayIp || "DHCP")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: "ISP: " + (modelData.isp || "Unknown ISP") + " · " + (modelData.timezone || "UTC")
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(12)

                        Text {
                          textFormat: Text.PlainText;
                          text: " " + (modelData.clientCount || 0) + " clients"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: " " + (modelData.deviceCount || 0) + " devices"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: " 100% uptime"
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
