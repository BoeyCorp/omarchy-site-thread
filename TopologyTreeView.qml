import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: root

  property var site: null
  property var devices: []
  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || "#888888")
  property color accent: (Color.accent || "#89B4FA")
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property color backup: "#F59E0B"
  property string fontFamily: Style.font.family

  signal sshRequested(string ip, string user)
  signal pingRequested(string ip)
  signal webRequested(string ip)

  spacing: Style.space(6)

  function siteDevices() {
    var list = Array.isArray(root.devices) ? root.devices : []
    if (!root.site || !root.site.name) return list
    var out = []
    for (var i = 0; i < list.length; i++) {
      if (list[i].site === root.site.name) out.push(list[i])
    }
    return out.length > 0 ? out : list
  }

  function getGateway() {
    var list = siteDevices()
    for (var i = 0; i < list.length; i++) {
      var m = String(list[i].model || "").toLowerCase()
      if (m.indexOf("ucg") >= 0 || m.indexOf("udm") >= 0 || m.indexOf("uxg") >= 0 || m.indexOf("gateway") >= 0) {
        return list[i]
      }
    }
    return root.site ? { name: root.site.gatewayModel || "UniFi Gateway", model: root.site.gatewayModel || "Gateway", ip: root.site.gatewayIp || "", online: root.site.status === "up" } : null
  }

  function getSwitches() {
    var list = siteDevices()
    var out = []
    for (var i = 0; i < list.length; i++) {
      var m = String(list[i].model || "").toLowerCase()
      if (m.indexOf("usw") >= 0 || m.indexOf("switch") >= 0) out.push(list[i])
    }
    return out
  }

  function getLeafDevices() {
    var list = siteDevices()
    var out = []
    for (var i = 0; i < list.length; i++) {
      var m = String(list[i].model || "").toLowerCase()
      if (m.indexOf("ucg") < 0 && m.indexOf("udm") < 0 && m.indexOf("uxg") < 0 && m.indexOf("usw") < 0 && m.indexOf("switch") < 0) {
        out.push(list[i])
      }
    }
    return out
  }

  // Gateway Root Node
  Rectangle {
    id: gwCard
    property var gw: root.getGateway()
    Layout.fillWidth: true
    implicitHeight: gwCol.implicitHeight + Style.space(14)
    radius: 4
    color: root.track
    border.width: 1
    border.color: root.accent

    ColumnLayout {
      id: gwCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(8)
      spacing: Style.space(4)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Rectangle {
          width: Style.space(8)
          height: Style.space(8)
          radius: width / 2
          color: (gwCard.gw && gwCard.gw.online) ? root.healthy : root.urgent
          Layout.alignment: Qt.AlignVCenter
        }

        Text {
          textFormat: Text.PlainText;
          text: (gwCard.gw && gwCard.gw.name) ? gwCard.gw.name : "UniFi Gateway"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
          height: Style.space(16)
          width: gwPillText.implicitWidth + Style.space(8)
          radius: 2
          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
          Text {
            textFormat: Text.PlainText;
            id: gwPillText
            anchors.centerIn: parent
            text: "GATEWAY"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: 8
            font.bold: true
          }
        }

        Item { Layout.fillWidth: true }

        // Action Buttons
        RowLayout {
          spacing: Style.space(4)
          Rectangle {
            visible: !!(gwCard.gw && gwCard.gw.ip)
            implicitHeight: Style.space(20)
            implicitWidth: gwSshText.implicitWidth + Style.space(10)
            radius: 3
            color: gwSshMouse.containsMouse ? root.accent : root.track
            border.width: 1
            border.color: root.accent
            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(3)
              Text { textFormat: Text.PlainText; text: ""; color: gwSshMouse.containsMouse ? "#ffffff" : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 3 }
              Text { textFormat: Text.PlainText; id: gwSshText; text: "SSH"; color: gwSshMouse.containsMouse ? "#ffffff" : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
            }
            MouseArea {
              id: gwSshMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (gwCard.gw && gwCard.gw.ip) root.sshRequested(gwCard.gw.ip, "root")
            }
          }
        }
      }

      Text {
        textFormat: Text.PlainText;
        text: (gwCard.gw ? gwCard.gw.model : "") + (gwCard.gw && gwCard.gw.ip ? " · IP: " + gwCard.gw.ip : "") + (root.site && root.site.isp ? " · ISP: " + root.site.isp : "")
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption - 2
      }
    }
  }

  // Switches Sub-Tree (indented └─)
  Repeater {
    model: root.getSwitches()
    delegate: Rectangle {
      id: swCard
      required property var modelData
      required property int index

      Layout.fillWidth: true
      Layout.leftMargin: Style.space(14)
      implicitHeight: swCol.implicitHeight + Style.space(12)
      radius: 4
      color: root.card
      border.width: 1
      border.color: root.outline

      ColumnLayout {
        id: swCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(7)
        spacing: Style.space(3)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            textFormat: Text.PlainText;
            text: "└─"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Rectangle {
            width: Style.space(7)
            height: Style.space(7)
            radius: width / 2
            color: modelData.online ? root.healthy : root.urgent
          }

          Text {
            textFormat: Text.PlainText;
            text: modelData.name || modelData.model || "Switch"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
          }

          Rectangle {
            height: Style.space(14)
            width: swPillText.implicitWidth + Style.space(6)
            radius: 2
            color: root.track
            Text {
              textFormat: Text.PlainText;
              id: swPillText
              anchors.centerIn: parent
              text: "SWITCH"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: 7
              font.bold: true
            }
          }

          Item { Layout.fillWidth: true }

          // SSH Button
          Rectangle {
            visible: !!modelData.ip
            implicitHeight: Style.space(18)
            implicitWidth: swSshText.implicitWidth + Style.space(8)
            radius: 3
            color: swSshMouse.containsMouse ? root.accent : root.track
            border.width: 1
            border.color: root.outline
            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(2)
              Text { textFormat: Text.PlainText; text: ""; color: swSshMouse.containsMouse ? "#ffffff" : root.dim; font.family: root.fontFamily; font.pixelSize: 8 }
              Text { textFormat: Text.PlainText; id: swSshText; text: "SSH"; color: swSshMouse.containsMouse ? "#ffffff" : root.dim; font.family: root.fontFamily; font.pixelSize: 8 }
            }
            MouseArea {
              id: swSshMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.sshRequested(modelData.ip, "root")
            }
          }
        }

        Text {
          textFormat: Text.PlainText;
          text: (modelData.model || "") + (modelData.ip ? " · IP: " + modelData.ip : "")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 3
        }
      }
    }
  }

  // APs & Endpoints Sub-Tree (indented ├─ and └─)
  Repeater {
    model: root.getLeafDevices()
    delegate: Rectangle {
      required property var modelData
      required property int index

      Layout.fillWidth: true
      Layout.leftMargin: Style.space(28)
      implicitHeight: leafCol.implicitHeight + Style.space(10)
      radius: 4
      color: root.card
      border.width: 1
      border.color: root.outline

      ColumnLayout {
        id: leafCol
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
            text: index === (root.getLeafDevices().length - 1) ? "└─" : "├─"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
          }

          Rectangle {
            width: Style.space(6)
            height: Style.space(6)
            radius: width / 2
            color: modelData.online ? root.healthy : root.urgent
          }

          Text {
            textFormat: Text.PlainText;
            text: modelData.name || modelData.model || "Device"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
          }

          Item { Layout.fillWidth: true }

          // Ping Button
          Rectangle {
            visible: !!modelData.ip
            implicitHeight: Style.space(16)
            implicitWidth: leafPingText.implicitWidth + Style.space(8)
            radius: 2
            color: leafPingMouse.containsMouse ? root.cardHover : root.track
            Text {
              textFormat: Text.PlainText;
              id: leafPingText
              anchors.centerIn: parent
              text: "Ping"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: 8
            }
            MouseArea {
              id: leafPingMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.pingRequested(modelData.ip)
            }
          }
        }

        Text {
          textFormat: Text.PlainText;
          text: (modelData.model || "") + (modelData.ip ? " · IP: " + modelData.ip : "")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 3
        }
      }
    }
  }
}
