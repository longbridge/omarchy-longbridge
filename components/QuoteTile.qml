import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

CursorSurface {
  id: root

  required property var quote
  required property int rowIndex
  property bool stale: false
  property color textColor: Color.foreground
  property color positiveColor: "#45b97c"
  property color negativeColor: Color.urgent
  property string panelFontFamily: Style.font.family
  signal activateRequested()
  signal hoverRequested(int rowIndex)

  readonly property real lastValue: Number(quote && quote.last)
  readonly property real previousValue: Number(quote && quote.prev_close)
  readonly property real changePercent: previousValue !== 0
    ? (lastValue - previousValue) / previousValue * 100 : 0
  readonly property color movementColor: changePercent > 0 ? positiveColor
    : (changePercent < 0 ? negativeColor : textColor)

  width: parent ? parent.width : implicitWidth
  implicitHeight: Style.space(52)
  bordered: true

  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Style.space(3)
    radius: width / 2
    color: root.movementColor
  }

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.right: priceColumn.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(1)

    Text {
      width: parent.width
      text: String(root.quote && root.quote.symbol || "")
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: root.stale ? "STALE" : String(root.quote && (root.quote.trade_session || root.quote.name) || "Waiting for quote…")
      color: root.stale ? root.negativeColor : Qt.darker(root.textColor, 1.5)
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      font.bold: root.stale
      elide: Text.ElideRight
    }
  }

  Column {
    id: priceColumn
    anchors.right: parent.right
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(100)
    spacing: Style.space(1)

    Text {
      width: parent.width
      text: Model.formatPrice(root.quote && root.quote.last)
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }

    Text {
      width: parent.width
      text: Model.formatPercent(root.changePercent)
      color: root.movementColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignRight
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.hoverRequested(root.rowIndex)
    onClicked: root.activateRequested()
  }
}

