.pragma library

// Last-known watchlist state, persisted so a shell restart paints rows
// immediately instead of waiting out a cold `longbridge serve` start. Only
// watchlist membership and quotes are stored — never account or portfolio
// data, and never anything from the OAuth files the CLI owns.

var VERSION = 1
var MAX_SYMBOLS = 500

function serialize(input) {
  var source = input || {}
  var groups = groupsPayload(source.groups)
  var kept = symbolsInGroups(groups)
  return JSON.stringify({
    version: VERSION,
    saved_at: Number(source.savedAt) || 0,
    default_group_id: String(source.defaultGroupId || ""),
    active_group_id: String(source.activeGroupId || ""),
    groups: groups,
    static_info: staticInfoPayload(source.staticInfo, kept),
    quotes: quotesPayload(source.quotes, kept)
  })
}

function deserialize(text) {
  var payload = parseJson(text)
  if (!payload.ok) return { ok: false }
  var value = payload.value
  if (!value || typeof value !== "object" || isList(value)) return { ok: false }
  if (Number(value.version) !== VERSION) return { ok: false }
  var groups = groupsPayload(value.groups)
  if (groups.length === 0) return { ok: false }
  var kept = symbolsInGroups(groups)
  return {
    ok: true,
    cache: {
      savedAt: Number(value.saved_at) || 0,
      defaultGroupId: String(value.default_group_id || ""),
      activeGroupId: String(value.active_group_id || ""),
      groups: groups,
      staticInfo: staticInfoPayload(value.static_info, kept),
      quotes: quotesPayload(value.quotes, kept)
    }
  }
}

function groupsPayload(groups) {
  var source = isList(groups) ? groups : []
  var result = []
  for (var i = 0; i < source.length; i++) {
    var group = source[i]
    if (!group || typeof group !== "object" || group.id === undefined || group.id === null) continue
    var rows = isList(group.securities) ? group.securities : []
    var securities = []
    for (var j = 0; j < rows.length && securities.length < MAX_SYMBOLS; j++) {
      var security = rows[j]
      if (!security || typeof security !== "object" || !security.symbol) continue
      securities.push({
        symbol: String(security.symbol),
        name: String(security.name || ""),
        market: String(security.market || "Unknown"),
        is_pinned: security.is_pinned === true
      })
    }
    result.push({ id: String(group.id), name: String(group.name || ""), securities: securities })
  }
  return result
}

// Quotes and static info are pruned to what the cached groups can display, so
// symbols dropped from the watchlist do not accumulate on disk forever.
function symbolsInGroups(groups) {
  var kept = {}
  for (var i = 0; i < groups.length; i++) {
    var securities = groups[i].securities
    for (var j = 0; j < securities.length; j++) kept[securities[j].symbol] = true
  }
  return kept
}

function quotesPayload(quotes, kept) {
  var result = []
  var source = isList(quotes) ? quotes : quotesFromMap(quotes)
  for (var i = 0; i < source.length && result.length < MAX_SYMBOLS; i++) {
    var quote = source[i]
    if (!quote || typeof quote !== "object" || !quote.symbol) continue
    if (!kept[String(quote.symbol)]) continue
    result.push(quote)
  }
  return result
}

function quotesFromMap(quotes) {
  var result = []
  if (!quotes || typeof quotes !== "object") return result
  for (var symbol in quotes) if (quotes[symbol]) result.push(quotes[symbol])
  return result
}

function staticInfoPayload(info, kept) {
  var result = {}
  if (!info || typeof info !== "object") return result
  for (var symbol in info) {
    if (!kept[symbol] || !info[symbol]) continue
    var row = info[symbol]
    result[symbol] = {
      currency: String(row.currency || ""),
      lot_size: Number(row.lot_size || 0),
      eps_ttm: String(row.eps_ttm || ""),
      bps: String(row.bps || ""),
      dividend_yield: String(row.dividend_yield || ""),
      total_shares: String(row.total_shares || ""),
      circulating_shares: String(row.circulating_shares || ""),
      exchange: String(row.exchange || "")
    }
  }
  return result
}

function parseJson(text) {
  try { return { ok: true, value: JSON.parse(String(text || "")) } }
  catch (error) { return { ok: false } }
}

function isList(value) {
  return value !== null && value !== undefined
    && typeof value !== "string" && typeof value.length === "number"
}
