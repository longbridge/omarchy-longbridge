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
    groups: [],
    defaultGroupId: "",
    activeGroupId: "",
    quotes: {},
    quoteErrors: {},
    charts: {},
    subscribed: [],
    connection: "idle",
    auth: "unknown",
    error: null
  }
}

function applyGroups(state, groups, defaultGroupId) {
  var next = copyObject(state || initialState([]))
  var source = listLike(groups) ? groups : []
  next.groups = []
  for (var i = 0; i < source.length; i++) {
    var group = source[i] || {}
    var securities = []
    var rows = listLike(group.securities) ? group.securities : []
    for (var j = 0; j < rows.length; j++) securities.push(copyObject(rows[j] || {}))
    next.groups.push({ id: String(group.id), name: String(group.name || ""), securities: securities })
  }
  next.defaultGroupId = String(defaultGroupId || "")
  var activeExists = false
  for (var k = 0; k < next.groups.length; k++)
    if (next.groups[k].id === String(state && state.activeGroupId || "")) activeExists = true
  next.activeGroupId = activeExists ? String(state.activeGroupId) : next.defaultGroupId
  return next
}

function selectGroup(state, groupId) {
  var wanted = String(groupId || "")
  var next = copyObject(state || initialState([]))
  next.groups = (state.groups || []).slice()
  for (var i = 0; i < next.groups.length; i++) {
    if (next.groups[i].id === wanted) {
      next.activeGroupId = wanted
      return next
    }
  }
  return next
}

function activeGroup(state) {
  var groups = state && state.groups ? state.groups : []
  var wanted = String(state && state.activeGroupId || "")
  for (var i = 0; i < groups.length; i++) if (String(groups[i].id) === wanted) return groups[i]
  return null
}

