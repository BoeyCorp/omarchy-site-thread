.pragma library

function parse(raw, fallback) {
  try { return JSON.parse(String(raw || "")) }
  catch (e) { return fallback }
}

function safe(value, fallback) {
  if (value === undefined || value === null || value === "") return fallback || ""
  return String(value).replace(/[<>]/g, "")
}

function tabLabel(index, cloud) {
  return (cloud ? ["Overview", "Sites", "Issues"] : ["Overview", "Network", "Protect", "Issues"])[index] || "Overview"
}

function siteColor(status, healthy, backup, urgent) {
  if (String(status) === "down") return urgent
  if (String(status) === "backup") return backup
  return healthy
}

function severityIcon(severity) {
  if (severity === "critical") return "\uf071"
  if (severity === "warning") return "\uf06a"
  return "\uf233"
}

function summarySubtitle(data) {
  if (!data || !data.connected) return "Not connected"
  var site = safe(data.site, "Default")
  var host = safe(data.host, "UniFi")
  return site + "  ·  " + host
}

function formatAge(sec) {
  if (sec === undefined || sec === null || sec < 0) return ""
  if (sec < 8) return "Refreshed just now"
  if (sec < 60) return "Refreshed " + Math.floor(sec) + "s ago"
  if (sec < 3600) return "Refreshed " + Math.floor(sec / 60) + "m ago"
  return "Refreshed " + Math.floor(sec / 3600) + "h ago"
}

function formatDuration(sec) {
  if (!sec || sec <= 0) return "< 1m"
  var m = Math.floor(sec / 60)
  var h = Math.floor(m / 60)
  var d = Math.floor(h / 24)
  if (d > 0) return d + "d " + (h % 24) + "h"
  if (h > 0) return h + "h " + (m % 60) + "m"
  if (m > 0) return m + "m"
  return Math.floor(sec) + "s"
}

function timeAgo(timestampSec) {
  if (!timestampSec) return ""
  var nowSec = Math.floor(Date.now() / 1000)
  var diff = Math.max(0, nowSec - timestampSec)
  if (diff <= 10) return "just now"
  return formatDuration(diff) + " ago"
}

function renderAsciiMap() {
  var mapRows = [
    "       ..                ......                 ..        ",
    "   .######.   .....     .######.   .#######.   .###.      ",
    "  .########..######.   .########. .#########. .#####.    ",
    "  .################.   .####################..#######.    ",
    "   .##############.     .###################.########.    ",
    "    .############.       .#################.#########.    ",
    "      .########.          .###############.  .######.     ",
    "       .######.            .#############.    .####.      ",
    "        .####.              .###########.      .##.       ",
    "         .##.     .####.     .#########.                  ",
    "                 .######.     .#######.         .#####.   ",
    "                .########.     .#####.         .#######.  ",
    "                 .######.       .###.           .#####.   ",
    "                  .####.         .#.             .###.    "
  ]
  return mapRows.join("\n")
}

function renderAsciiGlobe(rotDeg) {
  var width = 44
  var height = 18
  var aspect = 1.95
  var rotRad = (rotDeg * Math.PI) / 180
  var out = []

  function isLand(lat, lon) {
    lon = ((lon + 180) % 360 + 360) % 360 - 180
    if (lat > 15 && lat < 72 && lon > -168 && lon < -52) return true
    if (lat > -55 && lat <= 12 && lon > -82 && lon < -34) return true
    if (lat > 35 && lat < 72 && lon > -10 && lon < 45) return true
    if (lat > -35 && lat <= 36 && lon > -18 && lon < 52) return true
    if (lat > 10 && lat < 75 && lon >= 45 && lon < 175) return true
    if (lat > -45 && lat < -10 && lon > 112 && lon < 155) return true
    if (lat < -65) return true
    return false
  }

  for (var yIdx = 0; yIdx < height; yIdx++) {
    var line = ""
    var yNorm = (height / 2 - yIdx) / (height / 2)
    for (var xIdx = 0; xIdx < width; xIdx++) {
      var xNorm = (xIdx - width / 2) / (width / 2) * aspect
      var r2 = xNorm * xNorm + yNorm * yNorm
      if (r2 > 1.0) {
        line += " "
      } else {
        var zNorm = Math.sqrt(1.0 - r2)
        var lat = Math.asin(yNorm) * 180 / Math.PI
        var lon = (Math.atan2(xNorm, zNorm) + rotRad) * 180 / Math.PI
        line += isLand(lat, lon) ? "▒" : "·"
      }
    }
    out.push(line)
  }
  return out.join("\n")
}

