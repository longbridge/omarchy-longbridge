const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const load = file => {
  const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "")
  const context = {}
  vm.createContext(context)
  vm.runInContext(source, context)
  return context
}

const cache = load("CacheAdapter.js")
const rpc = load("RpcAdapter.js")
const plain = value => JSON.parse(JSON.stringify(value))

const state = {
  savedAt: 1755417600,
  defaultGroupId: "2630",
  activeGroupId: "3001",
  groups: [
    {
      id: "2630",
      name: "all",
      securities: [
        { symbol: "AAPL.US", name: "Apple", market: "US", is_pinned: true },
        { symbol: "700.HK", name: "TENCENT", market: "HK", is_pinned: false }
      ]
    },
    { id: "3001", name: "us", securities: [{ symbol: "AAPL.US", name: "Apple", market: "US", is_pinned: false }] }
  ],
  staticInfo: {
    "AAPL.US": { currency: "USD", lot_size: 1 },
    "700.HK": { currency: "HKD", lot_size: 100 },
    "GONE.US": { currency: "USD", lot_size: 1 }
  },
  quotes: {
    "AAPL.US": { symbol: "AAPL.US", last: "233.900", prev_close: "233.010", currency: "USD", trade_session: "Overnight" },
    "700.HK": { symbol: "700.HK", last: "448.400", prev_close: "444.800", currency: "HKD", trade_session: "Intraday" },
    // No longer in any group: must not be written back.
    "GONE.US": { symbol: "GONE.US", last: "1.000" }
  }
}

const restored = cache.deserialize(cache.serialize(state))
assert.strictEqual(restored.ok, true)
assert.strictEqual(restored.cache.savedAt, 1755417600)
assert.strictEqual(restored.cache.defaultGroupId, "2630")
assert.strictEqual(restored.cache.activeGroupId, "3001")
assert.deepStrictEqual(plain(restored.cache.groups.map(group => group.name)), ["all", "us"])
assert.strictEqual(restored.cache.groups[0].securities[0].is_pinned, true)
assert.strictEqual(restored.cache.groups[0].securities[1].symbol, "700.HK")

// Quotes round-trip as rows the panel can replay directly as a snapshot.
const quotes = plain(restored.cache.quotes)
assert.deepStrictEqual(quotes.map(quote => quote.symbol), ["AAPL.US", "700.HK"])
assert.strictEqual(quotes[0].last, "233.900")
assert.strictEqual(quotes[0].currency, "USD")

// Symbols that left every group are pruned from both maps.
assert.strictEqual(quotes.some(quote => quote.symbol === "GONE.US"), false)
assert.strictEqual("GONE.US" in plain(restored.cache.staticInfo), false)
assert.strictEqual(plain(restored.cache.staticInfo)["700.HK"].lot_size, 100)

// A cache that cannot be trusted is simply skipped: the panel loads live.
assert.strictEqual(cache.deserialize("").ok, false)
assert.strictEqual(cache.deserialize("not json").ok, false)
assert.strictEqual(cache.deserialize("[]").ok, false)
assert.strictEqual(cache.deserialize('{"version":99,"groups":[{"id":"1","securities":[]}]}').ok, false)
assert.strictEqual(cache.deserialize('{"version":1,"groups":[]}').ok, false)

// Groups with nothing in them survive; a cache is not required to hold quotes.
const empty = cache.deserialize(cache.serialize({
  groups: [{ id: "-6", name: "holdings", securities: [] }],
  defaultGroupId: "-6"
}))
assert.strictEqual(empty.ok, true)
assert.deepStrictEqual(plain(empty.cache.quotes), [])

// Serializing accepts the live quote map or a plain list of rows.
const fromList = cache.deserialize(cache.serialize({
  groups: state.groups,
  defaultGroupId: "2630",
  quotes: [{ symbol: "AAPL.US", last: "1.000" }]
}))
assert.strictEqual(plain(fromList.cache.quotes).length, 1)

const large = { id: "1", name: "all", securities: [] }
for (let i = 0; i < 620; i++) large.securities.push({ symbol: `S${i}.US`, name: `S${i}` })
const capped = cache.deserialize(cache.serialize({ groups: [large], defaultGroupId: "1" }))
assert.strictEqual(capped.cache.groups[0].securities.length, 500)

// A push folded onto a cached row keeps the fields the push omits.
const merged = rpc.mergeQuote(
  { symbol: "AAPL.US", name: "Apple", currency: "USD", prev_close: "233.010", last: "233.900" },
  { symbol: "AAPL.US", last: "234.500", trade_session: "Overnight", prev_close: undefined }
)
assert.strictEqual(merged.last, "234.500")
assert.strictEqual(merged.prev_close, "233.010")
assert.strictEqual(merged.currency, "USD")
assert.strictEqual(merged.trade_session, "Overnight")

console.log("cache adapter tests passed")
