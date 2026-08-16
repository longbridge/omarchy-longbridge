.pragma library

function helperCommand(path, symbols) {
  var command = [String(path || "")]
  var source = symbols && typeof symbols.length === "number" ? symbols : []
  for (var i = 0; i < source.length; i++) command.push(String(source[i]))
  return command
}

function parse(text) {
  var payload
  try { payload = JSON.parse(String(text || "")) }
  catch (error) { return invalid("Public quote data was unreadable.") }
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return invalid("Public quote data was invalid.")
  if (["ready", "partial", "error"].indexOf(String(payload.state || "")) < 0) return invalid("Public quote data was invalid.")
  if (!Array.isArray(payload.quotes) || !Array.isArray(payload.errors)) return invalid("Public quote data was invalid.")
  var quotes = []
  for (var i = 0; i < payload.quotes.length; i++) {
    var source = payload.quotes[i]
    if (!source || typeof source !== "object" || !source.symbol) return invalid("Public quote data was invalid.")
    quotes.push({
      symbol: String(source.symbol),
      name: String(source.name || ""),
      currency: String(source.currency || ""),
      last: String(source.last || "0"),
      prev_close: String(source.prev_close || "0"),
      open: String(source.open || "0"),
      high: String(source.high || "0"),
      low: String(source.low || "0"),
      volume: String(source.volume || "0"),
      timestamp: Number(source.timestamp || 0),
      trade_status: String(source.trade_status || "UNKNOWN"),
      trade_session: String(source.trade_session || "Intraday")
    })
  }
  var errors = []
  for (var j = 0; j < payload.errors.length; j++) {
    var problem = payload.errors[j]
    if (!problem || typeof problem !== "object" || !problem.symbol) continue
    errors.push({
      symbol: String(problem.symbol),
      code: String(problem.code || "quote_failed"),
      message: String(problem.message || "Quote unavailable.")
    })
  }
  return {
    ok: true,
    state: String(payload.state),
    fetchedAtMs: Number(payload.fetched_at_ms || 0),
    errors: errors,
    event: { type: "snapshot", quotes: quotes, errors: errors }
  }
}

function invalid(message) {
  return { ok: false, error: { code: "invalid_data", message: message } }
}