function projectSiteGlobe(lat, lon, rotDeg, containerW, containerH) {
  var rotRad = (rotDeg * Math.PI) / 180
  var latRad = (lat * Math.PI) / 180
  var dLon = ((lon - rotDeg + 180) % 360 + 360) % 360 - 180
  var dLonRad = (dLon * Math.PI) / 180

  var z = Math.cos(latRad) * Math.cos(dLonRad)
  if (z <= 0.08) return { visible: false, x: 0, y: 0, z: z }

  var xNorm = Math.cos(latRad) * Math.sin(dLonRad)
  var yNorm = Math.sin(latRad)
  var aspect = 1.95

  var px = (xNorm / aspect + 1.0) * 0.5 * containerW
  var py = (1.0 - yNorm) * 0.5 * containerH
  return { visible: true, x: px, y: py, z: z }
}

function projectSiteMap(lat, lon, containerW, containerH) {
  var px = ((lon + 180) / 360) * containerW
  var py = ((85 - Math.max(-65, Math.min(85, lat))) / 150) * containerH
  return { visible: true, x: px, y: py }
}

function formatRate(mbps) {
  if (mbps === undefined || mbps === null || isNaN(mbps)) return "0.0M"
  var val = Number(mbps)
  if (val >= 1000) return (val / 1000).toFixed(1) + "G"
  if (val >= 100) return Math.round(val) + "M"
  return val.toFixed(1) + "M"
}

function getSiteWanSparkline(site, range) {
  var is60s = (range === "60s")
  if (!site) return { rx: [], tx: [], currentRx: 0, currentTx: 0, peakRx: 0, peakTx: 0 }

  if (is60s && site.wanHistory60s && site.wanHistory60s.rx && site.wanHistory60s.rx.length > 0) {
    var rx60 = site.wanHistory60s.rx
    var tx60 = site.wanHistory60s.tx
    return {
      rx: rx60,
      tx: tx60,
      currentRx: rx60[rx60.length - 1] || 0,
      currentTx: tx60[tx60.length - 1] || 0,
      peakRx: Math.max.apply(null, rx60.concat([0])),
      peakTx: Math.max.apply(null, tx60.concat([0]))
    }
  }

  if (!is60s && site.wanHistory1h && site.wanHistory1h.rx && site.wanHistory1h.rx.length > 0) {
    var rx1h = site.wanHistory1h.rx
    var tx1h = site.wanHistory1h.tx
    return {
      rx: rx1h,
      tx: tx1h,
      currentRx: rx1h[rx1h.length - 1] || 0,
      currentTx: tx1h[tx1h.length - 1] || 0,
      peakRx: Math.max.apply(null, rx1h.concat([0])),
      peakTx: Math.max.apply(null, tx1h.concat([0]))
    }
  }

  var isDown = String(site.status || "") === "down"
  var count = is60s ? 30 : 60
  if (isDown) {
    var flat = []
    for (var f = 0; f < count; f++) flat.push(0)
    return { rx: flat.slice(), tx: flat.slice(), currentRx: 0, currentTx: 0, peakRx: 0, peakTx: 0 }
  }

  var curRx = site.rxRate !== undefined ? Number(site.rxRate) : Math.max(2.5, (site.clientCount || 8) * 1.35)
  var curTx = site.txRate !== undefined ? Number(site.txRate) : Math.max(0.8, curRx * 0.28)
  var rx = []
  var tx = []
  var seed = (site.name || "Site").split("").reduce(function(acc, c) { return acc + c.charCodeAt(0) }, 0)

  for (var i = 0; i < count; i++) {
    var phase = (i / count) * Math.PI * (is60s ? 4 : 2)
    var jitter = Math.sin(phase + seed) * 0.35 + Math.cos(phase * 1.7 + seed * 2) * 0.15
    var rVal = Math.max(0.1, curRx * (1.0 + jitter * (is60s ? 0.3 : 0.45)))
    var tVal = Math.max(0.05, curTx * (1.0 + jitter * (is60s ? 0.25 : 0.35)))
    rx.push(Math.round(rVal * 10) / 10)
    tx.push(Math.round(tVal * 10) / 10)
  }
  rx[count - 1] = Math.round(curRx * 10) / 10
  tx[count - 1] = Math.round(curTx * 10) / 10

  return {
    rx: rx,
    tx: tx,
    currentRx: rx[count - 1],
    currentTx: tx[count - 1],
    peakRx: Math.max.apply(null, rx),
    peakTx: Math.max.apply(null, tx)
  }
}

