const test = require("node:test")
const assert = require("node:assert/strict")

const Model = require("../Model.js")

test("canonical Longbridge symbols are normalized, deduplicated, and capped", () => {
  const input = [" aapl.us ", "700.hk", "AAPL.US", "000001.sz", "bad", "D05.SG"]
  assert.deepEqual(Model.normalizedSymbols(input, 3), ["AAPL.US", "700.HK", "000001.SZ"])
  assert.equal(Model.symbolIsValid("BRK-B.US"), true)
  assert.equal(Model.symbolIsValid("AAPL"), false)
  assert.equal(Model.symbolIsValid("BAD SYMBOL.US"), false)
})

test("snapshot and quote events reconcile without mutating previous state", () => {
  const original = Model.initialState(["AAPL.US", "700.HK"])
  const snap = Model.applyEvent(original, {
    type: "snapshot",
    quotes: [
      { symbol: "AAPL.US", last: "230.00", prev_close: "225.00", timestamp: 100 },
      { symbol: "700.HK", last: "610.00", prev_close: "600.00", timestamp: 100 }
    ]
  })
  const pushed = Model.applyEvent(snap, {
    type: "quote",
    symbol: "AAPL.US",
    last: "232.18",
    prev_close: "",
    timestamp: 110
  })

  assert.equal(original.quotes["AAPL.US"], undefined)
  assert.equal(snap.quotes["AAPL.US"].last, "230.00")
  assert.equal(pushed.quotes["AAPL.US"].last, "232.18")
  assert.equal(pushed.quotes["AAPL.US"].prev_close, "225.00")
  assert.notEqual(pushed, snap)
  assert.notEqual(pushed.quotes, snap.quotes)
})

test("partial snapshots preserve failed-symbol values and attach row errors", () => {
  let state = Model.initialState(["AAPL.US", "700.HK"])
  state = Model.applyEvent(state, {
    type: "snapshot",
    quotes: [
      { symbol: "AAPL.US", last: "230.00", prev_close: "225.00", timestamp: 100 },
      { symbol: "700.HK", last: "610.00", prev_close: "600.00", timestamp: 100 }
    ],
    errors: []
  })
  const partial = Model.applyEvent(state, {
    type: "snapshot",
    quotes: [{ symbol: "AAPL.US", last: "232.18", timestamp: 110 }],
    errors: [{ symbol: "700.HK", code: "network_error", message: "Quote unavailable." }]
  })

  assert.equal(partial.quotes["700.HK"].last, "610.00")
  assert.equal(Model.rows(partial)[0].ready, true)
  assert.equal(Model.rows(partial)[1].ready, true)
  assert.equal(Model.rows(partial)[1].errorMessage, "Quote unavailable.")
  assert.equal(Model.rows(state)[1].errorMessage, "")
})

test("flat rows preserve configured watchlist order", () => {
  let state = Model.initialState(["D05.SG", "AAPL.US", "700.HK"])
  state = Model.applyEvent(state, {
    type: "snapshot",
    quotes: [{ symbol: "AAPL.US", last: "1", prev_close: "1", timestamp: 100 }],
    errors: []
  })
  assert.deepEqual(Model.rows(state).map(row => row.symbol), ["D05.SG", "AAPL.US", "700.HK"])
})

test("rows are grouped in US, HK, CN, SG order", () => {
  let state = Model.initialState(["D05.SG", "000001.SZ", "700.HK", "AAPL.US"])
  state = Model.applyEvent(state, {
    type: "snapshot",
    quotes: state.symbols.map(symbol => ({ symbol, last: "1", prev_close: "1", timestamp: 100 }))
  })

  assert.deepEqual(
    Model.marketGroups(state).map(group => [group.market, group.rows.map(row => row.symbol)]),
    [
      ["US", ["AAPL.US"]],
      ["HK", ["700.HK"]],
      ["CN", ["000001.SZ"]],
      ["SG", ["D05.SG"]]
    ]
  )
})

test("connection and subscription events produce new operational state", () => {
  const original = Model.initialState(["AAPL.US"])
  const connecting = Model.applyEvent(original, { type: "connection", state: "connecting" })
  const live = Model.applyEvent(connecting, { type: "subscription", symbols: ["AAPL.US"] })

  assert.equal(original.connection, "idle")
  assert.equal(connecting.connection, "connecting")
  assert.equal(live.connection, "live")
  assert.deepEqual(live.subscribed, ["AAPL.US"])
})

test("stale state and decimal formatting are derived from literal timestamps", () => {
  assert.equal(Model.isStale({ timestamp: 100 }, 221001, 120000), true)
  assert.equal(Model.isStale({ timestamp: 100 }, 219000, 120000), false)
  assert.equal(Model.formatPrice("1234.5"), "1,234.50")
  assert.equal(Model.formatPrice("0.123456"), "0.1235")
  assert.equal(Model.formatPercent("1.234"), "+1.23%")
  assert.equal(Model.formatPercent("-1.234"), "−1.23%")
})
