var radians = Math.PI / 180
var degrees = 180 / Math.PI

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function wrapLongitude(value) {
  var wrapped = (Number(value) + 180) % 360
  if (wrapped < 0) wrapped += 360
  return wrapped - 180
}

function project(latitude, longitude, centreLatitude, centreLongitude) {
  var phi = Number(latitude) * radians
  var lambda = wrapLongitude(Number(longitude) - Number(centreLongitude)) * radians
  var phi0 = Number(centreLatitude) * radians
  var cosPhi = Math.cos(phi)
  var sinPhi = Math.sin(phi)
  var cosPhi0 = Math.cos(phi0)
  var sinPhi0 = Math.sin(phi0)

  return {
    x: cosPhi * Math.sin(lambda),
    y: cosPhi0 * sinPhi - sinPhi0 * cosPhi * Math.cos(lambda),
    z: sinPhi0 * sinPhi + cosPhi0 * cosPhi * Math.cos(lambda)
  }
}

function unproject(x, y, centreLatitude, centreLongitude) {
  var rho2 = x * x + y * y
  if (rho2 > 1) return null

  var z = Math.sqrt(Math.max(0, 1 - rho2))
  var phi0 = Number(centreLatitude) * radians
  var cosPhi0 = Math.cos(phi0)
  var sinPhi0 = Math.sin(phi0)
  var latitude = Math.asin(y * cosPhi0 + z * sinPhi0)
  var longitude = Number(centreLongitude) * radians
    + Math.atan2(x, z * cosPhi0 - y * sinPhi0)

  return {
    latitude: latitude * degrees,
    longitude: wrapLongitude(longitude * degrees)
  }
}
