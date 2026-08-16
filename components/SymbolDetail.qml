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
  signal removeRequested()

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

    Item { width: Math.max(0, parent.width - parent.children[0].width - parent.children[2].width - parent.spacing * 2); height: 1 }

    Button {
      text: "Remove"
      iconText: "×"
      bordered: true
      foreground: root.textColor
      fontFamily: root.panelFontFamily
      onClicked: root.removeRequested()
    }
  }

  Text {
    width: parent.width
    text: String(root.quote && root.quote.symbol || "")
    color: root.textColor
    font.family: root.panelFontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  Text {
    width: parent.width
    text: Model.formatPrice(root.quote && root.quote.last) + "  " + String(root.quote && root.quote.currency || "")
    color: root.textColor
    font.family: root.panelFontFamily
    font.pixelSize: Style.font.hero
    font.bold: true
  }

  Grid {
    width: parent.width
    columns: 2
    columnSpacing: Style.space(12)
    rowSpacing: Style.space(8)

    Repeater {
      model: [
        { label: "OPEN", value: root.quote && root.quote.open },
        { label: "PREVIOUS", value: root.quote && root.quote.prev_close },
        { label: "HIGH", value: root.quote && root.quote.high },
        { label: "LOW", value: root.quote && root.quote.low },
        { label: "VOLUME", value: root.quote && root.quote.volume },
        { label: "SESSION", value: root.quote && root.quote.trade_session }
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
          text: modelData.label === "SESSION" || modelData.label === "VOLUME"
            ? String(modelData.value || "—") : Model.formatPrice(modelData.value)
          color: root.textColor
          font.family: root.panelFontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
      }
    }
  }
}

