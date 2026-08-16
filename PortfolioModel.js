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
