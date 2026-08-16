const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const source = fs.readFileSync("QuoteAdapter.js", "utf8").replace(/^\.pragma library\s*$/m, "")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)

assert.deepStrictEqual(Array.from(context.helperCommand("/plugin/longbridge-quotes", ["AAPL.US", "700.HK"])), [
  "/plugin/longbridge-quotes", "AAPL.US", "700.HK"
])

const parsed = context.parse(JSON.stringify({
  state: "partial",
  fetched_at_ms: 1000,
  quotes: [{
    symbol: "AAPL.US", name: "Apple Inc.", currency: "USD", last: "232.18",
    prev_close: "230.0", open: "231.05", high: "233.2", low: "229.9",
    volume: "123", timestamp: 1786861000, trade_status: "REGULAR", trade_session: "Intraday"
  }],
  errors: [{ symbol: "700.HK", code: "network_error", message: "Quote unavailable." }]
}))
assert.strictEqual(parsed.ok, true)
assert.strictEqual(parsed.state, "partial")
assert.strictEqual(parsed.fetchedAtMs, 1000)
assert.strictEqual(parsed.event.type, "snapshot")
assert.strictEqual(parsed.event.quotes[0].symbol, "AAPL.US")
assert.strictEqual(parsed.event.quotes[0].last, "232.18")
assert.strictEqual(parsed.errors[0].symbol, "700.HK")

assert.strictEqual(context.parse("{}").ok, false)
assert.strictEqual(context.parse('{"state":"ready","quotes":{}}').ok, false)
assert.strictEqual(context.parse('{"state":"bogus","quotes":[],"errors":[]}').ok, false)

console.log("quote adapter tests passed")
