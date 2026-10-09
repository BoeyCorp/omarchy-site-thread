import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: root

  property var settings: ({})
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

  signal settingChanged(string key, var value)
  signal clearHistoryRequested()
  signal closeSettingsRequested()

  spacing: Style.space(12)

  // Top header in settings view
  SectionCard {
    title: "SITETHREAD PREFERENCES"
    subtitle: "Customize top bar telemetry, refresh intervals, and terminal shortcuts"
    iconText: ""
    titleColor: root.foreground
    fontFamily: root.fontFamily

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(12)
      anchors.topMargin: Style.space(8)

      // 1. Bar Badge Mode Selector
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText;
          text: "BAR BADGE MODE"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Select what is displayed on the top bar badge next to the UniFi logo"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { id: "alerts", label: "Alerts Count" },
              { id: "clients", label: "Fleet Clients" },
              { id: "sites", label: "Sites Ratio" },
              { id: "off", label: "Off" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.badgeMode || "alerts") === modelData.id
              implicitHeight: Style.space(24)
              implicitWidth: badgePillText.implicitWidth + Style.space(14)
              radius: 4
              color: isSelected ? root.accent : (badgeMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: badgePillText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? "#ffffff" : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: badgeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("badgeMode", modelData.id)
              }
            }
          }
        }
      }

      // 2. Multi-Dot Site Bar Status
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText;
          text: "MULTI-DOT SITE STATUS IN TOP BAR"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Display individual site status indicator dots beside the UniFi bar icon"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { val: true, label: "Enabled" },
              { val: false, label: "Disabled" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.enableMultiDot !== undefined ? root.settings.enableMultiDot : true) === modelData.val
              implicitHeight: Style.space(24)
              implicitWidth: mDotText.implicitWidth + Style.space(14)
              radius: 4
              color: isSelected ? root.accent : (mDotMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: mDotText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? "#ffffff" : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: mDotMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("enableMultiDot", modelData.val)
              }
            }
          }
        }
      }

      // 3. Auto-Rotate 3D Globe
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText;
          text: "AUTO-ROTATE 3D VECTOR GLOBE"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Continuously rotate fleet globe when the Overview dashboard is opened"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { val: true, label: "Auto-Rotate" },
              { val: false, label: "Manual Drag Only" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.autoRotate !== undefined ? root.settings.autoRotate : false) === modelData.val
              implicitHeight: Style.space(24)
              implicitWidth: autoRotPillText.implicitWidth + Style.space(14)
              radius: 4
              color: isSelected ? root.accent : (autoRotMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: autoRotPillText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? "#ffffff" : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: autoRotMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("autoRotate", modelData.val)
              }
            }
          }
        }
      }

      // 4. Polling Refresh Interval
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText;
          text: "REFRESH INTERVAL"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Frequency of background Network and Protect telemetry queries"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { sec: 15, label: "15s" },
              { sec: 30, label: "30s" },
              { sec: 60, label: "60s" },
              { sec: 120, label: "2m" },
              { sec: 300, label: "5m" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.refreshSeconds || 30) === modelData.sec
              implicitHeight: Style.space(24)
              implicitWidth: refPillText.implicitWidth + Style.space(14)
              radius: 4
              color: isSelected ? root.accent : (refMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: refPillText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? "#ffffff" : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: refMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("refreshSeconds", modelData.sec)
              }
            }
          }
        }
      }

      // 5. Preferred Terminal for SSH
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText;
          text: "PREFERRED TERMINAL (SSH & DIAGNOSTICS)"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Terminal emulator used when launching 1-click SSH and ping consoles"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { cmd: "xdg-terminal-exec", label: "Default" },
              { cmd: "ghostty", label: "Ghostty" },
              { cmd: "kitty", label: "Kitty" },
              { cmd: "foot", label: "Foot" },
              { cmd: "alacritty", label: "Alacritty" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.terminalCommand || "xdg-terminal-exec") === modelData.cmd
              implicitHeight: Style.space(24)
              implicitWidth: termPillText.implicitWidth + Style.space(12)
              radius: 4
              color: isSelected ? root.accent : (termMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: termPillText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? "#ffffff" : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: termMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("terminalCommand", modelData.cmd)
              }
            }
          }
        }
      }

      // 6. Action Controls: Clear History & Back
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(8)
        spacing: Style.space(10)

        Rectangle {
          implicitHeight: Style.space(28)
          implicitWidth: clearBtnText.implicitWidth + Style.space(16)
          radius: 4
          color: clearMouse.containsMouse ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.25) : root.track
          border.width: 1
          border.color: root.urgent

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(5)
            Text { textFormat: Text.PlainText; text: ""; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            Text { textFormat: Text.PlainText; id: clearBtnText; text: "Clear Alert History"; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
          }

          MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearHistoryRequested()
          }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          implicitHeight: Style.space(28)
          implicitWidth: backBtnText.implicitWidth + Style.space(18)
          radius: 4
          color: backMouse.containsMouse ? root.cardHover : root.accent

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(5)
            Text { textFormat: Text.PlainText; text: ""; color: "#ffffff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            Text { textFormat: Text.PlainText; id: backBtnText; text: "Back to Dashboard"; color: "#ffffff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
          }

          MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeSettingsRequested()
          }
        }
      }
    }
  }
}
