function normalizedSymbol(value) {
  return String(value || "").replace(/^\s+|\s+$/g, "").toUpperCase()
}

function symbolIsValid(value) {
  return /^[A-Z0-9][A-Z0-9-]{0,19}\.(US|HK|SH|SZ|SG)$/.test(normalizedSymbol(value))
}

function listLike(value) {
  return value !== null && value !== undefined
    && typeof value !== "string" && typeof value.length === "number"
}

function normalizedSymbols(values, maximum) {
  var source = listLike(values) ? values : []
  var limit = Math.max(1, Number(maximum) || 20)
  var seen = {}
  var result = []
  for (var i = 0; i < source.length && result.length < limit; i++) {
    var symbol = normalizedSymbol(source[i])
    if (!symbolIsValid(symbol) || seen[symbol]) continue
    seen[symbol] = true
    result.push(symbol)
  }
  return result
}

function initialState(symbols) {
  return {
    symbols: normalizedSymbols(symbols),
    quotes: {},
    subscribed: [],
    connection: "idle",
    auth: "unknown",
    error: null
  }
}

function copyObject(source) {
  var result = {}
  for (var key in source) if (Object.prototype.hasOwnProperty.call(source, key)) result[key] = source[key]
  return result
}

function mergedQuote(previous, incoming) {
  var result = copyObject(previous || {})
  for (var key in incoming) {
    if (!Object.prototype.hasOwnProperty.call(incoming, key)) continue
    var value = incoming[key]
    if (value !== "" && value !== null && value !== undefined) result[key] = value
  }
  result.symbol = normalizedSymbol(result.symbol)
  return result
}

function applyEvent(state, event) {
  var next = copyObject(state || initialState([]))
  next.symbols = (state.symbols || []).slice()
  next.subscribed = (state.subscribed || []).slice()
  next.quotes = copyObject(state.quotes || {})
  next.error = state.error || null
  var type = String(event && event.type || "")

  if (type === "connection") {
    next.connection = String(event.state || "disconnected")
  } else if (type === "snapshot") {
    var quotes = listLike(event.quotes) ? event.quotes : []
    for (var i = 0; i < quotes.length; i++) {
      var snapshotSymbol = normalizedSymbol(quotes[i] && quotes[i].symbol)
      if (symbolIsValid(snapshotSymbol))
        next.quotes[snapshotSymbol] = mergedQuote(next.quotes[snapshotSymbol], quotes[i])
    }
  } else if (type === "quote") {
    var symbol = normalizedSymbol(event.symbol)
    if (symbolIsValid(symbol)) next.quotes[symbol] = mergedQuote(next.quotes[symbol], event)
  } else if (type === "subscription") {
    next.subscribed = normalizedSymbols(event.symbols)
    next.connection = "live"
    next.error = null
  } else if (type === "auth") {
    next.auth = String(event.state || "unknown")
  } else if (type === "error") {
    next.error = { code: String(event.code || "unknown"), message: String(event.message || "") }
    if (next.error.code === "not_authenticated") next.auth = "not_authenticated"
  }
  return next
}

function marketForSymbol(symbol) {
  var suffix = normalizedSymbol(symbol).split(".").pop()
  if (suffix === "SH" || suffix === "SZ") return "CN"
  return suffix
}

function rows(state) {
  var result = []
  var symbols = normalizedSymbols(state && state.symbols)
  var quotes = state && state.quotes ? state.quotes : {}
  for (var i = 0; i < symbols.length; i++) {
    var symbol = symbols[i]
    result.push(quotes[symbol] || { symbol: symbol, ready: false })
  }
  return result
}

function marketGroups(state) {
  var order = ["US", "HK", "CN", "SG"]
  var grouped = { US: [], HK: [], CN: [], SG: [] }
  var allRows = rows(state)
  for (var i = 0; i < allRows.length; i++) {
    var market = marketForSymbol(allRows[i].symbol)
    if (grouped[market]) grouped[market].push(allRows[i])
  }
  var result = []
  for (var j = 0; j < order.length; j++) {
    if (grouped[order[j]].length) result.push({ market: order[j], rows: grouped[order[j]] })
  }
  return result
}

function decimalPlaces(value) {
  var number = Math.abs(Number(value))
  return number > 0 && number < 1 ? 4 : 2
}

function groupedFixed(value, places) {
  var fixed = Number(value).toFixed(places).split(".")
  var sign = fixed[0].charAt(0) === "-" ? "-" : ""
  var whole = sign ? fixed[0].slice(1) : fixed[0]
  whole = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  return sign + whole + (fixed.length > 1 ? "." + fixed[1] : "")
}

function formatPrice(value) {
  if (!isFinite(Number(value))) return "—"
  return groupedFixed(value, decimalPlaces(value))
}

function formatPercent(value) {
  var number = Number(value)
  if (!isFinite(number)) return "—"
  return (number > 0 ? "+" : number < 0 ? "−" : "") + Math.abs(number).toFixed(2) + "%"
}

function isStale(quote, nowMs, thresholdMs) {
  var timestamp = Number(quote && quote.timestamp)
  if (!(timestamp > 0)) return true
  var quoteMs = timestamp < 1000000000000 ? timestamp * 1000 : timestamp
  return Number(nowMs) - quoteMs > (Number(thresholdMs) || 120000)
}

if (typeof module !== "undefined") module.exports = {
  normalizedSymbol: normalizedSymbol,
  symbolIsValid: symbolIsValid,
  normalizedSymbols: normalizedSymbols,
  initialState: initialState,
  applyEvent: applyEvent,
  marketForSymbol: marketForSymbol,
  rows: rows,
  marketGroups: marketGroups,
  formatPrice: formatPrice,
  formatPercent: formatPercent,
  isStale: isStale
}

