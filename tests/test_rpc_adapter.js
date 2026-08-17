const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const source = fs.readFileSync("RpcAdapter.js", "utf8").replace(/^\.pragma library\s*$/m, "")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)

const fixture = name => JSON.parse(fs.readFileSync(`tests/fixtures/${name}`, "utf8"))
// Values cross the vm realm boundary, so compare structure rather than identity.
const plain = value => JSON.parse(JSON.stringify(value))

assert.deepStrictEqual(Array.from(context.serveCommand()), ["longbridge", "serve"])
assert.strictEqual(
  context.requestLine(7, "quote.quote", { symbols: ["AAPL.US"] }),
  '{"jsonrpc":"2.0","id":7,"method":"quote.quote","params":{"symbols":["AAPL.US"]}}\n'
)
assert.strictEqual(context.requestLine(1, "initialize", null), '{"jsonrpc":"2.0","id":1,"method":"initialize"}\n')

// Framing: responses correlate by id, notifications carry no id.
const response = context.parseMessage('{"jsonrpc":"2.0","id":3,"result":[{"symbol":"AAPL.US"}]}')
assert.strictEqual(response.kind, "response")
assert.strictEqual(response.id, 3)
assert.strictEqual(response.result[0].symbol, "AAPL.US")

const notification = context.parseMessage('{"jsonrpc":"2.0","method":"quote.updated","params":{"symbol":"AAPL.US"}}')
assert.strictEqual(notification.kind, "notification")
assert.strictEqual(notification.method, "quote.updated")

assert.strictEqual(context.parseMessage("not json").kind, "invalid")
assert.strictEqual(context.parseMessage("   ").kind, "empty")
assert.strictEqual(context.parseMessage("[1,2]").kind, "invalid")

const unknownMethod = context.parseMessage('{"jsonrpc":"2.0","id":4,"error":{"code":-32601,"message":"unknown method"}}')
assert.strictEqual(unknownMethod.error.code, "cli_outdated")
const badParams = context.parseMessage('{"jsonrpc":"2.0","id":5,"error":{"code":-32602,"message":"`symbols` must not be empty"}}')
assert.strictEqual(badParams.error.code, "cli_failed")
const authFailure = context.parseMessage('{"jsonrpc":"2.0","id":6,"error":{"code":-32000,"message":"run longbridge auth login"}}')
assert.strictEqual(authFailure.error.code, "not_authenticated")
// Upstream detail never reaches the panel.
assert.strictEqual(
  context.classifyRpcError({ code: -32000, message: "request failed with access_token=secret" }).message,
  "Longbridge could not load data."
)

const watchlist = context.parseWatchlistGroups(fixture("rpc_watchlist.json"))
assert.strictEqual(watchlist.ok, true)
assert.strictEqual(watchlist.defaultGroupId, "2630")
assert.deepStrictEqual(Array.from(watchlist.groups, group => group.name), ["all", "holdings", "us"])
assert.strictEqual(watchlist.groups[0].securities[0].symbol, "AAPL.US")
assert.strictEqual(watchlist.groups[0].securities[0].is_pinned, true)
assert.strictEqual(watchlist.groups[0].securities[1].market, "HK")
assert.strictEqual(watchlist.groups[1].securities.length, 0)
// A group without a securities list is empty, not a broken payload.
assert.strictEqual(watchlist.groups[2].securities.length, 0)

assert.strictEqual(context.parseWatchlistGroups([]).ok, false)
assert.strictEqual(context.parseWatchlistGroups("nope").ok, false)
assert.strictEqual(
  context.parseWatchlistGroups([{ id: 1, name: "all", securities: [] }, { id: 2, name: "ALL", securities: [] }]).ok,
  false
)

const info = context.parseStaticInfo(fixture("rpc_static_info.json"))
assert.strictEqual(info["AAPL.US"].currency, "USD")
assert.strictEqual(info["700.HK"].lot_size, 100)
assert.deepStrictEqual(plain(context.parseStaticInfo(null)), {})

const quotes = context.parseQuotes(fixture("rpc_quote.json"), info)
assert.strictEqual(quotes.ok, true)
assert.strictEqual(quotes.event.type, "snapshot")
// Every session block is always present, so the newest timestamp wins.
const apple = quotes.event.quotes[0]
assert.strictEqual(apple.symbol, "AAPL.US")
// The freshest block prices the row…
assert.strictEqual(apple.price_session, "Overnight")
// …but a snapshot never claims a session of its own: only a push sets that,
// so a later snapshot cannot undo it and reshuffle the list.
assert.ok(!("trade_session" in apple))
assert.strictEqual(apple.last, "233.900")
assert.strictEqual(apple.prev_close, "233.010")
assert.strictEqual(apple.open, "232.500")
assert.strictEqual(apple.currency, "USD")
assert.strictEqual(apple.volume, "59393")
assert.strictEqual(apple.timestamp, Math.floor(Date.parse("2026-08-17T07:33:52Z") / 1000))
// Without session blocks the intraday quote is reported as-is.
const tencent = quotes.event.quotes[1]
assert.ok(!("trade_session" in tencent))
assert.strictEqual(tencent.price_session, "Intraday")
assert.strictEqual(tencent.last, "448.400")
assert.strictEqual(tencent.currency, "HKD")
assert.strictEqual(tencent.trade_status, "Normal")

