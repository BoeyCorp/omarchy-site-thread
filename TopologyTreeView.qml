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

  function isGateway(d) {
    if (!d) return false
    var m = String(d.model || "").toLowerCase()
    return m.indexOf("ucg") >= 0 || m.indexOf("udm") >= 0 || m.indexOf("uxg") >= 0 || m.indexOf("gateway") >= 0
  }

  function isSwitch(d) {
    if (!d) return false
    var m = String(d.model || "").toLowerCase()
    return m.indexOf("usw") >= 0 || m.indexOf("switch") >= 0
  }

  function hasTrueTopology() {
    var list = siteDevices()
    for (var i = 0; i < list.length; i++) {
      if (list[i].parentName) return true
    }
    return false
  }

  function getGateway() {
    var list = siteDevices()
    for (var i = 0; i < list.length; i++) {
      if (isGateway(list[i])) return list[i]
    }
    for (var j = 0; j < list.length; j++) {
      if (!list[j].parentName) return list[j]
    }
    return root.site ? {
      name: root.site.gatewayModel || "UniFi Gateway",
      model: root.site.gatewayModel || "Gateway",
      ip: root.site.gatewayIp || "",
      online: root.site.status === "up"
    } : null
  }

  function getTier1Children() {
    var list = siteDevices()
    var gw = getGateway()
    var gwName = gw ? String(gw.name || "").toLowerCase() : ""

    if (hasTrueTopology()) {
      var out = []
      for (var i = 0; i < list.length; i++) {
        var d = list[i]
        if (d === gw) continue
        var p = String(d.parentName || "").toLowerCase()
        if (p === gwName || (!p && !isGateway(d))) {
          out.push(d)
        }
      }
      out.sort(function(a, b) {
        var sa = isSwitch(a) ? 0 : 1
        var sb = isSwitch(b) ? 0 : 1
        if (sa !== sb) return sa - sb
        return (a.parentPort || 0) - (b.parentPort || 0)
      })
      return out
    } else {
      // Heuristic fallback: all switches
      var switches = []
      for (var s = 0; s < list.length; s++) {
        if (isSwitch(list[s]) && list[s] !== gw) switches.push(list[s])
      }
      return switches
    }
  }

  function getTier2Children(parentDev) {
    if (!parentDev) return []
    var list = siteDevices()
    var pName = String(parentDev.name || "").toLowerCase()

    if (hasTrueTopology()) {
      var out = []
      for (var i = 0; i < list.length; i++) {
        var d = list[i]
        if (d === parentDev) continue
        var p = String(d.parentName || "").toLowerCase()
        if (p === pName) out.push(d)
      }
      out.sort(function(a, b) {
        return (a.parentPort || 0) - (b.parentPort || 0)
      })
      return out
    } else {
      // Heuristic fallback: all leaf endpoints
      var leafs = []
      for (var l = 0; l < list.length; l++) {
        var item = list[l]
        if (!isGateway(item) && !isSwitch(item)) leafs.push(item)
      }
      return leafs
    }
  }

  function portSpeedLabel(dev) {
    if (!dev || !dev.parentPort) return ""
    var port = "Port " + dev.parentPort
    if (dev.uplinkSpeed >= 10000) return port + " · 10G"
    if (dev.uplinkSpeed >= 2500) return port + " · 2.5G"
    if (dev.uplinkSpeed >= 1000) return port + " · 1G"
    return port
  }

  // Tier 0: Gateway Root Node
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

        // SSH Action Button
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

      Text {
        textFormat: Text.PlainText;
        text: (gwCard.gw ? gwCard.gw.model : "") + (gwCard.gw && gwCard.gw.ip ? " · IP: " + gwCard.gw.ip : "") + (root.site && root.site.isp ? " · ISP: " + root.site.isp : "")
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption - 2
      }
    }
  }

  // Tier 1: Direct Gateway Children (Switches and directly connected APs)
  Repeater {
    model: root.getTier1Children()
    delegate: ColumnLayout {
      id: t1Group
      required property var modelData
      required property int index

      Layout.fillWidth: true
      spacing: Style.space(4)

      // Tier 1 Node Card
      Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(14)
        implicitHeight: t1Col.implicitHeight + Style.space(12)
        radius: 4
        color: root.card
        border.width: 1
        border.color: root.isSwitch(modelData) ? root.outline : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.2)

        ColumnLayout {
          id: t1Col
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
              text: index === (root.getTier1Children().length - 1) ? "└─" : "├─"
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
              text: modelData.name || modelData.model || "Device"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              font.bold: true
            }

            // Port badge
            Rectangle {
              visible: !!modelData.parentPort
              height: Style.space(14)
              width: t1PortText.implicitWidth + Style.space(8)
              radius: 2
              color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
              Text {
                textFormat: Text.PlainText;
                id: t1PortText
                anchors.centerIn: parent
                text: root.portSpeedLabel(modelData)
                color: root.healthy
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            Rectangle {
              height: Style.space(14)
              width: t1PillText.implicitWidth + Style.space(6)
              radius: 2
              color: root.track
              Text {
                textFormat: Text.PlainText;
                id: t1PillText
                anchors.centerIn: parent
                text: root.isSwitch(modelData) ? "SWITCH" : "AP"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            Item { Layout.fillWidth: true }

            // Action Button: SSH for switches, Ping for others
            Rectangle {
              visible: !!modelData.ip
              implicitHeight: Style.space(18)
              implicitWidth: t1ActionText.implicitWidth + Style.space(8)
              radius: 3
              color: t1ActionMouse.containsMouse ? root.accent : root.track
              border.width: 1
              border.color: root.outline
              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(2)
                Text {
                  textFormat: Text.PlainText;
                  text: root.isSwitch(modelData) ? "" : ""
                  color: t1ActionMouse.containsMouse ? "#ffffff" : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: 8
                }
                Text {
                  textFormat: Text.PlainText;
                  id: t1ActionText
                  text: root.isSwitch(modelData) ? "SSH" : "Ping"
                  color: t1ActionMouse.containsMouse ? "#ffffff" : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: 8
                }
              }
              MouseArea {
                id: t1ActionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.isSwitch(modelData)) {
                    root.sshRequested(modelData.ip, "root")
                  } else {
                    root.pingRequested(modelData.ip)
                  }
                }
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

      // Tier 2: Children connected to this Tier 1 device
      Repeater {
        model: root.getTier2Children(modelData)
        delegate: Rectangle {
          required property var modelData
          required property int index

          Layout.fillWidth: true
          Layout.leftMargin: Style.space(28)
          implicitHeight: t2Col.implicitHeight + Style.space(10)
          radius: 4
          color: root.card
          border.width: 1
          border.color: root.outline

          ColumnLayout {
            id: t2Col
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
                text: index === (root.getTier2Children(t1Group.modelData).length - 1) ? "└─" : "├─"
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

              // Port badge
              Rectangle {
                visible: !!modelData.parentPort
                height: Style.space(13)
                width: t2PortText.implicitWidth + Style.space(6)
                radius: 2
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                Text {
                  textFormat: Text.PlainText;
                  id: t2PortText
                  anchors.centerIn: parent
                  text: root.portSpeedLabel(modelData)
                  color: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 7
                  font.bold: true
                }
              }

              Item { Layout.fillWidth: true }

              // Ping Button
              Rectangle {
                visible: !!modelData.ip
                implicitHeight: Style.space(16)
                implicitWidth: t2PingText.implicitWidth + Style.space(8)
                radius: 2
                color: t2PingMouse.containsMouse ? root.cardHover : root.track
                Text {
                  textFormat: Text.PlainText;
                  id: t2PingText
                  anchors.centerIn: parent
                  text: "Ping"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: 8
                }
                MouseArea {
                  id: t2PingMouse
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
  }
}
