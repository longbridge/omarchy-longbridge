.pragma library

function initialState() {
  return {
    loading: true,
    error: "",
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
  if (event.type === "portfolio") {
    return {
      loading: false,
      error: "",
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
