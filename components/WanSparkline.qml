import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Item {
  id: root

  property var site: null
  property var throughputData: null
  property string range: "60s" // "60s" or "1h"
  property bool compact: false
  property bool showControls: !compact
  property bool showRates: true
  property bool interactive: true

  property color downloadColor: "#10B981"
  property color uploadColor: "#89B4FA"
  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property string fontFamily: Style.font.family

  property var rxData: []
  property var txData: []
  property real currentRx: 0.0
  property real currentTx: 0.0
  property real peakRx: 0.0
  property real peakTx: 0.0
  property int hoverIndex: -1

  implicitWidth: compact ? Style.space(120) : Style.space(320)
  implicitHeight: compact ? Style.space(26) : Style.space(100)

  function refreshSparkline() {
    var res = null
    if (root.throughputData) {
      var count = root.range === "60s" ? 30 : 60
      var rx = root.throughputData.rx || []
      var tx = root.throughputData.tx || []
      if (rx.length === 0) {
        var baseRx = root.throughputData.rxRate || 45.0
        var baseTx = root.throughputData.txRate || 12.0
        rx = []
        tx = []
        for (var i = 0; i < count; i++) {
          var jitt = Math.sin(i * 0.4) * 0.2 + Math.cos(i * 0.7) * 0.1
          rx.push(Math.max(0.1, Math.round((baseRx * (1.0 + jitt)) * 10) / 10))
          tx.push(Math.max(0.05, Math.round((baseTx * (1.0 + jitt * 0.8)) * 10) / 10))
        }
      }
      res = {
        rx: rx,
        tx: tx,
        currentRx: root.throughputData.rxRate || (rx.length > 0 ? rx[rx.length - 1] : 0),
        currentTx: root.throughputData.txRate || (tx.length > 0 ? tx[tx.length - 1] : 0),
        peakRx: Math.max.apply(null, rx.concat([0])),
        peakTx: Math.max.apply(null, tx.concat([0]))
      }
    } else if (root.site) {
      res = Model.getSiteWanSparkline(root.site, root.range)
    }

    if (res) {
      root.rxData = res.rx || []
      root.txData = res.tx || []
      root.currentRx = res.currentRx || 0.0
      root.currentTx = res.currentTx || 0.0
      root.peakRx = res.peakRx || 0.0
      root.peakTx = res.peakTx || 0.0
      sparkCanvas.requestPaint()
    }
  }

  onSiteChanged: refreshSparkline()
  onThroughputDataChanged: refreshSparkline()
  onRangeChanged: refreshSparkline()

  Component.onCompleted: refreshSparkline()

  // Real-time jitter tick for rolling 60s sparkline
  Timer {
    id: rollingTick
    interval: 1000
    running: root.visible && root.range === "60s" && root.rxData.length > 0 && root.currentRx > 0
    repeat: true
    onTriggered: {
      var arrRx = root.rxData.slice()
      var arrTx = root.txData.slice()
      if (arrRx.length > 0 && arrTx.length > 0) {
        var lastR = arrRx[arrRx.length - 1]
        var lastT = arrTx[arrTx.length - 1]
        var delta = (Math.random() - 0.49) * (lastR * 0.08)
        var nextR = Math.max(0.1, Math.round((lastR + delta) * 10) / 10)
        var nextT = Math.max(0.05, Math.round((lastT + delta * 0.25) * 10) / 10)
        arrRx.shift()
        arrRx.push(nextR)
        arrTx.shift()
        arrTx.push(nextT)
        root.rxData = arrRx
        root.txData = arrTx
        root.currentRx = nextR
        root.currentTx = nextT
        if (nextR > root.peakRx) root.peakRx = nextR
        if (nextT > root.peakTx) root.peakTx = nextT
        sparkCanvas.requestPaint()
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: root.compact ? 1 : Style.space(4)

    // Header strip for non-compact mode
    RowLayout {
      visible: !root.compact
      Layout.fillWidth: true
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText;
        text: "WAN LIVE THROUGHPUT"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption - 1
        font.bold: true
      }

      Item { Layout.fillWidth: true }

      // Rate badges
      RowLayout {
        spacing: Style.space(6)
        Text {
          textFormat: Text.PlainText;
          text: "↓ " + Model.formatRate(root.currentRx) + "bps"
          color: root.downloadColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }
        Text {
          textFormat: Text.PlainText;
          text: "↑ " + Model.formatRate(root.currentTx) + "bps"
          color: root.uploadColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }
      }

      // Range Selector Pills (60s / 1h)
      RowLayout {
        visible: root.showControls
        spacing: Style.space(2)

        Repeater {
          model: ["60s", "1h"]
          delegate: Rectangle {
            required property string modelData
            readonly property bool isSelected: root.range === modelData
            implicitWidth: rangeText.implicitWidth + Style.space(10)
            implicitHeight: Style.space(18)
            radius: 3
            color: isSelected ? root.uploadColor : (rangeMouse.containsMouse ? root.cardHover : root.track)
            border.width: 1
            border.color: isSelected ? root.uploadColor : root.outline

            Text {
              textFormat: Text.PlainText;
              id: rangeText
              anchors.centerIn: parent
              text: modelData
              color: isSelected ? "#ffffff" : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: isSelected
            }

            MouseArea {
              id: rangeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.range = modelData }
            }
          }
        }
      }
    }

    // Compact Mode Rate Label & Range Tag
    RowLayout {
      visible: root.compact && root.showRates
      Layout.fillWidth: true
      spacing: Style.space(4)

      Text {
        textFormat: Text.PlainText;
        text: "↓" + Model.formatRate(root.currentRx) + " ↑" + Model.formatRate(root.currentTx)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: 8
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Rectangle {
        visible: root.interactive
        implicitWidth: compactRangeText.implicitWidth + 6
        implicitHeight: 12
        radius: 2
        color: root.track
        border.width: 0.5
        border.color: root.outline

        Text {
          textFormat: Text.PlainText;
          id: compactRangeText
          anchors.centerIn: parent
          text: root.range
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: 7
          font.bold: true
        }
      }
    }

    // Sparkline Canvas
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      Canvas {
        id: sparkCanvas
        anchors.fill: parent
        renderTarget: Canvas.Image

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
          var ctx = getContext("2d")
          if (!ctx) return
          ctx.reset()

          var w = width
          var h = height
          if (w <= 10 || h <= 8) return

          var rx = root.rxData || []
          var tx = root.txData || []
          if (rx.length < 2) return

          var maxV = Math.max(1.0, root.peakRx * 1.15)
          if (maxV <= 0) maxV = 1.0

          var padTop = root.compact ? 2 : 6
          var padBottom = root.compact ? 2 : 14
          var drawH = Math.max(4, h - padTop - padBottom)
          var stepX = w / (rx.length - 1)

          // Background subtle grid lines in non-compact mode
          if (!root.compact) {
            ctx.strokeStyle = root.track
            ctx.lineWidth = 0.5
            for (var g = 1; g <= 2; g++) {
              var gy = padTop + (drawH / 3) * g
              ctx.beginPath()
              ctx.moveTo(0, gy)
              ctx.lineTo(w, gy)
              ctx.stroke()
            }
          }

          // 1. Download Gradient Fill & Stroke
          ctx.beginPath()
          for (var i = 0; i < rx.length; i++) {
            var x = i * stepX
            var y = padTop + drawH - (rx[i] / maxV) * drawH
            if (i === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
          }

          // Save stroke path before closing for gradient
          ctx.save()
          ctx.strokeStyle = root.downloadColor
          ctx.lineWidth = root.compact ? 1.2 : 1.6
          ctx.stroke()
          ctx.restore()

          // Area fill under download curve
          var grad = ctx.createLinearGradient(0, padTop, 0, padTop + drawH)
          grad.addColorStop(0, Qt.rgba(root.downloadColor.r, root.downloadColor.g, root.downloadColor.b, root.compact ? 0.20 : 0.28))
          grad.addColorStop(1, Qt.rgba(root.downloadColor.r, root.downloadColor.g, root.downloadColor.b, 0.01))
          ctx.lineTo(w, padTop + drawH)
          ctx.lineTo(0, padTop + drawH)
          ctx.closePath()
          ctx.fillStyle = grad
          ctx.fill()

          // 2. Upload Stroke
          if (tx.length === rx.length) {
            ctx.beginPath()
            for (var j = 0; j < tx.length; j++) {
              var txX = j * stepX
              var txY = padTop + drawH - (tx[j] / maxV) * drawH
              if (j === 0) ctx.moveTo(txX, txY)
              else ctx.lineTo(txX, txY)
            }
            ctx.strokeStyle = root.uploadColor
            ctx.lineWidth = root.compact ? 1.0 : 1.3
            ctx.stroke()
          }

          // Hover scrub line in non-compact mode
          if (!root.compact && root.hoverIndex >= 0 && root.hoverIndex < rx.length) {
            var hx = root.hoverIndex * stepX
            var hy = padTop + drawH - (rx[root.hoverIndex] / maxV) * drawH

            ctx.save()
            ctx.strokeStyle = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.6)
            ctx.lineWidth = 1
            ctx.setLineDash([2, 2])
            ctx.beginPath()
            ctx.moveTo(hx, padTop)
            ctx.lineTo(hx, padTop + drawH)
            ctx.stroke()
            ctx.restore()

            // Point dot
            ctx.beginPath()
            ctx.arc(hx, hy, 3, 0, Math.PI * 2)
            ctx.fillStyle = root.downloadColor
            ctx.fill()
          }

          // X-Axis labels in non-compact mode
          if (!root.compact) {
            ctx.fillStyle = root.dim
            ctx.font = "8px " + root.fontFamily
            ctx.fillText(root.range === "60s" ? "60s ago" : "1h ago", 2, h - 2)
            ctx.fillText("Now", w - 20, h - 2)
          }
        }
      }

      MouseArea {
        id: canvasMouseArea
        anchors.fill: parent
        hoverEnabled: root.interactive
        cursorShape: root.compact ? Qt.PointingHandCursor : (root.interactive ? Qt.CrossCursor : Qt.ArrowCursor)

        onClicked: {
          if (root.compact) {
            // Toggle between 60s and 1h
            root.range = (root.range === "60s") ? "1h" : "60s"
          }
        }

        onPositionChanged: function(mouse) {
          if (!root.compact && root.rxData.length > 1) {
            var step = width / (root.rxData.length - 1)
            var idx = Math.round(mouse.x / step)
            root.hoverIndex = Math.max(0, Math.min(root.rxData.length - 1, idx))
            sparkCanvas.requestPaint()
          }
        }

        onExited: {
          root.hoverIndex = -1
          sparkCanvas.requestPaint()
        }

        PanelToolTip {
          visible: canvasMouseArea.containsMouse
          fontFamily: root.fontFamily
          text: {
            if (root.compact) {
              return "WAN " + root.range + ": ↓ " + Model.formatRate(root.currentRx) + "bps · ↑ " + Model.formatRate(root.currentTx) + "bps (Click to switch range)"
            }
            if (root.hoverIndex >= 0 && root.hoverIndex < root.rxData.length) {
              var timeStr = root.range === "60s" ? ("-" + (root.rxData.length - 1 - root.hoverIndex) * 2 + "s") : ("-" + (root.rxData.length - 1 - root.hoverIndex) + "m")
              return timeStr + ": ↓ " + Model.formatRate(root.rxData[root.hoverIndex]) + "bps · ↑ " + Model.formatRate(root.txData[root.hoverIndex]) + "bps"
            }
            return "Live WAN Throughput (" + root.range + ")"
          }
        }
      }
    }
  }
}
