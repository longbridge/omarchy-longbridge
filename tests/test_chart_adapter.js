const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const source = fs.readFileSync("ChartAdapter.js", "utf8").replace(/^\.pragma library\s*$/m, "")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)
const plain = value => JSON.parse(JSON.stringify(value))

assert.deepStrictEqual(plain(context.seriesParams("AAPL.US")), { symbol: "AAPL.US" })

// The session's minute line, as `quote.intraday` returns it.
const bars = [
  { price: "100.0", timestamp: "2026-08-17T13:30:00Z", volume: 10, turnover: "1000", avg_price: "100.0" },
  { price: "104.0", timestamp: "2026-08-17T13:31:00Z", volume: 12, turnover: "1248", avg_price: "102.0" },
  { price: "102.0", timestamp: "2026-08-17T13:32:00Z", volume: 8, turnover: "816", avg_price: "102.0" }
]
const series = context.parseSeries("AAPL.US", bars)
assert.strictEqual(series.symbol, "AAPL.US")
assert.deepStrictEqual(plain(series.points), [100, 104, 102])
assert.strictEqual(series.min, 100)
assert.strictEqual(series.max, 104)

// Bars without a usable close are skipped; too few points is no chart at all.
assert.deepStrictEqual(plain(context.parseSeries("X.US", [{ price: "1" }, { price: "0" }, { price: "3" }]).points), [1, 3])
assert.strictEqual(context.parseSeries("X.US", [{ price: "1" }]), null)
assert.strictEqual(context.parseSeries("X.US", []), null)
assert.strictEqual(context.parseSeries("X.US", null), null)

// A live price replaces the forming bar rather than lengthening the series.
const advanced = context.withLive(series, "108.0")
assert.deepStrictEqual(plain(advanced.points), [100, 104, 108])
assert.strictEqual(advanced.max, 108)
assert.deepStrictEqual(plain(series.points), [100, 104, 102])
// An unchanged or unusable price returns the same object, so nothing repaints.
assert.strictEqual(context.withLive(advanced, "108.0"), advanced)
assert.strictEqual(context.withLive(advanced, "0"), advanced)
assert.strictEqual(context.withLive(advanced, "nope"), advanced)

// Plotting maps the series into the pixel box, y inverted for the canvas.
const points = plain(context.plot(series, 60, 20, 0))
assert.strictEqual(points.length, 3)
assert.strictEqual(points[0].x, 0)
assert.strictEqual(points[2].x, 60)
assert.strictEqual(points[0].y, 20) // lowest close sits on the floor
assert.strictEqual(points[1].y, 0)  // highest close on the ceiling

// The previous close widens the range so the baseline is always in frame.
const withBaseline = plain(context.plot(series, 60, 20, 96))
assert.ok(withBaseline[0].y < 20)
assert.strictEqual(Math.round(context.baselineY(series, 20, 96)), 20)
assert.strictEqual(context.baselineY(series, 20, 0), -1)

// A flat series draws down the middle instead of dividing by a zero range.
const flat = context.parseSeries("X.US", [{ price: "5" }, { price: "5" }])
assert.deepStrictEqual(plain(context.plot(flat, 10, 20, 0)).map(point => point.y), [10, 10])
assert.strictEqual(context.baselineY(flat, 20, 5), 10)

assert.deepStrictEqual(plain(context.plot(null, 60, 20, 0)), [])

// A full session is ~390 minutes; it is reduced for the row without losing the
// ends, because the last point is the one the live price replaces.
{
  const minutes = []
  for (let i = 0; i < 390; i++) minutes.push({ price: String(100 + i) })
  const session = context.parseSeries("AAPL.US", minutes)
  assert.ok(session.points.length <= 120)
  assert.ok(session.points.length >= 90)
  assert.strictEqual(session.points[0], 100)
  assert.strictEqual(session.points[session.points.length - 1], 489)
  assert.strictEqual(session.min, 100)
  assert.strictEqual(session.max, 489)
}

// The axis is the market's whole session: a day still running fills only the
// fraction of the width it has actually elapsed.
{
  const sessions = [{
    market: "US",
    trade_sessions: [
      { begin_time: "04:00:00.0", end_time: "09:30:00.0", trade_session: "Pre" },
      { begin_time: "09:30:00.0", end_time: "16:00:00.0", trade_session: "Intraday" },
      { begin_time: "16:00:00.0", end_time: "20:00:00.0", trade_session: "Post" }
    ]
  }, {
    market: "HK",
    trade_sessions: [
      { begin_time: "09:30:00.0", end_time: "12:00:00.0", trade_session: "Intraday" },
      { begin_time: "13:00:00.0", end_time: "16:00:00.0", trade_session: "Intraday" }
    ]
  }]
  const minutes = context.parseSessionMinutes(sessions)
  assert.strictEqual(minutes.US, 390)
  assert.strictEqual(minutes.HK, 330)
  assert.deepStrictEqual(plain(context.parseSessionMinutes(null)), {})

  assert.strictEqual(context.marketOf("TSLA.US"), "US")
  assert.strictEqual(context.marketOf("600519.SH"), "CN")
  assert.strictEqual(context.marketOf("000568.SZ"), "CN")

  // Two hours into a US session: the line covers under a third of the box.
  const partial = []
  for (let i = 0; i < 120; i++) partial.push({ price: String(100 + i) })
  const running = context.parseSeries("TSLA.US", partial, 390)
  assert.strictEqual(running.points.length, 120)
  assert.strictEqual(running.slots, 390)
  const drawn = plain(context.plot(running, 300, 20, 0))
  assert.strictEqual(Math.round(drawn[drawn.length - 1].x), 92)

  // A finished session fills the width.
  const full = []
  for (let i = 0; i < 390; i++) full.push({ price: String(100 + i) })
  const closed = context.parseSeries("TSLA.US", full, 390)
  const filled = plain(context.plot(closed, 300, 20, 0))
  assert.strictEqual(Math.round(filled[filled.length - 1].x), 300)

  // A live price still lands on the last point, keeping the axis intact.
  const advancedRunning = context.withLive(running, "500")
  assert.strictEqual(advancedRunning.slots, 390)
}

console.log("chart adapter tests passed")