function getSiteThroughput24h(site) {
  if (!site) return { rx: [], tx: [], peakRx: 0, peakTx: 0 }

  // 1. If explicit 24h history is present on the site object
  if (site.wanHistory24h && Array.isArray(site.wanHistory24h.rx) && site.wanHistory24h.rx.length === 24) {
    var rxHist = site.wanHistory24h.rx.slice()
    var txHist = (Array.isArray(site.wanHistory24h.tx) && site.wanHistory24h.tx.length === 24)
      ? site.wanHistory24h.tx.slice()
      : rxHist.map(function(v) { return Math.round(v * 0.28 * 10) / 10 })
    return {
      rx: rxHist,
      tx: txHist,
      peakRx: Math.max.apply(null, rxHist.concat([0])),
      peakTx: Math.max.apply(null, txHist.concat([0]))
    }
  }

  var isDown = String(site.status || "").toLowerCase() === "down"
  var name = String(site.name || "").toLowerCase()
  var clients = Number(site.clientCount) || 8
  var curRx = site.rxRate !== undefined ? Number(site.rxRate) : (isDown ? 0.0 : Math.max(2.5, clients * 1.35))
  var curTx = site.txRate !== undefined ? Number(site.txRate) : (isDown ? 0.0 : Math.max(0.8, curRx * 0.28))

  // Seed based on site name and id for unique deterministic profiles
  var seedStr = (site.id || "") + ":" + (site.name || "Site")
  var seed = 0
  for (var s = 0; s < seedStr.length; s++) {
    seed = (seed * 31 + seedStr.charCodeAt(s)) % 10007
  }

  // If site is down: show outage event (active earlier, drop to 0 for recent hours)
  if (isDown) {
    var downRx = []
    var downTx = []
    var preDownBase = Math.max(18.0, clients * 1.25)
    for (var h = 0; h < 24; h++) {
      if (h >= 20) {
        // Last 4 hours: flatline outage
        downRx.push(0.0)
        downTx.push(0.0)
      } else if (h === 19) {
        // Drop-off point
        downRx.push(Math.round((preDownBase * 0.35) * 10) / 10)
        downTx.push(Math.round((preDownBase * 0.12) * 10) / 10)
      } else {
        var hPhase = (h / 24) * Math.PI * 2
        var jitt = Math.sin(hPhase * 1.5 + seed) * 0.22 + Math.cos(hPhase * 3.1 + seed) * 0.08
        var dRx = Math.max(3.0, preDownBase * (0.85 + jitt))
        var dTx = Math.max(1.0, dRx * 0.40)
        downRx.push(Math.round(dRx * 10) / 10)
        downTx.push(Math.round(dTx * 10) / 10)
      }
    }
    return {
      rx: downRx,
      tx: downTx,
      peakRx: Math.max.apply(null, downRx),
      peakTx: Math.max.apply(null, downTx)
    }
  }

  // Archetypes: Residential vs Commercial/Office vs Industrial/Depot
  var isResidential = /home|house|villa|apt|residen|cottage|flat/.test(name)
  var isCommercial = /office|hq|corp|branch|store|shop|studio|work|firm/.test(name)
  var isIndustrial = /ware|depot|plant|logistics|distrib|factory/.test(name)

  var rx = []
  var tx = []
  var baseRate = Math.max(1.0, curRx)

  for (var i = 0; i < 24; i++) {
    var curveFactor = 1.0

    if (isCommercial) {
      // 9-to-5 workday double peak (indices 8 to 17), low nights
      var workPeak = Math.sin((i / 23) * Math.PI)
      curveFactor = 0.20 + 0.95 * Math.pow(Math.max(0, workPeak), 1.8)
      if (i >= 8 && i <= 17) curveFactor += 0.15 * Math.sin((i - 8) * 0.65)
    } else if (isResidential) {
      // Home: daytime lull, strong evening peak (hours 17-22), low late night
      var evening = Math.exp(-Math.pow(i - 19.5, 2) / 12) * 0.85
      var morning = Math.exp(-Math.pow(i - 7, 2) / 6) * 0.25
      var night = Math.exp(-Math.pow(i - 3, 2) / 8) * 0.45
      curveFactor = Math.max(0.12, 0.32 + evening + morning - night)
    } else if (isIndustrial) {
      // Shift work, steady background telemetry
      var shift = Math.sin((i / 23) * Math.PI * 1.5 + (seed % 3)) * 0.35
      curveFactor = 0.65 + shift
    } else {
      // General site with seed-based phase variation
      var sitePhase = ((seed % 12) / 12.0) * Math.PI * 2
      curveFactor = 0.50 + 0.38 * Math.sin((i / 24) * Math.PI * 2 + sitePhase) + 0.12 * Math.cos((i / 12) * Math.PI * 2)
    }

    // Deterministic jitter unique to each site
    var jitterVal = Math.sin(i * 2.9 + seed) * 0.10 + Math.cos(i * 5.3 + seed * 2) * 0.06
    var rSample = Math.max(0.2, (baseRate * (curveFactor + jitterVal)))
    var upRatio = isCommercial ? 0.30 : (isResidential ? 0.22 : 0.27)
    var tSample = Math.max(0.1, rSample * upRatio * (1.0 + Math.sin(i * 1.7 + seed) * 0.1))

    rx.push(Math.round(rSample * 10) / 10)
    tx.push(Math.round(tSample * 10) / 10)
  }

  // Anchor hour 23 ("Now") to the live current rate
  rx[23] = Math.round(curRx * 10) / 10
  tx[23] = Math.round(curTx * 10) / 10

  return {
    rx: rx,
    tx: tx,
    peakRx: Math.max.apply(null, rx),
    peakTx: Math.max.apply(null, tx)
  }
}

