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
    prev_close: "0",
    report_factor: "1",
    market_value: "62.5",
    total_gain: "2.25",
    day_gain: "0.50"
  }
)

// Live prices from the feed re-price rows and re-total the summary, so the
// portfolio moves between snapshots without another CLI call.
{
  let live = context.applyEvent(context.initialState(), {
    type: "portfolio",
    currency: "USD",
    net_assets: "1010.00",
    market_value: "1000.00",
    total_cash: "10.00",
    total_gain: "100.00",
    day_gain: "20.00",
    positions: [
      {
        symbol: "AAPL.US", name: "Apple", currency: "USD", quantity: "10",
        cost_price: "90.00", prev_close: "98.00", last: "100.00",
        market_value: "1000.00", report_factor: "1"
      },
      {
        symbol: "700.HK", name: "TENCENT", currency: "HKD", quantity: "100",
        cost_price: "400.00", prev_close: "440.00", last: "450.00",
        market_value: "45000.00", report_factor: "0.128"
      }
    ]
  })

  const unchanged = context.applyEvent(live, { type: "quotes", quotes: [{ symbol: "MSFT.US", last: "500" }] })
  assert.strictEqual(unchanged, live)

  live = context.applyEvent(live, {
    type: "quotes",
    quotes: [{ symbol: "AAPL.US", last: "110.00" }, { symbol: "700.HK", last: "460.00" }]
  })

  const apple = live.positions[0]
  assert.strictEqual(apple.last, "110")
  assert.strictEqual(apple.market_value, "1100.00")
  assert.strictEqual(apple.day_gain, "120.00")
  assert.strictEqual(apple.total_gain, "200.00")

  // Report-currency totals fold each row through its own factor.
  assert.strictEqual(live.marketValue, (1100 + 46000 * 0.128).toFixed(2))
  assert.strictEqual(live.dayGainValue, (120 + 2000 * 0.128).toFixed(2))
  assert.strictEqual(live.totalGainValue, (200 + 6000 * 0.128).toFixed(2))
  assert.strictEqual(live.netAssets, (10 + 1100 + 46000 * 0.128).toFixed(2))

  // A push with no usable price leaves the row alone.
  const zeroed = context.applyEvent(live, { type: "quotes", quotes: [{ symbol: "AAPL.US", last: "0" }] })
  assert.strictEqual(zeroed, live)
}

state = context.applyEvent(state, { type: "error", code: "portfolio_failed", message: "Could not load." })
assert.strictEqual(state.error, "Could not load.")

console.log("portfolio model tests passed")
