import QtQuick
import "../ChartAdapter.js" as ChartAdapter

// Intraday line for one security. Rise and fall colours are the row's own, so
// the chart reads the same way the percentage next to it does; the dashed rule
// is the previous close, which is what that percentage is measured against.
Canvas {
  id: root

  property var series: null
  property real previousClose: 0
  property color lineColor: "#63d297"
  property color guideColor: "#808080"
  readonly property bool hasSeries: series && series.points && series.points.length > 1

  opacity: hasSeries ? 1 : 0
  antialiasing: true

  onSeriesChanged: requestPaint()
  onPreviousCloseChanged: requestPaint()
  onLineColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var context = getContext("2d")
    context.reset()
    if (!hasSeries) return

    var inset = 1.5
    var plotHeight = Math.max(1, height - inset * 2)
    var points = ChartAdapter.plot(series, width, plotHeight, previousClose)
    if (points.length < 2) return

    var zero = ChartAdapter.baselineY(series, plotHeight, previousClose)
    if (zero >= 0) {
      context.beginPath()
      context.setLineDash([2, 3])
      context.lineWidth = 1
      context.strokeStyle = Qt.rgba(guideColor.r, guideColor.g, guideColor.b, 0.45)
      context.moveTo(0, zero + inset)
      context.lineTo(width, zero + inset)
      context.stroke()
      context.setLineDash([])
    }

    context.beginPath()
    context.moveTo(points[0].x, points[0].y + inset)
    for (var i = 1; i < points.length; i++) context.lineTo(points[i].x, points[i].y + inset)

    // Fill first so the line stays crisp on top of it.
    context.save()
    context.lineTo(points[points.length - 1].x, height)
    context.lineTo(points[0].x, height)
    context.closePath()
    context.fillStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.12)
    context.fill()
    context.restore()

    context.beginPath()
    context.moveTo(points[0].x, points[0].y + inset)
    for (var j = 1; j < points.length; j++) context.lineTo(points[j].x, points[j].y + inset)
    context.lineWidth = 1.4
    context.strokeStyle = lineColor
    context.lineJoin = "round"
    context.stroke()
  }
}
