const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const source = fs.readFileSync("PortfolioModel.js", "utf8").replace(/^\.pragma library\s*$/m, "")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)

let state = context.initialState()
assert.strictEqual(state.loading, true)
state = context.applyEvent(state, {
  type: "portfolio",
  currency: "USD",
  net_assets: "257638.30",
  market_value: "212518.05",
  total_cash: "45120.25",
  total_gain: "37600.00",
  day_gain: "1080.00",
  updated_at: 1786861000,
  positions: [
    { symbol: "AAPL.US", currency: "USD", market_value: "2321.80", total_gain: "321.80", day_gain: "21.80" }
  ]
})
assert.strictEqual(state.loading, false)
assert.strictEqual(state.currency, "USD")
assert.strictEqual(state.marketValue, "212518.05")
assert.strictEqual(state.positions.length, 1)
assert.strictEqual(context.totalGain(state), 37600)
assert.strictEqual(context.dayGain(state), 1080)

state = context.applyEvent(state, { type: "error", code: "portfolio_failed", message: "Could not load." })
assert.strictEqual(state.error, "Could not load.")

console.log("portfolio model tests passed")
