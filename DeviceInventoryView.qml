import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: root

  property var devices: []
  property string currentFilter: "all"
  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || "#888888")
  property color accent: (Color.accent || "#89B4FA")
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property string fontFamily: Style.font.family

  signal sshRequested(string ip, string user)
  signal pingRequested(string ip)
  signal webRequested(string ip)

  spacing: Style.space(10)

  function deviceCategory(d) {
    if (!d || !d.model) return "other"
    var m = String(d.model).toLowerCase()
    if (m.indexOf("ucg") >= 0 || m.indexOf("udm") >= 0 || m.indexOf("uxg") >= 0 || m.indexOf("gateway") >= 0) return "gateways"
    if (m.indexOf("usw") >= 0 || m.indexOf("switch") >= 0) return "switches"
    if (m.indexOf("u7") >= 0 || m.indexOf("u6") >= 0 || m.indexOf("nano") >= 0 || m.indexOf("ap") >= 0 || m.indexOf("hd") >= 0) return "aps"
    if (m.indexOf("unas") >= 0 || m.indexOf("nvr") >= 0 || m.indexOf("storage") >= 0) return "storage"
    return "other"
  }

  function filteredDevices() {
    var list = Array.isArray(root.devices) ? root.devices : []
    if (root.currentFilter === "all") return list
    var out = []
    for (var i = 0; i < list.length; i++) {
      if (deviceCategory(list[i]) === root.currentFilter) out.push(list[i])
    }
    return out
  }

  function countCategory(cat) {
    var list = Array.isArray(root.devices) ? root.devices : []
    if (cat === "all") return list.length
    var count = 0
    for (var i = 0; i < list.length; i++) {
      if (deviceCategory(list[i]) === cat) count++
    }
    return count
  }

  // Filter Bar
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(6)

    Repeater {
      model: [
        { id: "all", label: "All (" + countCategory("all") + ")" },
        { id: "gateways", label: "Gateways (" + countCategory("gateways") + ")" },
        { id: "switches", label: "Switches (" + countCategory("switches") + ")" },
        { id: "aps", label: "APs (" + countCategory("aps") + ")" },
        { id: "storage", label: "Storage (" + countCategory("storage") + ")" }
      ]
      delegate: Rectangle {
        required property var modelData
        readonly property bool isSelected: root.currentFilter === modelData.id
        implicitHeight: Style.space(24)
        implicitWidth: catPillText.implicitWidth + Style.space(14)
        radius: 4
        color: isSelected ? root.accent : (catMouse.containsMouse ? root.cardHover : root.track)
        border.width: 1
        border.color: isSelected ? root.accent : root.outline

        Text {
          textFormat: Text.PlainText;
          id: catPillText
          anchors.centerIn: parent
          text: modelData.label
          color: isSelected ? "#ffffff" : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: isSelected
        }

        MouseArea {
          id: catMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.currentFilter = modelData.id
        }
      }
    }
  }

  // Device List
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.space(6)

    Repeater {
      model: root.filteredDevices()
      delegate: Rectangle {
        id: devCard
        required property var modelData
        required property int index

        Layout.fillWidth: true
        implicitHeight: devInnerCol.implicitHeight + Style.space(14)
        radius: 4
        color: devCardMouse.containsMouse ? root.cardHover : root.card
        border.width: 1
        border.color: devCardMouse.containsMouse ? root.accent : root.outline

        MouseArea {
          id: devCardMouse
          anchors.fill: parent
          hoverEnabled: true
        }

        ColumnLayout {
          id: devInnerCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(8)
          spacing: Style.space(4)

          // Top Row: Status Dot, Device Model & Name, Site Badge
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Rectangle {
              width: Style.space(8)
              height: Style.space(8)
              radius: width / 2
              color: modelData.online ? root.healthy : root.urgent
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              textFormat: Text.PlainText;
              text: modelData.name || modelData.model || "UniFi Device"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              textFormat: Text.PlainText;
              text: "· " + (modelData.model || "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            // Site Badge
            Rectangle {
              visible: !!modelData.site
              height: Style.space(16)
              width: siteBadgeText.implicitWidth + Style.space(10)
              radius: 3
              color: root.track
              border.width: 1
              border.color: root.outline
              Layout.alignment: Qt.AlignVCenter

              Text {
                textFormat: Text.PlainText;
                id: siteBadgeText
                anchors.centerIn: parent
                text: modelData.site || ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
              }
            }
          }

          // Bottom Row: IP, MAC, Action Buttons
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText;
              text: "IP: " + (modelData.ip || "DHCP") + (modelData.id ? " · MAC: " + modelData.id : "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            // 1-Click Action Buttons
            RowLayout {
              spacing: Style.space(4)
              Layout.alignment: Qt.AlignVCenter

              // SSH Button (for Gateways and Switches)
              Rectangle {
                visible: !!modelData.ip && (deviceCategory(modelData) === "gateways" || deviceCategory(modelData) === "switches")
                implicitHeight: Style.space(20)
                implicitWidth: sshText.implicitWidth + Style.space(10)
                radius: 3
                color: sshMouse.containsMouse ? root.accent : root.track
                border.width: 1
                border.color: root.accent

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(3)
                  Text { textFormat: Text.PlainText; text: ""; color: sshMouse.containsMouse ? "#ffffff" : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 3 }
                  Text { textFormat: Text.PlainText; id: sshText; text: "SSH"; color: sshMouse.containsMouse ? "#ffffff" : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                }

                MouseArea {
                  id: sshMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.sshRequested(modelData.ip, "root")
                }
              }

              // Ping Button
              Rectangle {
                visible: !!modelData.ip
                implicitHeight: Style.space(20)
                implicitWidth: pingText.implicitWidth + Style.space(10)
                radius: 3
                color: pingMouse.containsMouse ? root.cardHover : root.track
                border.width: 1
                border.color: root.outline

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(3)
                  Text { textFormat: Text.PlainText; text: ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 3 }
                  Text { textFormat: Text.PlainText; id: pingText; text: "Ping"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                }

                MouseArea {
                  id: pingMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.pingRequested(modelData.ip)
                }
              }

              // Web UI Link
              Rectangle {
                visible: !!modelData.ip
                implicitHeight: Style.space(20)
                implicitWidth: webText.implicitWidth + Style.space(10)
                radius: 3
                color: webMouse.containsMouse ? root.cardHover : root.track
                border.width: 1
                border.color: root.outline

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(3)
                  Text { textFormat: Text.PlainText; text: ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 3 }
                  Text { textFormat: Text.PlainText; id: webText; text: "Web"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                }

                MouseArea {
                  id: webMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.webRequested(modelData.ip)
                }
              }
            }
          }
        }
      }
    }
  }
}
