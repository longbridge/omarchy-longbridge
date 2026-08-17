.pragma library

function initialState() {
  return {
    loading: true,
    error: "",
    marginCall: "0",
    riskLevel: "",
    creditLimit: "0",
    fundMarketValue: "0",
    markets: [],
    currency: "USD",
    netAssets: "0",
    marketValue: "0",
    totalCash: "0",
    totalGainValue: "0",
    dayGainValue: "0",
    updatedAt: 0,
    positions: []
  }
}

function applyEvent(state, event) {
  if (!event || !event.type) return state
  // A different account is behind the session now.
  if (event.type === "reset") return initialState()
  if (event.type === "portfolio") {
    return {
      loading: false,
      error: "",
      marginCall: String(event.margin_call || "0"),
      riskLevel: String(event.risk_level || ""),
      creditLimit: String(event.credit_limit || "0"),
      fundMarketValue: String(event.fund_market_value || "0"),
      markets: normalizeMarkets(event.markets),
      currency: String(event.currency || "USD"),
      netAssets: String(event.net_assets || "0"),
      marketValue: String(event.market_value || "0"),
      totalCash: String(event.total_cash || "0"),
      totalGainValue: String(event.total_gain || "0"),
      dayGainValue: String(event.day_gain || "0"),
      updatedAt: Number(event.updated_at || 0),
      positions: normalizePositions(event.positions)
    }
  }
  // Live prices from the quote feed. Rows recompute in their own currency and
  // the summary re-totals through each row's report factor, so value, day P/L
  // and total P/L move with the market between snapshots. Cash is not affected
  // by a price, so net assets is cash plus the re-totalled market value.
  if (event.type === "quotes") {
    var next = copy(state)
    var incoming = {}
    var quotes = event.quotes && typeof event.quotes.length === "number" ? event.quotes : []
    for (var q = 0; q < quotes.length; q++) {
      var last = number(quotes[q].last)
      if (last > 0) incoming[String(quotes[q].symbol || "")] = last
    }
    var positions = []
    var touched = false
    var source = state.positions || []
    for (var i = 0; i < source.length; i++) {
      var row = source[i]
      var price = incoming[row.symbol]
      if (!price) {
        positions.push(row)
        continue
      }
      touched = true
      positions.push(pricedPosition(row, price))
    }
    if (!touched) return state
    next.positions = positions
    var marketValue = 0
    var dayGain = 0
    var totalGain = 0
    for (var j = 0; j < positions.length; j++) {
      var factor = number(positions[j].report_factor) || 1
      marketValue += number(positions[j].market_value) * factor
      dayGain += number(positions[j].day_gain) * factor
      totalGain += number(positions[j].total_gain) * factor
    }
    next.marketValue = marketValue.toFixed(2)
    next.dayGainValue = dayGain.toFixed(2)
    next.totalGainValue = totalGain.toFixed(2)
    next.netAssets = (number(state.totalCash) + marketValue).toFixed(2)
    return next
  }
  if (event.type === "error") {
    var next = copy(state)
    next.loading = false
    next.error = String(event.message || "Could not load your portfolio.")
    return next
  }
  return state
}

function sumInReportCurrency(state, key) {
  var total = 0
  var rows = state.positions || []
  for (var i = 0; i < rows.length; i++) {
    if (String(rows[i].currency || "") === state.currency) total += Number(rows[i][key] || 0)
  }
  return total
}

function totalGain(state) { return Number(state.totalGainValue || 0) }
function dayGain(state) { return Number(state.dayGainValue || 0) }

// Share of the account by market, in the report currency. Each row is converted
// with the factor its snapshot implied, so an HK position does not enter the bar
// at its HKD face value the way a raw per-market total would.
function allocation(state) {
  var rows = state && state.positions ? state.positions : []
  var byMarket = {}
  var order = []
  for (var i = 0; i < rows.length; i++) {
    var market = marketOf(rows[i].symbol)
    var value = number(rows[i].market_value) * (number(rows[i].report_factor) || 1)
    if (value <= 0) continue
    if (!(market in byMarket)) {
      byMarket[market] = 0
      order.push(market)
    }
    byMarket[market] += value
  }
  var cash = number(state && state.totalCash)
  if (cash > 0) {
    byMarket.CASH = (byMarket.CASH || 0) + cash
    if (order.indexOf("CASH") < 0) order.push("CASH")
  }
  var total = 0
  for (var j = 0; j < order.length; j++) total += byMarket[order[j]]
  if (total <= 0) return []
  var result = []
  for (var k = 0; k < order.length; k++) {
    result.push({ label: order[k], value: byMarket[order[k]].toFixed(2), share: byMarket[order[k]] / total })
  }
  return result
}

function marketOf(symbol) {
  var suffix = String(symbol || "").split(".").pop().toUpperCase()
  if (suffix === "SH" || suffix === "SZ") return "CN"
  return suffix || "OTHER"
}

// Names as the terminal reports them (src/cli/trade.rs risk_level_name).
function riskLevelName(level) {
  var value = Number(level)
  if (value === 0) return "SAFE"
  if (value === 1) return "MEDIUM"
  if (value === 2) return "WARNING"
  if (value === 3) return "DANGER"
  return "—"
}

function normalizeMarkets(values) {
  var source = values && typeof values.length === "number" ? values : []
  var result = []
  for (var i = 0; i < source.length; i++) {
    var row = source[i] || {}
    if (number(row.value) <= 0) continue
    result.push({ market: String(row.market || ""), value: String(row.value || "0") })
  }
  return result
}

// The terminal shows both P/L figures as an amount and a percentage: intraday
// against yesterday's close, floating against what the position cost.
// Short positions carry a negative quantity, so the base is taken absolute:
// the percentage describes the size of the move against what the position is
// worth, and the sign belongs to the P/L itself.
function intradayPercent(row) {
  var base = Math.abs(number(row.prev_close) * number(row.quantity))
  return base > 0 ? (number(row.day_gain) / base) * 100 : 0
}

function floatingPercent(row) {
  var base = Math.abs(number(row.cost_price) * number(row.quantity))
  return base > 0 ? (number(row.total_gain) / base) * 100 : 0
}

function pricedPosition(row, price) {
  var quantity = number(row.quantity)
  var next = copy(row)
  next.last = String(price)
  next.market_value = (price * quantity).toFixed(2)
  next.day_gain = ((price - number(row.prev_close)) * quantity).toFixed(2)
  next.total_gain = ((price - number(row.cost_price)) * quantity).toFixed(2)
  return next
}

function number(value) {
  var parsed = Number(value || 0)
  return isFinite(parsed) ? parsed : 0
}

function normalizePositions(values) {
  var source = values && typeof values.length === "number" ? values : []
  var result = []
  for (var i = 0; i < source.length; i++) {
    var row = source[i] || {}
    result.push({
      symbol: String(row.symbol || ""),
      name: String(row.name || ""),
      currency: String(row.currency || ""),
      quantity: String(row.quantity || "0"),
      available_quantity: String(row.available_quantity || "0"),
      cost_price: String(row.cost_price || "0"),
      last: String(row.last || "0"),
      prev_close: String(row.prev_close || "0"),
      report_factor: String(row.report_factor || "1"),
      market_value: String(row.market_value || "0"),
      total_gain: String(row.total_gain || "0"),
      day_gain: String(row.day_gain || "0")
    })
  }
  return result
}

function copy(value) {
  var result = {}
  for (var key in value) result[key] = value[key]
  return result
}
