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
      positions: event.positions || []
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

function copy(value) {
  var result = {}
  for (var key in value) result[key] = value[key]
  return result
}
