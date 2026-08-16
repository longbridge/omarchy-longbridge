import QtQuick
import qs.Commons

Rectangle {
  id: root

  required property var quote
  required property color textColor
  required property string panelFontFamily
  property bool selected: false
  property bool stale: false
  signal activated()

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
    anchors.right: priceColumn.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Text {
      width: parent.width
      text: String(root.quote.symbol || "")
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: root.quote.errorMessage || String(root.quote.name || (root.quote.ready ? "" : "Waiting for quote…"))
      color: root.dimColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Column {
    id: priceColumn
    anchors.right: parent.right
    anchors.rightMargin: Style.space(9)
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

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
      Text {
        text: String(root.quote.currency || "")
        color: root.dimColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption
      }
      Text {
        text: root.quote.ready
          ? (root.changePercent > 0 ? "+" : root.changePercent < 0 ? "−" : "") + Math.abs(root.changePercent).toFixed(2) + "%"
          : ""
        color: root.movementColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      Text {
        visible: root.stale
        text: "STALE"
        color: root.dimColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  HoverHandler { id: hover }
  TapHandler { onTapped: root.activated() }
}
