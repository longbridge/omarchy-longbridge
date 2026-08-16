import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Column {
  id: root

  required property string market
  required property var rows
  property int selectedIndex: -1
  property int indexOffset: 0
  property double nowMs: Date.now()
  property color textColor: Color.foreground
  property string panelFontFamily: Style.font.family
  signal rowActivated(int globalIndex)
  signal rowHovered(int globalIndex)

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(5)

  PanelSectionHeader {
    text: root.market + " MARKET  ·  " + root.rows.length
    foreground: root.textColor
    fontFamily: root.panelFontFamily
  }

  Repeater {
    model: root.rows
    delegate: QuoteTile {
      required property var modelData
      required property int index
      quote: modelData
      rowIndex: root.indexOffset + index
      hasCursor: root.selectedIndex === rowIndex
      stale: Model.isStale(modelData, root.nowMs, 120000)
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      onActivateRequested: root.rowActivated(rowIndex)
      onHoverRequested: function(globalIndex) { root.rowHovered(globalIndex) }
    }
  }
}

