.pragma library

// The session's time-share line, which is what longbridge.com draws: one point
// per minute from the open. `quote.candlesticks` was the wrong source — sixty
// five-minute bars reach back five hours, so the line began mid-session and
// missed the move from the open.
//
// A minute series is ~390 points and a row's line is 58px wide, so it is
// reduced to at most MAX_POINTS on the way in; the last point is always kept,
// since that is the one the live price replaces.

var MAX_POINTS = 120

function seriesParams(symbol) {
  return { symbol: String(symbol) }
}

// `sessionMinutes` is how long the market's regular session runs. A day in
// progress has fewer points than that, and the line is drawn across that
// fraction of the width — the rest of the axis stays empty until the close,
// the way the time-share chart on longbridge.com does.
function parseSeries(symbol, result, sessionMinutes) {
  if (!isList(result)) return null
  var prices = []
  for (var i = 0; i < result.length; i++) {
    var point = result[i]
    if (!point || typeof point !== "object") continue
    var price = Number(point.price)
    if (!isFinite(price) || price <= 0) continue
    prices.push(price)
  }
  if (prices.length < 2) return null
  var stride = strideFor(prices.length)
  var expected = Number(sessionMinutes) > prices.length ? Number(sessionMinutes) : prices.length
  return withBounds({
    symbol: String(symbol),
    points: downsample(prices, stride),
    slots: Math.max(2, Math.ceil(expected / stride))
  })
}

function strideFor(count) {
  return count <= MAX_POINTS ? 1 : Math.ceil(count / MAX_POINTS)
}

function downsample(prices, stride) {
  if (stride <= 1) return prices
  var result = []
  for (var i = 0; i < prices.length; i += stride) result.push(prices[i])
  if (result[result.length - 1] !== prices[prices.length - 1]) result.push(prices[prices.length - 1])
  return result
}

// The last bar is still forming, so a live price replaces it instead of
// extending the series — the line moves without drifting off its time axis.
function withLive(series, last) {
  var price = Number(last)
  if (!series || !isFinite(price) || price <= 0) return series
  var points = series.points.slice()
  if (points[points.length - 1] === price) return series
  points[points.length - 1] = price
  return withBounds({ symbol: series.symbol, points: points, slots: series.slots })
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
  // The axis is the whole session, so a day still running leaves the tail of
  // the box empty rather than stretching to fill it.
  var slots = Math.max(series.slots || series.points.length, series.points.length)
  var stepX = width / (slots - 1)
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

// `quote.trading_session` reports each market's windows; the regular session is
// the one a time-share chart spans.
function parseSessionMinutes(result) {
  var minutes = {}
  if (!isList(result)) return minutes
  for (var i = 0; i < result.length; i++) {
    var market = result[i] && String(result[i].market || "")
    var windows = result[i] && isList(result[i].trade_sessions) ? result[i].trade_sessions : []
    if (!market) continue
    var total = 0
    for (var j = 0; j < windows.length; j++) {
      if (String(windows[j].trade_session || "") !== "Intraday") continue
      total += minutesBetween(windows[j].begin_time, windows[j].end_time)
    }
    if (total > 0) minutes[market] = total
  }
  return minutes
}

function minutesBetween(begin, end) {
  var from = clockMinutes(begin)
  var to = clockMinutes(end)
  if (from < 0 || to < 0) return 0
  return to > from ? to - from : 0
}

function clockMinutes(value) {
  var parts = String(value || "").split(":")
  if (parts.length < 2) return -1
  var hours = Number(parts[0])
  var mins = Number(parts[1])
  if (!isFinite(hours) || !isFinite(mins)) return -1
  return hours * 60 + mins
}

function marketOf(symbol) {
  var suffix = String(symbol || "").split(".").pop().toUpperCase()
  if (suffix === "SH" || suffix === "SZ") return "CN"
  return suffix
}

function isList(value) {
  return value !== null && value !== undefined
    && typeof value !== "string" && typeof value.length === "number"
}