// A stale pre-market block must not displace the running intraday session.
const regularHours = context.parseQuotes([{
  symbol: "AAPL.US",
  last_done: "240.000",
  prev_close: "232.100",
  open: "233.000",
  high: "241.000",
  low: "232.800",
  timestamp: "2026-08-17T17:00:00Z",
  volume: 4000000,
  turnover: "960000000.000",
  trade_status: "Normal",
  pre_market_quote: {
    last_done: "232.800",
    timestamp: "2026-08-17T13:20:00Z",
    volume: 1000,
    turnover: "232800.000",
    high: "233.000",
    low: "232.500",
    prev_close: "232.100"
  }
}], info)
assert.strictEqual(regularHours.event.quotes[0].price_session, "Intraday")
assert.strictEqual(regularHours.event.quotes[0].last, "240.000")

assert.strictEqual(context.parseQuotes(null, info).ok, false)
assert.strictEqual(context.parseQuotes([{ last_done: "1" }], info).ok, false)

// Pushes carry no prev_close or currency; only the fields present are reported
// so the model keeps the rest of the snapshot row.
const push = context.quoteUpdateEvent({
  symbol: "AAPL.US",
  last_done: "234.100",
  open: "233.000",
  high: "234.400",
  low: "232.900",
  timestamp: "2026-08-17T07:36:17Z",
  volume: 389026,
  turnover: "91000000.000",
  trade_status: "Normal",
  trade_session: "Overnight",
  current_volume: 80,
  current_turnover: "18098.400"
})
assert.strictEqual(push.type, "quote")
assert.strictEqual(push.last, "234.100")
assert.strictEqual(push.trade_session, "Overnight")
assert.strictEqual(push.price_session, "Overnight")
assert.strictEqual(push.timestamp, Math.floor(Date.parse("2026-08-17T07:36:17Z") / 1000))
assert.ok(!("prev_close" in push))
assert.ok(!("currency" in push))
assert.strictEqual(context.quoteUpdateEvent({ symbol: "AAPL.US", trade_session: "Normal" }).trade_session, "Intraday")
assert.strictEqual(context.quoteUpdateEvent({}), null)

assert.deepStrictEqual(plain(context.subscribeParams(["AAPL.US", "AAPL.US", "700.HK"])), {
  symbols: ["AAPL.US", "700.HK"],
  sub_types: ["Quote"],
  is_first_push: true
})
assert.deepStrictEqual(plain(context.unsubscribeParams(["AAPL.US"])), { symbols: ["AAPL.US"], sub_types: ["Quote"] })
assert.deepStrictEqual(plain(context.quoteParams(["AAPL.US"])), { symbols: ["AAPL.US"] })
assert.deepStrictEqual(plain(context.staticInfoParams(null)), { symbols: [] })

assert.deepStrictEqual(plain(context.chunkSymbols(["A.US", "B.US", "C.US"], 2)), [["A.US", "B.US"], ["C.US"]])
assert.deepStrictEqual(plain(context.chunkSymbols([], 2)), [])
const large = []
for (let i = 0; i < 260; i++) large.push(`S${i}.US`)
assert.strictEqual(context.chunkSymbols(large).length, 2)
assert.strictEqual(context.subscribableSymbols(large).length, 200)

assert.deepStrictEqual(plain(context.missingSymbols(["AAPL.US", "MSFT.US"], info)), ["MSFT.US"])
assert.deepStrictEqual(plain(context.missingSymbols(["AAPL.US"], info)), [])

console.log("RPC adapter tests passed")

// The holdings group is filled from account positions, which arrive under
// `stock_info`, one list per account channel (see the terminal's fetch_holdings).
{
  const positions = context.parseStockPositions({
    list: [
      {
        account_channel: "lb",
        stock_info: [
          { symbol: "TSM.US", symbol_name: "Taiwan Semiconductor", market: "US", quantity: "9.2328" },
          { symbol: "TSLA.US", symbol_name: "Tesla", market: "US", quantity: "67" }
        ]
      },
      { account_channel: "other", stock_info: [{ symbol: "TSM.US", symbol_name: "Taiwan Semiconductor", market: "US" }] }
    ]
  })
  assert.deepStrictEqual(plain(positions), [
    { symbol: "TSM.US", name: "Taiwan Semiconductor", market: "US", is_pinned: false },
    { symbol: "TSLA.US", name: "Tesla", market: "US", is_pinned: false }
  ])
  assert.deepStrictEqual(plain(context.parseStockPositions({ list: [{ stock_info: null }] })), [])
  assert.deepStrictEqual(plain(context.parseStockPositions(null)), [])

  assert.strictEqual(context.holdingsGroupIndex([{ name: "all" }, { name: "Holdings" }]), 1)
  assert.strictEqual(context.holdingsGroupIndex([{ name: "all" }]), -1)
  assert.strictEqual(context.holdingsGroupIndex(null), -1)
}

console.log("holdings group tests passed")
