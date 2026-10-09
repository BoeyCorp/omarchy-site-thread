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
