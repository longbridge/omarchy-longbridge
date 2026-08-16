var allowedTypes = {
  connection: true,
  snapshot: true,
  quote: true,
  subscription: true,
  auth: true,
  search: true,
  error: true
}

function consume(buffer, chunk) {
  var combined = String(buffer || "") + String(chunk || "")
  var lines = combined.split("\n")
  var remainder = lines.pop()
  var events = []
  var errors = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/^\s+|\s+$/g, "")
    if (line === "") continue
    try {
      var event = JSON.parse(line)
      if (!event || !allowedTypes[String(event.type || "")]) errors.push("unknown_event")
      else events.push(event)
    } catch (error) {
      errors.push("malformed_json")
    }
  }
  return { events: events, remainder: remainder, errors: errors }
}

if (typeof module !== "undefined") module.exports = { consume: consume }

