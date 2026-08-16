.pragma library

function quoteCommand(symbols) {
  var command = ["longbridge", "quote"]
  for (var i = 0; i < symbols.length; i++) command.push(String(symbols[i]))
  command.push("--format", "json")
  return command
}

function portfolioCommand() {
  return ["longbridge", "portfolio", "--format", "json"]
}

function parseQuotes(text) {
  var payload = parseJson(text)
  if (!payload.ok || !Array.isArray(payload.value)) return invalid("Longbridge returned invalid quote data.")
  var quotes = []
  for (var i = 0; i < payload.value.length; i++) {
    var source = payload.value[i]
    if (!source || typeof source !== "object" || !source.symbol) return invalid("Longbridge returned invalid quote data.")
    var session = newestSession(source)
    var active = session ? session.quote : source
    quotes.push({
      symbol: String(source.symbol),
      name: String(source.name || ""),
      currency: String(source.currency || ""),
      last: String(active.last || source.last || "0"),
      prev_close: String(source.prev_close || active.prev_close || "0"),
      open: String(source.open || "0"),
      high: String(active.high || source.high || "0"),
      low: String(active.low || source.low || "0"),
      volume: String(active.volume === undefined ? (source.volume || "0") : active.volume),
      turnover: String(active.turnover || source.turnover || "0"),
      timestamp: session ? Math.floor(Date.parse(active.timestamp) / 1000) : Math.floor(Date.now() / 1000),
      trade_status: String(source.status || "Unknown"),
      trade_session: session ? session.name : "Intraday"
    })
  }
  return { ok: true, event: { type: "snapshot", quotes: quotes } }
}

function newestSession(source) {
  var candidates = [
    { name: "Pre", quote: source.pre_market },
    { name: "Post", quote: source.post_market },
    { name: "Overnight", quote: source.overnight }
  ]
  var newest = null
  var newestTime = -1
  for (var i = 0; i < candidates.length; i++) {
    var quote = candidates[i].quote
    if (!quote || !quote.last || !quote.timestamp) continue
    var time = Date.parse(quote.timestamp)
    if (!isNaN(time) && time > newestTime) {
      newest = candidates[i]
      newestTime = time
    }
  }
  return newest
}

function parsePortfolio(text) {
  var payload = parseJson(text)
  if (!payload.ok || !payload.value || Array.isArray(payload.value) || typeof payload.value !== "object")
    return invalid("Longbridge returned invalid portfolio data.")
  var source = payload.value
  if (!source.overview || !Array.isArray(source.holdings)) return invalid("Longbridge returned invalid portfolio data.")
  var overview = source.overview
  var positions = []
  for (var i = 0; i < source.holdings.length; i++) {
    var holding = source.holdings[i]
    var quantity = number(holding.quantity)
    var last = number(holding.market_price)
    var cost = number(holding.cost_price)
    var previous = number(holding.prev_close)
    positions.push({
      symbol: String(holding.symbol || ""),
      name: String(holding.name || ""),
      currency: String(holding.currency || ""),
      quantity: String(holding.quantity || "0"),
      available_quantity: String(holding.available_quantity || "0"),
      cost_price: String(holding.cost_price || "0"),
      last: String(holding.market_price || "0"),
      prev_close: String(holding.prev_close || "0"),
      market_value: String(holding.market_value || "0"),
      market_value_usd: String(holding.market_value_usd || "0"),
      total_gain: ((last - cost) * quantity).toFixed(2),
      day_gain: ((last - previous) * quantity).toFixed(2)
    })
  }
  return {
    ok: true,
    event: {
      type: "portfolio",
      currency: String(overview.currency || "USD"),
      net_assets: String(overview.total_asset || "0"),
      market_value: String(overview.market_cap || "0"),
      total_cash: String(overview.total_cash || "0"),
      total_gain: String(overview.total_pl || "0"),
      day_gain: String(overview.total_today_pl || "0"),
      positions: positions,
      cash_balances: source.cash_balances || [],
      updated_at: Math.floor(Date.now() / 1000)
    }
  }
}

function classifyFailure(stderrText, exitCode) {
  var detail = String(stderrText || "").toLowerCase()
  if (exitCode === 127 || detail.indexOf("not found") >= 0 || detail.indexOf("failed to start") >= 0)
    return { code: "cli_missing", message: "Install Longbridge Terminal to use this plugin." }
  if (detail.indexOf("auth login") >= 0 || detail.indexOf("not authenticated") >= 0 || detail.indexOf("authentication") >= 0)
    return { code: "not_authenticated", message: "Run longbridge auth login in a terminal." }
  return { code: "cli_failed", message: "Longbridge could not load data." }
}

function parseJson(text) {
  try { return { ok: true, value: JSON.parse(String(text || "")) } }
  catch (error) { return { ok: false } }
}

function invalid(message) { return { ok: false, error: { code: "invalid_data", message: message } } }
function number(value) {
  var parsed = Number(value || 0)
  return isFinite(parsed) ? parsed : 0
}
