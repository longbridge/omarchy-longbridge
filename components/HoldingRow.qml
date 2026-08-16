import QtQuick
import qs.Commons

Rectangle {
  id: root

  required property var holding
  required property color textColor
  required property string panelFontFamily
  property bool selected: false
  signal activated()

  readonly property color dimColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.56)
  readonly property real dayGain: Number(holding.day_gain || 0)
  readonly property color gainColor: "#63d297"
  readonly property color lossColor: "#ff6b7a"

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
    spacing: 0
    Text {
      width: parent.width
      text: String(root.holding.symbol || "")
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: String(root.holding.name || "")
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
    spacing: 0
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
      text: "Today " + (root.dayGain > 0 ? "+" : root.dayGain < 0 ? "−" : "")
        + String(root.holding.currency || "") + " " + Math.abs(root.dayGain).toLocaleString(Qt.locale(), "f", 2)
      color: root.dayGain < 0 ? root.lossColor : root.gainColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  HoverHandler { id: hover }
  TapHandler { onTapped: root.activated() }
}
