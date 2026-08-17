import QtQuick
import qs.Commons
import "../PortfolioModel.js" as PortfolioModel

Rectangle {
  id: root

  required property var holding
  required property color textColor
  required property color gainColor
  required property color lossColor
  required property string panelFontFamily
  property bool selected: false
  signal activated()

  readonly property color dimColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.56)
  readonly property real dayGain: Number(holding.day_gain || 0)
  readonly property real dayPercent: PortfolioModel.intradayPercent(holding)

  // "25 @ 430.16" — the quantity held and what it cost, the terminal's Qty and
  // Cost columns in the room a 44-unit row can spare.
  readonly property string positionLine: {
    var quantity = Number(root.holding.quantity || 0)
    if (quantity === 0) return ""
    var shares = quantity.toLocaleString(Qt.locale(), "f", quantity % 1 === 0 ? 0 : 4)
    var cost = Number(root.holding.cost_price || 0)
    return cost > 0 ? shares + " @ " + cost.toLocaleString(Qt.locale(), "f", 2) : shares
  }

  function signedPercent(value) {
    var amount = Number(value || 0)
    return (amount > 0 ? "+" : amount < 0 ? "−" : "") + Math.abs(amount).toFixed(2) + "%"
  }

  width: ListView.view ? ListView.view.width : implicitWidth
  implicitHeight: Style.space(44)
  radius: Style.cornerRadius
  color: selected || hover.hovered
    ? Qt.rgba(textColor.r, textColor.g, textColor.b, selected ? 0.10 : 0.05)
    : "transparent"

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(9)
    anchors.right: valueColumn.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(4)

    // Symbol keeps its full width and the name takes whatever is left, elided:
    // quantity and cost still get a line of their own below, which is what
    // crowding them onto this one cost.
    Row {
      width: parent.width
      spacing: Style.space(6)
      Text {
        id: symbolText
        text: String(root.holding.symbol || "")
        color: root.textColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
      Text {
        width: Math.max(0, parent.width - symbolText.width - parent.spacing)
        anchors.baseline: symbolText.baseline
        text: String(root.holding.name || "")
        color: root.dimColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Text {
      width: parent.width
      text: root.positionLine
      color: root.dimColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Column {
    id: valueColumn
    anchors.right: parent.right
    anchors.rightMargin: Style.space(9)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(4)
    Text {
      anchors.right: parent.right
      text: String(root.holding.currency || "") + " " + Number(root.holding.market_value || 0).toLocaleString(Qt.locale(), "f", 2)
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
    Text {
      anchors.right: parent.right
      text: (root.dayGain > 0 ? "+" : root.dayGain < 0 ? "−" : "")
        + Math.abs(root.dayGain).toLocaleString(Qt.locale(), "f", 2)
        + "  " + root.signedPercent(root.dayPercent)
      color: root.dayGain < 0 ? root.lossColor : root.gainColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  HoverHandler { id: hover }
  TapHandler { onTapped: root.activated() }
}
