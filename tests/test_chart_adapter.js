const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const source = fs.readFileSync("ChartAdapter.js", "utf8").replace(/^\.pragma library\s*$/m, "")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)
const plain = value => JSON.parse(JSON.stringify(value))

assert.deepStrictEqual(plain(context.seriesParams("AAPL.US")), {
  symbol: "AAPL.US",
  period: "5m",
  count: 60,
  adjust_type: "NoAdjust"
})

const bars = [
  { close: "100.0", open: "99", high: "101", low: "98", volume: 10, timestamp: "2026-08-17T13:30:00Z" },
  { close: "104.0", open: "100", high: "105", low: "100", volume: 12, timestamp: "2026-08-17T13:35:00Z" },
  { close: "102.0", open: "104", high: "104", low: "101", volume: 8, timestamp: "2026-08-17T13:40:00Z" }
]
const series = context.parseSeries("AAPL.US", bars)
assert.strictEqual(series.symbol, "AAPL.US")
assert.deepStrictEqual(plain(series.points), [100, 104, 102])
assert.strictEqual(series.min, 100)
assert.strictEqual(series.max, 104)

// Bars without a usable close are skipped; too few points is no chart at all.
assert.deepStrictEqual(plain(context.parseSeries("X.US", [{ close: "1" }, { close: "0" }, { close: "3" }]).points), [1, 3])
assert.strictEqual(context.parseSeries("X.US", [{ close: "1" }]), null)
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
const flat = context.parseSeries("X.US", [{ close: "5" }, { close: "5" }])
assert.deepStrictEqual(plain(context.plot(flat, 10, 20, 0)).map(point => point.y), [10, 10])
assert.strictEqual(context.baselineY(flat, 20, 5), 10)

assert.deepStrictEqual(plain(context.plot(null, 60, 20, 0)), [])

console.log("chart adapter tests passed")
