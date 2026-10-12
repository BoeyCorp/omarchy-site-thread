import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".."
import "../../components"

ColumnLayout {
  id: root

  property var fleetData: ({})
  property string clientSearch: ""
  property string clientSiteFilter: "All"
  property string clientMediumFilter: "All"

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property color backup: "#f59e0b"
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property string fontFamily: Style.font.family

  signal pingHostRequested(string host, string label)
  function pingHost(host, label) {
    pingHostRequested(host, label)
  }

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
            SearchField {
              placeholderText: "Search clients by name, IP, MAC address, ESSID, or uplink AP..."
              text: root.clientSearch
              foreground: root.foreground
              dim: root.dim
              track: root.track
              outline: root.outline
              accent: root.accent
              fontFamily: root.fontFamily
              onTextChanged: root.clientSearch = text
              onCleared: root.clientSearch = ""
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
