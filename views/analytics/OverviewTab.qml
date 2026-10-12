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
  property bool isLightTheme: false

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  property color accentForeground: "#ffffff"
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property color backup: "#f59e0b"
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property string fontFamily: Style.font.family

  property var selectedSiteIds: []
  property int chartHoverIndex: -1
  property real chartHoverMouseX: 0
  property real chartHoverMouseY: 0

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

  function getSiteThroughput(site) {
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
    var target = new Date(now.getTime() - hoursAgo * 3600 * 1000)
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return days[target.getDay()] + ", " + months[target.getMonth()] + " " + target.getDate() + ", " + target.getFullYear()
  }

  function getThroughputTime(idx) {
    if (idx < 0 || idx > 23) return ""
    var now = new Date()
    var hoursAgo = 23 - idx
    var target = new Date(now.getTime() - hoursAgo * 3600 * 1000)
    var h = target.getHours()
    var ampm = h >= 12 ? "PM" : "AM"
    var h12 = h % 12
    if (h12 === 0) h12 = 12
    var hPad = (h12 < 10 ? "0" : "") + h12
    var rel = hoursAgo === 0 ? "Now" : hoursAgo + "h ago"
    return hPad + ":00 " + ampm + " (" + rel + ")"
  }


        spacing: Style.space(10)

        // KPI Grid (4 status displays on Overview page only)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          StatBlock {
            label: "WAN FLEET HEALTH"
            value: (root.fleetData && root.fleetData.severity === "critical") ? "Degraded" : ((root.fleetData && root.fleetData.severity === "warning") ? "Warning" : "100%")
            subvalue: (root.fleetData && root.fleetData.message) ? root.fleetData.message : "0 Failovers active"
            valColor: (root.fleetData && root.fleetData.severity === "critical") ? root.urgent : ((root.fleetData && root.fleetData.severity === "warning") ? root.backup : root.healthy)
            subColor: valColor
            fontFamily: root.fontFamily
            iconText: ""
          }

          StatBlock {
            label: "FLEET CLIENTS"
            value: String(root.fleetData && root.fleetData.network && root.fleetData.network.clientCount !== undefined ? root.fleetData.network.clientCount : 0)
            subvalue: String(root.fleetData && root.fleetData.network && root.fleetData.network.wifiClients !== undefined ? root.fleetData.network.wifiClients : 0) + " WiFi · " + String(root.fleetData && root.fleetData.network && root.fleetData.network.wiredClients !== undefined ? root.fleetData.network.wiredClients : 0) + " Wired"
            valColor: root.accent
            fontFamily: root.fontFamily
            iconText: ""
          }

          StatBlock {
            label: "HARDWARE FLEET"
            value: String(root.fleetData && root.fleetData.network && root.fleetData.network.deviceCount !== undefined ? root.fleetData.network.deviceCount : 0)
            subvalue: String(root.fleetData && root.fleetData.network ? (root.fleetData.network.offlineCount || 0) : 0) + " Offline · " + String(root.fleetData && root.fleetData.network ? (root.fleetData.network.updateCount || 0) : 0) + " Updates"
            valColor: root.foreground
            fontFamily: root.fontFamily
            iconText: ""
          }

          StatBlock {
            label: "SITES OPERATIONAL"
            value: String(root.fleetData && root.fleetData.sites ? root.fleetData.sites.filter(function(s) { return s.status === "online" || s.online !== false; }).length : 0) + "/" + String(root.fleetData && root.fleetData.sites ? root.fleetData.sites.length : 0)
            subvalue: (root.fleetData && root.fleetData.sites && root.fleetData.sites.some(function(s) { return s.status === "down"; })) ? "Sites offline" : "All gateways online"
            valColor: (root.fleetData && root.fleetData.sites && root.fleetData.sites.some(function(s) { return s.status === "down"; })) ? root.urgent : root.healthy
            subColor: valColor
            fontFamily: root.fontFamily
            iconText: ""
          }
        }

        // Two-column Overview & Mesh Split
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
            id: wanThroughputCard
            title: "24-HOUR WAN THROUGHPUT"
            subtitle: {
              var tp = root.getActiveThroughput()
              var siteNames = tp.activeSites.map(function(s) { return s.name }).join(" · ")
              if (!siteNames) siteNames = "All Managed Sites"
              return siteNames + " · Peak: " + tp.peakRx.toFixed(1) + " Mbps DL / " + tp.peakTx.toFixed(1) + " Mbps UL"
            }
            iconText: ""
            titleColor: root.foreground
            badgeText: root.selectedSiteIds.length > 0
              ? ("FILTERED (" + root.selectedSiteIds.length + ")")
              : "REAL-TIME"
            badgeColor: root.selectedSiteIds.length > 0 ? root.accent : root.healthy
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
                function onSelectedSiteIdsChanged() { chartCanvas.requestPaint() }
                function onChartHoverIndexChanged() { chartCanvas.requestPaint() }
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

                var tp = root.getActiveThroughput()
                var rxData = tp.rx
                var txData = tp.tx
                var peakRx = tp.peakRx

                var maxVal = Math.max(40, Math.ceil(peakRx / 20) * 20)
                if (maxVal < 60 && maxVal > 40) maxVal = 60
                if (maxVal > 80 && maxVal < 100) maxVal = 100

                // Grid lines & Y-axis labels
                ctx.strokeStyle = root.isLightTheme ? "#cbd5e1" : "#2a324b"
                ctx.fillStyle = root.dim
                ctx.font = "8px " + root.fontFamily
                ctx.lineWidth = 0.5
                var stepVal = maxVal / 4
                for (var g = 0; g <= 4; g++) {
                  var y = 8 + (chartH / 4) * g
                  ctx.beginPath()
                  ctx.moveTo(leftPad, y)
                  ctx.lineTo(w - 10, y)
                  ctx.stroke()
                  var lblVal = Math.round(maxVal - g * stepVal)
                  ctx.fillText(lblVal + "M", 2, y + 3)
                }

                // X-axis time labels
                var timeLabels = ["24h ago", "18h", "12h", "6h", "Now"]
                for (var t = 0; t < timeLabels.length; t++) {
                  var tx = leftPad + (chartW / 4) * t
                  ctx.fillText(timeLabels[t], tx - (t === 4 ? 18 : 10), h - 3)
                }

                // Draw Download Curve
                ctx.beginPath()
                var step = chartW / (rxData.length - 1)
                for (var i = 0; i < rxData.length; i++) {
                  var px = leftPad + i * step
                  var py = 8 + chartH - (rxData[i] / maxVal) * chartH
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
                  var txY = 8 + chartH - (txData[j] / maxVal) * chartH
                  if (j === 0) ctx.moveTo(txX, txY)
                  else ctx.lineTo(txX, txY)
                }
                ctx.strokeStyle = root.healthy
                ctx.lineWidth = 1.5
                ctx.stroke()

                // Vertical scrub line and highlight dots on hover
                if (root.chartHoverIndex >= 0 && root.chartHoverIndex < rxData.length) {
                  var hx = leftPad + root.chartHoverIndex * step
                  var hrxY = 8 + chartH - (rxData[root.chartHoverIndex] / maxVal) * chartH
                  var htxY = 8 + chartH - (txData[root.chartHoverIndex] / maxVal) * chartH

                  ctx.save()
                  ctx.beginPath()
                  ctx.strokeStyle = root.isLightTheme ? "#94a3b8" : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.7)
                  ctx.lineWidth = 1.0
                  ctx.setLineDash([3, 3])
                  ctx.moveTo(hx, 8)
                  ctx.lineTo(hx, 8 + chartH)
                  ctx.stroke()
                  ctx.restore()

                  // Download halo and dot
                  ctx.beginPath()
                  ctx.arc(hx, hrxY, 6, 0, 2 * Math.PI)
                  ctx.fillStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
                  ctx.fill()
                  ctx.beginPath()
                  ctx.arc(hx, hrxY, 3.5, 0, 2 * Math.PI)
                  ctx.fillStyle = root.accent
                  ctx.fill()

                  // Upload halo and dot
                  ctx.beginPath()
                  ctx.arc(hx, htxY, 5, 0, 2 * Math.PI)
                  ctx.fillStyle = Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.35)
                  ctx.fill()
                  ctx.beginPath()
                  ctx.arc(hx, htxY, 3, 0, 2 * Math.PI)
                  ctx.fillStyle = root.healthy
                  ctx.fill()
                }
              }

              MouseArea {
                id: chartMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.CrossCursor

                onPositionChanged: function(mouse) {
                  var leftPad = 32
                  var rightPad = 10
                  var chartW = chartCanvas.width - leftPad - rightPad
                  if (chartW <= 0) return
                  var clampedX = Math.max(leftPad, Math.min(chartCanvas.width - rightPad, mouse.x))
                  var ratio = (clampedX - leftPad) / chartW
                  var idx = Math.max(0, Math.min(23, Math.round(ratio * 23)))
                  root.chartHoverIndex = idx
                  root.chartHoverMouseX = mouse.x
                  root.chartHoverMouseY = mouse.y
                  chartCanvas.requestPaint()
                }

                onExited: {
                  root.chartHoverIndex = -1
                  chartCanvas.requestPaint()
                }
              }

              // Info card tooltip
              Rectangle {
                id: infoCard
                visible: root.chartHoverIndex >= 0
                enabled: false
                z: 100
                width: cardLayout.implicitWidth + Style.space(18)
                height: cardLayout.implicitHeight + Style.space(16)
                radius: 6
                color: root.isLightTheme ? "#ffffff" : "#161b2a"
                border.width: 1
                border.color: root.accent

                x: {
                  var targetX = root.chartHoverMouseX + 16
                  if (targetX + width > chartCanvas.width - 8) {
                    targetX = root.chartHoverMouseX - width - 16
                  }
                  return Math.max(8, Math.min(chartCanvas.width - width - 8, targetX))
                }
                y: {
                  var targetY = root.chartHoverMouseY - height / 2
                  return Math.max(8, Math.min(chartCanvas.height - height - 8, targetY))
                }

                ColumnLayout {
                  id: cardLayout
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(4)

                  // Date & Time row
                  RowLayout {
                    spacing: Style.space(6)
                    Text {
                      textFormat: Text.PlainText;
                      text: ""
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                    }
                    ColumnLayout {
                      spacing: 1
                      Text {
                        textFormat: Text.PlainText;
                        text: root.getThroughputDate(root.chartHoverIndex)
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }
                      Text {
                        textFormat: Text.PlainText;
                        text: root.getThroughputTime(root.chartHoverIndex)
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                      }
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.outline
                  }

                  // Download speed row
                  RowLayout {
                    spacing: Style.space(6)
                    Rectangle {
                      width: 7
                      height: 7
                      radius: 3.5
                      color: root.accent
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: "Download:"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                    }
                    Text {
                      textFormat: Text.PlainText;
                      readonly property var tp: root.getActiveThroughput()
                      text: (tp.rx[root.chartHoverIndex] !== undefined ? tp.rx[root.chartHoverIndex].toFixed(1) : "0.0") + " Mbps"
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                      Layout.alignment: Qt.AlignRight
                    }
                  }

                  // Upload speed row
                  RowLayout {
                    spacing: Style.space(6)
                    Rectangle {
                      width: 7
                      height: 7
                      radius: 3.5
                      color: root.healthy
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: "Upload:"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                    }
                    Text {
                      textFormat: Text.PlainText;
                      readonly property var tp: root.getActiveThroughput()
                      text: (tp.tx[root.chartHoverIndex] !== undefined ? tp.tx[root.chartHoverIndex].toFixed(1) : "0.0") + " Mbps"
                      color: root.healthy
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                      Layout.alignment: Qt.AlignRight
                    }
                  }

                  // Scope indicator
                  RowLayout {
                    visible: root.selectedSiteIds.length > 0
                    spacing: 4
                    Text {
                      textFormat: Text.PlainText;
                      readonly property var tp: root.getActiveThroughput()
                      text: " " + (tp.activeSites.length === 1 ? tp.activeSites[0].name : (tp.activeSites.length + " sites filtered"))
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 3
                      elide: Text.ElideRight
                      Layout.maximumWidth: Style.space(160)
                    }
                  }
                }
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
            subtitle: String(root.fleetData && root.fleetData.network ? (root.fleetData.network.clientCount || 0) : 0) + " clients across " + String(root.fleetData && root.fleetData.network ? (root.fleetData.network.deviceCount || 0) : 0) + " managed devices"
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

              readonly property int totalClients: root.fleetData && root.fleetData.network && root.fleetData.network.clientCount !== undefined ? root.fleetData.network.clientCount : 0
              readonly property int wifiClients: root.fleetData && root.fleetData.network && root.fleetData.network.wifiClients !== undefined ? root.fleetData.network.wifiClients : 0
              readonly property int wiredClients: root.fleetData && root.fleetData.network && root.fleetData.network.wiredClients !== undefined ? root.fleetData.network.wiredClients : 0

              Text {
                textFormat: Text.PlainText;
                text: "WiFi Wireless Clients (" + parent.wifiClients + " clients · " + (parent.totalClients > 0 ? Math.round(parent.wifiClients / parent.totalClients * 100) : 0) + "%)"
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
                  width: Math.max(0, parent.width * (parent.parent.totalClients > 0 ? (parent.parent.wifiClients / parent.parent.totalClients) : 0))
                  height: parent.height
                  radius: 4
                  color: root.accent
                }
              }

              Text {
                textFormat: Text.PlainText;
                text: "Wired Ethernet Clients (" + parent.wiredClients + " clients · " + (parent.totalClients > 0 ? Math.round(parent.wiredClients / parent.totalClients * 100) : 0) + "%)"
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
                  width: Math.max(0, parent.width * (parent.parent.totalClients > 0 ? (parent.parent.wiredClients / parent.parent.totalClients) : 0))
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
            subtitle: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.name ? root.fleetData.sdwan.name : ((root.fleetData && root.fleetData.sites && root.fleetData.sites.length > 0) ? root.fleetData.sites[0].name + " Mesh" : "Inter-Site Mesh")) + " · Zero-Trust Inter-Site Mesh"
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
                        text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0) ? root.fleetData.sdwan.connections[0].siteA : (root.fleetData && root.fleetData.sites && root.fleetData.sites.length > 0 ? root.fleetData.sites[0].name : "Primary Site")
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.maximumWidth: Style.space(120)
                      }
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0) ? root.fleetData.sdwan.connections[0].subnetA : (root.fleetData && root.fleetData.sites && root.fleetData.sites.length > 0 && root.fleetData.sites[0].gatewayIp ? root.fleetData.sites[0].gatewayIp + "/24" : "Direct Gateway Link")
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 3
                      elide: Text.ElideRight
                      Layout.maximumWidth: Style.space(120)
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
                        text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0) ? root.fleetData.sdwan.connections[0].siteB : (root.fleetData && root.fleetData.sites && root.fleetData.sites.length > 1 ? root.fleetData.sites[1].name : "Secondary Site")
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.maximumWidth: Style.space(120)
                      }
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0) ? root.fleetData.sdwan.connections[0].subnetB : (root.fleetData && root.fleetData.sites && root.fleetData.sites.length > 1 && root.fleetData.sites[1].gatewayIp ? root.fleetData.sites[1].gatewayIp + "/24" : "Direct Gateway Link")
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 3
                      elide: Text.ElideRight
                      Layout.maximumWidth: Style.space(120)
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
            subtitle: root.selectedSiteIds.length > 0
              ? "Filtering " + root.selectedSiteIds.length + " of " + (root.fleetData && root.fleetData.sites ? root.fleetData.sites.length : 0) + " sites · Click site to toggle"
              : "Active gateways, public IPs, and ISPs · Click site to filter throughput"
            iconText: ""
            titleColor: root.foreground
            fontFamily: root.fontFamily
            badgeText: root.selectedSiteIds.length > 0 ? (root.selectedSiteIds.length + " FILTERED") : "ALL SITES"
            badgeColor: root.selectedSiteIds.length > 0 ? root.accent : root.dim
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

                // Filter Active Reset Banner
                Rectangle {
                  visible: root.selectedSiteIds.length > 0
                  width: parent.width
                  height: 24
                  radius: 3
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                  border.width: 1
                  border.color: root.accent

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8

                    Text {
                      textFormat: Text.PlainText;
                      text: " Filter active: showing " + root.selectedSiteIds.length + " site(s)"
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true
                      Layout.fillWidth: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      text: "✕ Reset filter"
                      color: resetMouse.containsMouse ? root.foreground : root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true

                      MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearSiteSelection()
                      }
                    }
                  }
                }

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
                    readonly property bool isSelected: root.isSiteSelected(modelData)
                    width: siteMatrixCol.width
                    height: siteCol.childrenRect.height + Style.space(12)
                    radius: 4
                    color: isSelected
                      ? (root.isLightTheme ? "#e8effe" : "#1a2540")
                      : (siteCardMouse.containsMouse ? root.cardHover : root.track)
                    border.width: isSelected ? 2 : 1
                    border.color: isSelected
                      ? root.accent
                      : (siteCardMouse.containsMouse ? root.dim : root.outline)

                    MouseArea {
                      id: siteCardMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.toggleSiteSelection(modelData)
                      }
                    }

                    Column {
                      id: siteCol
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.margins: Style.space(6)
                      spacing: Style.space(3)

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
                          width: parent.width - 150
                          elide: Text.ElideRight
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        // Filter Pill
                        Rectangle {
                          height: 16
                          width: filterBadgeText.implicitWidth + 8
                          radius: 2
                          anchors.verticalCenter: parent.verticalCenter
                          color: isSelected ? root.accent : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.15)
                          border.width: 1
                          border.color: isSelected ? root.accent : root.outline

                          Text {
                            textFormat: Text.PlainText;
                            id: filterBadgeText
                            anchors.centerIn: parent
                            text: isSelected ? "✓ FILTERED" : "FILTER"
                            color: isSelected ? root.accentForeground : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }

                        Rectangle {
                          height: 16
                          width: statusTextTag.implicitWidth + 8
                          radius: 2
                          anchors.verticalCenter: parent.verticalCenter
                          color: modelData.status === "down" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2) : (modelData.status === "backup" ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2) : Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2))
                          Text {
                            textFormat: Text.PlainText;
                            id: statusTextTag
                            anchors.centerIn: parent
                            text: modelData.status === "down" ? "OFFLINE" : (modelData.status === "backup" ? "BACKUP WAN" : "ONLINE")
                            color: modelData.status === "down" ? root.urgent : (modelData.status === "backup" ? root.backup : root.healthy)
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        width: parent.width
                        text: (modelData.gatewayModel || "Gateway") + " · IP: " + (modelData.gatewayIp || "DHCP") + " · ISP: " + (modelData.isp || "Unknown ISP")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                      }

                      Row {
                        width: parent.width
                        spacing: Style.space(10)

                        Text {
                          textFormat: Text.PlainText;
                          text: " " + (modelData.clientCount || 0) + " clients"
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
