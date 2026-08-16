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

const manyPositions = Array.from({ length: 12 }, (_, index) => ({
  symbol: `TEST${index}.US`,
  name: `Holding ${index}`,
  currency: "USD",
  quantity: String(index + 1),
  available_quantity: String(index),
  cost_price: "10.25",
  last: "12.50",
  market_value: String((index + 1) * 12.5),
  total_gain: "2.25",
  day_gain: index % 2 === 0 ? "0.50" : "-0.25"
}))
manyPositions[4].quantity = 5
manyPositions[4].market_value = 62.5
const denseState = context.applyEvent(context.initialState(), {
  type: "portfolio",
  currency: "USD",
  positions: manyPositions
})
manyPositions[4].name = "Mutated after apply"
assert.strictEqual(denseState.positions.length, 12)
assert.deepStrictEqual(
  JSON.parse(JSON.stringify(denseState.positions[4])),
  {
    symbol: "TEST4.US",
    name: "Holding 4",
    currency: "USD",
    quantity: "5",
    available_quantity: "4",
    cost_price: "10.25",
    last: "12.50",
    market_value: "62.5",
    total_gain: "2.25",
    day_gain: "0.50"
  }
)

state = context.applyEvent(state, { type: "error", code: "portfolio_failed", message: "Could not load." })
assert.strictEqual(state.error, "Could not load.")

console.log("portfolio model tests passed")
