.pragma library

// Request builders and payload parsers for `longbridge serve`, the CLI's
// newline-delimited JSON-RPC 2.0 endpoint. Unlike the `--format json` CLI
// output the results here are the raw Longbridge OpenAPI shapes, which is a
// stable contract, so every field rename lives in this file.

var QUOTE_CHUNK = 200
var SUBSCRIBE_LIMIT = 200

function serveCommand() {
  return ["longbridge", "serve"]
}

function requestLine(id, method, params) {
  var request = { jsonrpc: "2.0", id: Number(id), method: String(method) }
  if (params !== undefined && params !== null) request.params = params
  return JSON.stringify(request) + "\n"
}

function parseMessage(line) {
  var text = String(line || "").replace(/^\s+|\s+$/g, "")
  if (!text) return { kind: "empty" }
  var payload = parseJson(text)
  if (!payload.ok) return { kind: "invalid" }
  var value = payload.value
  if (!value || typeof value !== "object" || isList(value)) return { kind: "invalid" }
  if (value.id !== undefined && value.id !== null) {
    if (value.error) return { kind: "response", id: Number(value.id), error: classifyRpcError(value.error) }
    return { kind: "response", id: Number(value.id), result: value.result }
  }
  if (value.method) return { kind: "notification", method: String(value.method), params: value.params || {} }
  return { kind: "invalid" }
}

// JSON-RPC codes: -32601 unknown method means the installed CLI predates a
// method this plugin needs; -32602 will not succeed on retry; -32000 may.
function classifyRpcError(error) {
  var code = Number(error && error.code)
  var detail = String(error && error.message || "").toLowerCase()
  if (code === -32601) return { code: "cli_outdated", message: "Update Longbridge Terminal to use this plugin." }
  if (detail.indexOf("auth login") >= 0 || detail.indexOf("not authenticated") >= 0 || detail.indexOf("authentication") >= 0)
    return { code: "not_authenticated", message: "Run longbridge auth login in a terminal." }
  return { code: "cli_failed", message: "Longbridge could not load data." }
}

function parseWatchlistGroups(result) {
  if (!isList(result)) return invalid("Longbridge returned invalid watchlist data.")
  var groups = []
  var defaultGroupId = ""
  var allCount = 0
  for (var i = 0; i < result.length; i++) {
    var source = result[i]
    if (!source || typeof source !== "object") return invalid("Longbridge returned invalid watchlist data.")
    // An empty group may arrive without a securities list; that is a group with
    // nothing in it, not a broken payload.
    var rows = source.securities === null || source.securities === undefined ? [] : source.securities
    if (!isList(rows)) return invalid("Longbridge returned invalid watchlist data.")
    var id = String(source.id)
    var name = String(source.name || "")
    if (name.toLowerCase() === "all") {
      allCount++
      defaultGroupId = id
    }
    var securities = []
    for (var j = 0; j < rows.length; j++) {
      var security = rows[j]
      if (!security || typeof security !== "object" || !security.symbol)
        return invalid("Longbridge returned invalid watchlist data.")
      securities.push({
        symbol: String(security.symbol),
        name: String(security.name || ""),
        market: String(security.market || "Unknown"),
        is_pinned: security.is_pinned === true
      })
    }
    groups.push({ id: id, name: name, securities: securities })
  }
  if (allCount !== 1) return invalid("Longbridge watchlist has no unique all group.")
  return { ok: true, groups: groups, defaultGroupId: defaultGroupId }
}

// The watchlist API always returns the holdings group empty — its members are
// the account's own positions. The terminal fills it the same way, joining
// `fetch_holdings` onto the watchlist (longbridge-terminal
// src/tui/systems/watchlist.rs). Positions arrive under `stock_info`, one list
// per account channel.
function parseStockPositions(result) {
  var channels = result && isList(result.list) ? result.list : []
  var seen = {}
  var rows = []
  for (var i = 0; i < channels.length; i++) {
    var positions = channels[i] && isList(channels[i].stock_info) ? channels[i].stock_info : []
    for (var j = 0; j < positions.length; j++) {
      var position = positions[j]
      if (!position || !position.symbol || seen[position.symbol]) continue
      seen[position.symbol] = true
      rows.push({
        symbol: String(position.symbol),
        name: String(position.symbol_name || ""),
        market: String(position.market || "Unknown"),
        is_pinned: false
      })
    }
  }
  return rows
}

function holdingsGroupIndex(groups) {
  var source = isList(groups) ? groups : []
  for (var i = 0; i < source.length; i++) {
    if (String(source[i] && source[i].name || "").toLowerCase() === "holdings") return i
  }
  return -1
}

// `quote.static_info` is the only source for a security's currency; names stay
// with the watchlist payload, which is already localized by the server.
function parseStaticInfo(result) {
  var info = {}
  if (!isList(result)) return info
  for (var i = 0; i < result.length; i++) {
    var source = result[i]
    if (!source || typeof source !== "object" || !source.symbol) continue
    info[String(source.symbol)] = {
      currency: String(source.currency || ""),
      lot_size: Number(source.lot_size || 0)
    }
  }
  return info
}

function parseQuotes(result, info) {
  if (!isList(result)) return invalid("Longbridge returned invalid quote data.")
  var quotes = []
  for (var i = 0; i < result.length; i++) {
    var quote = parseQuote(result[i], info)
    if (!quote) return invalid("Longbridge returned invalid quote data.")
    quotes.push(quote)
  }
  return { ok: true, event: { type: "snapshot", quotes: quotes, errors: [] } }
}