function symbolKeyIsValid(value) {
  return /^\S+\.[A-Z]{2}$/.test(normalizedSymbol(value))
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
  next.quoteErrors = copyObject(state.quoteErrors || {})
  next.charts = copyObject(state.charts || {})
  next.error = state.error || null
  var type = String(event && event.type || "")

  if (type === "connection") {
    next.connection = String(event.state || "disconnected")
  } else if (type === "snapshot") {
    var quotes = listLike(event.quotes) ? event.quotes : []
    for (var i = 0; i < quotes.length; i++) {
      var snapshotSymbol = normalizedSymbol(quotes[i] && quotes[i].symbol)
      if (symbolKeyIsValid(snapshotSymbol)) {
        next.quotes[snapshotSymbol] = mergedQuote(next.quotes[snapshotSymbol], quotes[i])
        delete next.quoteErrors[snapshotSymbol]
      }
    }
    var errors = listLike(event.errors) ? event.errors : []
    for (var j = 0; j < errors.length; j++) {
      var errorSymbol = normalizedSymbol(errors[j] && errors[j].symbol)
      if (symbolKeyIsValid(errorSymbol)) next.quoteErrors[errorSymbol] = String(errors[j].message || "Quote unavailable.")
    }
  } else if (type === "quote") {
    var symbol = normalizedSymbol(event.symbol)
    if (symbolKeyIsValid(symbol)) next.quotes[symbol] = mergedQuote(next.quotes[symbol], event)
  } else if (type === "chart") {
    var chartSymbol = normalizedSymbol(event.symbol)
    if (symbolKeyIsValid(chartSymbol) && event.series) next.charts[chartSymbol] = event.series
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

function marketPriority(symbol) {
  var suffix = normalizedSymbol(symbol).split(".").pop()
  if (suffix === "US") return 0
  if (suffix === "HK") return 1
  if (suffix === "SH" || suffix === "SZ") return 2
  if (suffix === "SG") return 3
  return 99
}

// Mirrors the terminal's watchlist ordering (longbridge-terminal
// src/data/watchlist.rs): symbols in their normal trading session first, then
// by market, and stable within a key so equal rows keep the order Longbridge
// returned rather than picking up an arbitrary alphabetical tiebreaker.
//
// A row without a session yet counts as Intraday, matching the terminal, where
// trade_session defaults to Intraday and only a push moves it. So a symbol
// falls to the bottom only when it actually ticks outside regular hours — an
// overnight-eligible name during the overnight session, say — while the rest of
// its market holds its place.
function orderedRows(rows) {
  var indices = []
  for (var i = 0; i < rows.length; i++) indices.push(i)
  indices.sort(function(a, b) {
    var notTradingA = rows[a].trade_session && rows[a].trade_session !== "Intraday" ? 1 : 0
    var notTradingB = rows[b].trade_session && rows[b].trade_session !== "Intraday" ? 1 : 0
    if (notTradingA !== notTradingB) return notTradingA - notTradingB
    var marketA = marketPriority(rows[a].symbol)
    var marketB = marketPriority(rows[b].symbol)
    if (marketA !== marketB) return marketA - marketB
    return a - b
  })
  var result = []
  for (var j = 0; j < indices.length; j++) result.push(rows[indices[j]])
  return result
}

function rows(state) {
  var result = []
  var seen = {}
  var quotes = state && state.quotes ? state.quotes : {}
  var errors = state && state.quoteErrors ? state.quoteErrors : {}
  var charts = state && state.charts ? state.charts : {}
  var group = activeGroup(state)
  var securities = group && listLike(group.securities) ? group.securities : null
  var symbols = securities ? [] : normalizedSymbols(state && state.symbols)
  var length = securities ? securities.length : symbols.length
  for (var i = 0; i < length; i++) {
    var security = securities ? securities[i] : { symbol: symbols[i] }
    var symbol = normalizedSymbol(security.symbol)
    if (seen[symbol]) continue
    seen[symbol] = true
    var row = mergedQuote(quotes[symbol] || { symbol: symbol }, security)
    row.ready = !!quotes[symbol]
    row.errorMessage = String(errors[symbol] || "")
    row.series = charts[symbol] || null
    result.push(row)
  }
  return orderedRows(result)
}

// Quick filter for the watchlist box: case-insensitive substring over both the
// symbol and the security name, so "tsm", "TSM.US" and "taiwan" all reach the
// same row.
function filterRows(rows, query) {
  var source = listLike(rows) ? rows : []
  var needle = String(query || "").replace(/^\s+|\s+$/g, "").toLowerCase()
  if (needle === "") return source
  var result = []
  for (var i = 0; i < source.length; i++) {
    var row = source[i] || {}
    var symbol = String(row.symbol || "").toLowerCase()
    var name = String(row.name || "").toLowerCase()
    if (symbol.indexOf(needle) >= 0 || name.indexOf(needle) >= 0) result.push(row)
  }
  return result
}

// The list is keyed by symbol so its delegates survive a price tick: the rows
// themselves are rebuilt on every update, but this stays identical unless
// membership, filtering or ordering actually changed.
function rowKeys(rows) {
  var source = listLike(rows) ? rows : []
  var result = []
  for (var i = 0; i < source.length; i++) result.push(String(source[i] && source[i].symbol || ""))
  return result
}

function rowsBySymbol(rows) {
  var source = listLike(rows) ? rows : []
  var result = {}
  for (var i = 0; i < source.length; i++) {
    var symbol = String(source[i] && source[i].symbol || "")
    if (symbol) result[symbol] = source[i]
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
  applyGroups: applyGroups,
  selectGroup: selectGroup,
  activeGroup: activeGroup,
  applyEvent: applyEvent,
  marketForSymbol: marketForSymbol,
  marketPriority: marketPriority,
  filterRows: filterRows,
  rowKeys: rowKeys,
  rowsBySymbol: rowsBySymbol,
  orderedRows: orderedRows,
  rows: rows,
  marketGroups: marketGroups,
  formatPrice: formatPrice,
  formatPercent: formatPercent,
  isStale: isStale
}
