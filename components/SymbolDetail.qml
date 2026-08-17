import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Column {
  id: root

  required property var quote
  property color textColor: Color.foreground
  property string panelFontFamily: Style.font.family
  signal backRequested()

  readonly property real lastValue: Number(root.quote && root.quote.last || 0)
  readonly property real previousValue: Number(root.quote && root.quote.prev_close || 0)
  readonly property real changeValue: previousValue > 0 ? lastValue - previousValue : 0
  readonly property real changePercent: previousValue > 0 ? (changeValue / previousValue) * 100 : 0
  readonly property color movementColor: changeValue < 0 ? "#ff6b7a" : "#63d297"

  function signed(value, places) {
    var amount = Number(value || 0)
    return (amount > 0 ? "+" : amount < 0 ? "−" : "") + Math.abs(amount).toFixed(places)
  }

  function compactCount(value) {
    var amount = Number(value || 0)
    if (!isFinite(amount) || amount === 0) return "—"
    if (Math.abs(amount) >= 1e9) return (amount / 1e9).toFixed(2) + "B"
    if (Math.abs(amount) >= 1e6) return (amount / 1e6).toFixed(2) + "M"
    if (Math.abs(amount) >= 1e3) return (amount / 1e3).toFixed(2) + "K"
    return String(amount)
  }

  function ratio(value, divisor) {
    var top = Number(value || 0)
    var bottom = Number(divisor || 0)
    return bottom > 0 ? (top / bottom).toFixed(2) : "—"
  }

  width: parent ? parent.width : implicitWidth
  spacing: Style.spacing.panelGap

  Row {
    width: parent.width
    spacing: Style.space(8)

    Button {
      text: "Back"
      iconText: "←"
      bordered: true
      foreground: root.textColor
      fontFamily: root.panelFontFamily
      onClicked: root.backRequested()
    }

    Item { width: Math.max(0, parent.width - parent.children[0].width - parent.spacing); height: 1 }
  }

  Column {
    width: parent.width
    spacing: Style.space(1)
    Text {
      width: parent.width
      text: String(root.quote && root.quote.name || "").toUpperCase()
      color: Qt.darker(root.textColor, 1.5)
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: String(root.quote && root.quote.symbol || "")
        + (root.quote && root.quote.currency ? "  ·  " + root.quote.currency : "")
        + (root.quote && root.quote.trade_status ? "  ·  " + root.quote.trade_status : "")
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }
  }

  // Last, change and change percent, all in the trend colour: this is the line
  // the panel is opened to read.
  Row {
    width: parent.width
    spacing: Style.space(10)

    Text {
      anchors.baseline: changeText.baseline
      text: Model.formatPrice(root.quote && root.quote.last)
      color: root.movementColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }
    Text {
      id: changeText
      text: root.signed(root.changeValue, Math.abs(root.lastValue) < 1 ? 4 : 2)
        + "  " + root.signed(root.changePercent, 2) + "%"
      color: root.movementColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
  }

  // Same intraday series the row draws, given the room to be read.
  Rectangle {
    width: parent.width
    height: Style.space(96)
    visible: detailChart.hasSeries
    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.03)
    border.width: 1
    border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
    radius: Style.cornerRadius

    Sparkline {
      id: detailChart
      anchors.fill: parent
      anchors.margins: Style.space(8)
      series: root.quote && root.quote.series ? root.quote.series : null
      previousClose: Number(root.quote && root.quote.prev_close || 0)
      lineColor: root.movementColor
      guideColor: root.textColor
    }
  }

  Grid {
    width: parent.width
    columns: 2
    columnSpacing: Style.space(12)
    rowSpacing: Style.space(8)

    Repeater {
      model: [
        { label: "OPEN", value: Model.formatPrice(root.quote && root.quote.open) },
        { label: "PREV CLOSE", value: Model.formatPrice(root.quote && root.quote.prev_close) },
        { label: "HIGH", value: Model.formatPrice(root.quote && root.quote.high) },
        { label: "LOW", value: Model.formatPrice(root.quote && root.quote.low) },
        { label: "VOLUME", value: root.compactCount(root.quote && root.quote.volume) },
        { label: "TURNOVER", value: root.compactCount(root.quote && root.quote.turnover) },
        { label: "P/E (TTM)", value: root.ratio(root.quote && root.quote.last, root.quote && root.quote.eps_ttm) },
        { label: "EPS (TTM)", value: root.quote && root.quote.eps_ttm ? Model.formatPrice(root.quote.eps_ttm) : "—" },
        { label: "BPS", value: root.quote && root.quote.bps ? Model.formatPrice(root.quote.bps) : "—" },
        { label: "DIV YIELD", value: root.quote && root.quote.dividend_yield ? Number(root.quote.dividend_yield).toFixed(2) + "%" : "—" },
        { label: "SHARES", value: root.compactCount(root.quote && root.quote.total_shares) },
        { label: "LOT SIZE", value: root.quote && root.quote.lot_size ? String(root.quote.lot_size) : "—" },
        { label: "SESSION", value: String(root.quote && (root.quote.price_session || root.quote.trade_session) || "—") }
      ]
      delegate: Column {
        required property var modelData
        width: (root.width - Style.space(12)) / 2
        Text {
          text: modelData.label
          color: Qt.darker(root.textColor, 1.5)
          font.family: root.panelFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Text {
          width: parent.width
          text: String(modelData.value || "—")
          color: root.textColor
          font.family: root.panelFontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
      }
    }
  }
}