function parseQuote(source, info) {
  if (!source || typeof source !== "object" || !source.symbol) return null
  var symbol = String(source.symbol)
  var meta = (info || {})[symbol] || {}
  var session = newestSession(source)
  var active = session.quote
  return {
    symbol: symbol,
    name: String(meta.name || ""),
    currency: String(meta.currency || ""),
    last: String(active.last_done || source.last_done || "0"),
    prev_close: String(active.prev_close || source.prev_close || "0"),
    open: String(source.open || "0"),
    high: String(active.high || source.high || "0"),
    low: String(active.low || source.low || "0"),
    volume: String(active.volume === undefined ? (source.volume || "0") : active.volume),
    turnover: String(active.turnover || source.turnover || "0"),
    timestamp: epochSeconds(active.timestamp || source.timestamp),
    trade_status: String(source.trade_status || "Unknown"),
    // Which block the displayed price came from — a display label only.
    //
    // Deliberately absent: trade_session. The SDK's SecurityQuote has no such
    // field, and the terminal's update_from_quote leaves it untouched for that
    // reason (longbridge-terminal src/data/stock.rs) — only a push sets it.
    // Emitting one here would re-stamp every row as Intraday on each snapshot,
    // undoing what the pushes established and reshuffling the list.
    price_session: session.name
  }
}

// The raw payload always carries every session block, so the intraday quote
// competes on timestamp with pre/post/overnight instead of losing to a stale
// pre-market block during regular trading.
function newestSession(source) {
  var candidates = [
    { name: "Intraday", quote: source },
    { name: "Pre", quote: source.pre_market_quote },
    { name: "Post", quote: source.post_market_quote },
    { name: "Overnight", quote: source.overnight_quote }
  ]
  var newest = candidates[0]
  var newestTime = epochSeconds(source.timestamp)
  for (var i = 1; i < candidates.length; i++) {
    var quote = candidates[i].quote
    if (!quote || !quote.last_done || !quote.timestamp) continue
    var time = epochSeconds(quote.timestamp)
    if (time > newestTime) {
      newest = candidates[i]
      newestTime = time
    }
  }
  return newest
}

// `quote.updated` pushes carry no prev_close or currency; the model merges each
// push onto the snapshot row, so only the fields present are reported.
function quoteUpdateEvent(params) {
  if (!params || typeof params !== "object" || !params.symbol) return null
  var event = { type: "quote", symbol: String(params.symbol) }
  if (params.last_done !== undefined) event.last = String(params.last_done)
  if (params.open !== undefined) event.open = String(params.open)
  if (params.high !== undefined) event.high = String(params.high)
  if (params.low !== undefined) event.low = String(params.low)
  if (params.volume !== undefined) event.volume = String(params.volume)
  if (params.turnover !== undefined) event.turnover = String(params.turnover)
  if (params.prev_close !== undefined) event.prev_close = String(params.prev_close)
  if (params.trade_status !== undefined) event.trade_status = String(params.trade_status)
  if (params.trade_session !== undefined) {
    event.trade_session = sessionName(params.trade_session)
    event.price_session = event.trade_session
  }
  if (params.timestamp !== undefined) event.timestamp = epochSeconds(params.timestamp)
  return event
}

// Pushes carry a subset of the snapshot fields, so folding one onto the last
// known row keeps name, currency and prev_close alive between snapshots.
function mergeQuote(previous, incoming) {
  var result = {}
  var key
  for (key in previous) result[key] = previous[key]
  for (key in incoming) {
    var value = incoming[key]
    if (value !== "" && value !== null && value !== undefined) result[key] = value
  }
  return result
}

function sessionName(value) {
  var name = String(value || "")
  return name === "Normal" || name === "" ? "Intraday" : name
}

function quoteParams(symbols) {
  return { symbols: symbolList(symbols) }
}

function staticInfoParams(symbols) {
  return { symbols: symbolList(symbols) }
}

function subscribeParams(symbols) {
  return { symbols: symbolList(symbols), sub_types: ["Quote"], is_first_push: true }
}

function unsubscribeParams(symbols) {
  return { symbols: symbolList(symbols), sub_types: ["Quote"] }
}

// One `quote.quote` call is capped upstream, and a subscription is capped by
// account entitlement; both stay bounded here so a large group degrades to
// fewer live symbols rather than a failed request.
function chunkSymbols(symbols, size) {
  var source = symbolList(symbols)
  var limit = Math.max(1, Number(size) || QUOTE_CHUNK)
  var chunks = []
  for (var i = 0; i < source.length; i += limit) chunks.push(source.slice(i, i + limit))
  return chunks
}

function subscribableSymbols(symbols) {
  return symbolList(symbols).slice(0, SUBSCRIBE_LIMIT)
}

function symbolList(symbols) {
  var source = isList(symbols) ? symbols : []
  var seen = {}
  var result = []
  for (var i = 0; i < source.length; i++) {
    var symbol = String(source[i] || "")
    if (!symbol || seen[symbol]) continue
    seen[symbol] = true
    result.push(symbol)
  }
  return result
}

function missingSymbols(symbols, info) {
  var known = info || {}
  var result = []
  var source = symbolList(symbols)
  for (var i = 0; i < source.length; i++) if (!known[source[i]]) result.push(source[i])
  return result
}

function epochSeconds(value) {
  if (typeof value === "number" && isFinite(value)) return value > 1e11 ? Math.floor(value / 1000) : Math.floor(value)
  var parsed = Date.parse(String(value || ""))
  return isFinite(parsed) ? Math.floor(parsed / 1000) : 0
}

function parseJson(text) {
  try { return { ok: true, value: JSON.parse(String(text || "")) } }
  catch (error) { return { ok: false } }
}

function isList(value) {
  return value !== null && value !== undefined
    && typeof value !== "string" && typeof value.length === "number"
}

function invalid(message) { return { ok: false, error: { code: "invalid_data", message: message } } }
