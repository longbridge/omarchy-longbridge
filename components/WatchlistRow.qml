import QtQuick
import QtQuick.Controls
import qs.Commons

Rectangle {
  id: root

  required property var quote
  required property color textColor
  required property string panelFontFamily
  property bool selected: false
  property bool stale: false
  signal activated()
  signal chartRequested(string symbol)

  readonly property color dimColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.56)
  readonly property real lastValue: Number(quote.last || 0)
  readonly property real previousValue: Number(quote.prev_close || 0)
  readonly property real changePercent: previousValue === 0 ? 0 : (lastValue - previousValue) / previousValue * 100
  readonly property color gainColor: "#63d297"
  readonly property color lossColor: "#ff6b7a"
  readonly property color movementColor: changePercent < 0 ? lossColor : gainColor

  width: ListView.view ? ListView.view.width : implicitWidth
  implicitHeight: Style.space(44)
  radius: Style.cornerRadius
  color: selected || hover.hovered
    ? Qt.rgba(textColor.r, textColor.g, textColor.b, selected ? 0.10 : 0.05)
    : "transparent"

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(9)
    anchors.right: chart.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(4)

    Text {
      width: parent.width
      text: String(root.quote.symbol || "")
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      font.capitalization: Font.AllUppercase
      elide: Text.ElideRight
    }
    // The name is uppercased, the error and the placeholder are not: those are
    // sentences, and shouting them reads as a fault rather than a label.
    Text {
      width: parent.width
      text: root.quote.errorMessage
        || (root.quote.name
          ? String(root.quote.name).toUpperCase()
          : (root.quote.ready ? "" : "Waiting for quote…"))
      color: root.dimColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Sparkline {
    id: chart
    anchors.right: priceColumn.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(58)
    height: Style.space(22)
    series: root.quote.series || null
    previousClose: root.previousValue
    lineColor: root.movementColor
    guideColor: root.textColor
  }

  Column {
    id: priceColumn
    anchors.right: parent.right
    anchors.rightMargin: Style.space(9)
    anchors.verticalCenter: parent.verticalCenter
    // Fixed so every row's chart starts at the same x: a price column that
    // sizes to its own text would step the sparklines in and out per row.
    width: Style.space(104)
    spacing: Style.space(4)

    Text {
      anchors.right: parent.right
      text: root.quote.ready ? Number(root.quote.last || 0).toLocaleString(Qt.locale(), "f", Math.abs(root.lastValue) < 1 ? 4 : 2) : "—"
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
    Row {
      anchors.right: parent.right
      spacing: Style.space(5)
      // Currency is a property of the security, not of this tick, and the
      // market is already in the symbol — the detail view carries it instead.
      Text {
        text: root.quote.ready
          ? (root.changePercent > 0 ? "+" : root.changePercent < 0 ? "−" : "") + Math.abs(root.changePercent).toFixed(2) + "%"
          : ""
        color: root.movementColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      // A clock, not the word STALE: the row is narrow and this only says the
      // last tick is old.
      Text {
        visible: root.stale
        text: "󱎫"
        color: root.dimColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption
        ToolTip.visible: staleHover.hovered
        ToolTip.text: "Last price is more than five minutes old"

        HoverHandler { id: staleHover }
      }
    }
  }

  // The row asks for its own line the first time it is drawn, so a group of
  // hundreds only fetches what the list actually shows. Asking once per symbol
  // is enough: `quote` is replaced on every tick, and re-asking then would fire
  // this for every chart-less row twice a second.
  property string chartAskedFor: ""

  function askForChart() {
    var symbol = String(root.quote && root.quote.symbol || "")
    if (!symbol || symbol === chartAskedFor) return
    chartAskedFor = symbol
    root.chartRequested(symbol)
  }

  Component.onCompleted: askForChart()
  onQuoteChanged: askForChart()

  HoverHandler { id: hover }
  TapHandler { onTapped: root.activated() }
}
