.pragma library

// Watchlist and quotes come from `longbridge serve` (see RpcAdapter.js). The
// portfolio stays on the CLI: `serve` exposes the raw OpenAPI calls, but the
// account overview it renders — cross-currency totals, day and total P/L — is
// aggregated by the CLI command and has no JSON-RPC equivalent.
function portfolioCommand() {
  return ["longbridge", "portfolio", "--format", "json"]
}

function parsePortfolio(text) {
  var payload = parseJson(text)
  if (!payload.ok || !payload.value || Array.isArray(payload.value) || typeof payload.value !== "object")
    return invalid("Longbridge returned invalid portfolio data.")
  var source = payload.value
  if (!source.overview || !Array.isArray(source.holdings)) return invalid("Longbridge returned invalid portfolio data.")
  var overview = source.overview
  var positions = []
  // Rows are priced in their own currency while the summary is reported in one.
  // The snapshot carries both market_value and market_value_usd per holding, so
  // the rate implied by that pair — scaled by the account's own USD-to-report
  // ratio — converts a live price change into the report currency without
  // asking for exchange rates the panel would then have to keep fresh.
  var usdTotal = 0
  for (var u = 0; u < source.holdings.length; u++) usdTotal += number(source.holdings[u].market_value_usd)
  var usdToReport = usdTotal > 0 ? number(overview.market_cap) / usdTotal : 1
  for (var i = 0; i < source.holdings.length; i++) {
    var holding = source.holdings[i]
    var quantity = number(holding.quantity)
    var last = number(holding.market_price)
    var cost = number(holding.cost_price)
    var previous = number(holding.prev_close)
    var value = number(holding.market_value)
    var valueUsd = number(holding.market_value_usd)
    var toUsd = value > 0 && valueUsd > 0 ? valueUsd / value : 1
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
      report_factor: String(toUsd * usdToReport),
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
