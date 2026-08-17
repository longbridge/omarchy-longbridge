.pragma library

// Intraday shape for a row's sparkline. `quote.candlesticks` returns full OHLCV
// bars; a 60px line needs closes and nothing else, so the bars are reduced to a
// plain number series here rather than carried around per row.

var PERIOD = "5m"
var COUNT = 60

function seriesParams(symbol) {
  return { symbol: String(symbol), period: PERIOD, count: COUNT, adjust_type: "NoAdjust" }
}

function parseSeries(symbol, result) {
  if (!isList(result)) return null
  var points = []
  for (var i = 0; i < result.length; i++) {
    var bar = result[i]
    if (!bar || typeof bar !== "object") continue
    var close = Number(bar.close)
    if (!isFinite(close) || close <= 0) continue
    points.push(close)
  }
  if (points.length < 2) return null
  return withBounds({ symbol: String(symbol), points: points })
}

// The last bar is still forming, so a live price replaces it instead of
// extending the series — the line moves without drifting off its time axis.
function withLive(series, last) {
  var price = Number(last)
  if (!series || !isFinite(price) || price <= 0) return series
  var points = series.points.slice()
  if (points[points.length - 1] === price) return series
  points[points.length - 1] = price
  return withBounds({ symbol: series.symbol, points: points })
}

function withBounds(series) {
  var min = series.points[0]
  var max = series.points[0]
  for (var i = 1; i < series.points.length; i++) {
    if (series.points[i] < min) min = series.points[i]
    if (series.points[i] > max) max = series.points[i]
  }
  series.min = min
  series.max = max
  return series
}

// Maps the series into the pixel box the sparkline paints, with a flat series
// drawn down the middle rather than dividing by a zero range.
function plot(series, width, height, baseline) {
  if (!series || !series.points || series.points.length < 2) return []
  var min = series.min
  var max = series.max
  if (isFinite(Number(baseline)) && Number(baseline) > 0) {
    min = Math.min(min, Number(baseline))
    max = Math.max(max, Number(baseline))
  }
  var range = max - min
  var stepX = width / (series.points.length - 1)
  var result = []
  for (var i = 0; i < series.points.length; i++) {
    var ratio = range > 0 ? (series.points[i] - min) / range : 0.5
    result.push({ x: i * stepX, y: height - ratio * height })
  }
  return result
}

function baselineY(series, height, baseline) {
  var value = Number(baseline)
  if (!series || !isFinite(value) || value <= 0) return -1
  var min = Math.min(series.min, value)
  var max = Math.max(series.max, value)
  var range = max - min
  if (range <= 0) return height / 2
  return height - ((value - min) / range) * height
}

function isList(value) {
  return value !== null && value !== undefined
    && typeof value !== "string" && typeof value.length === "number"
}
