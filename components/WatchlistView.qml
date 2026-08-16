import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Column {
  id: root

  required property var rows
  required property color textColor
  required property string panelFontFamily
  property bool loading: false
  property string message: ""
  property int selectedIndex: 0
  property bool detailOpen: false
  property double nowMs: Date.now()
  signal addRequested(string symbol)
  signal removeRequested(int index)
  signal refreshRequested()

  readonly property color dimColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.58)
  readonly property var selectedQuote: rows.length > 0
    ? rows[Math.max(0, Math.min(selectedIndex, rows.length - 1))] : null
  property bool addMode: false

  width: parent ? parent.width : 0
  spacing: Style.space(8)

  Row {
    width: parent.width
    spacing: Style.space(7)

    Text {
      width: Math.max(0, parent.width - addButton.width - refreshButton.width - parent.spacing * 2)
      anchors.verticalCenter: parent.verticalCenter
      text: root.loading ? "Refreshing public quotes…" : (root.message || root.rows.length + " watched")
      color: root.dimColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
    Button {
      id: addButton
      text: root.addMode ? "Cancel" : "Add"
      foreground: root.textColor
      bordered: true
      onClicked: root.addMode = !root.addMode
    }
    Button {
      id: refreshButton
      text: "Refresh"
      foreground: root.textColor
      bordered: true
      enabled: !root.loading
      onClicked: root.refreshRequested()
    }
  }

  Row {
    visible: root.addMode
    width: parent.width
    spacing: Style.space(7)
    TextField {
      id: symbolField
      width: parent.width - saveButton.width - parent.spacing
      placeholderText: "AAPL.US or 700.HK"
      foreground: root.textColor
      maximumLength: 24
      Keys.onReturnPressed: saveButton.clicked()
    }
    Button {
      id: saveButton
      text: "Add"
      foreground: root.textColor
      bordered: true
      enabled: symbolField.text.trim() !== ""
      onClicked: {
        root.addRequested(symbolField.text)
        symbolField.text = ""
        root.addMode = false
      }
    }
  }

  Rectangle {
    visible: !root.detailOpen
    width: parent.width
    height: Math.min(Style.space(352), Math.max(Style.space(88), quoteList.contentHeight))
    radius: Style.cornerRadius
    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.025)
    border.width: 1
    border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
    clip: true

    ListView {
      id: quoteList
      anchors.fill: parent
      anchors.margins: 1
      model: root.rows
      currentIndex: root.selectedIndex
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: WatchlistRow {
        required property var modelData
        required property int index
        quote: modelData
        textColor: root.textColor
        panelFontFamily: root.panelFontFamily
        selected: index === root.selectedIndex
        stale: modelData.ready && Number(modelData.timestamp || 0) > 0
          && root.nowMs - Number(modelData.timestamp) * 1000 > 300000
        onActivated: {
          root.selectedIndex = index
          root.detailOpen = true
        }
      }

      Text {
        visible: root.rows.length === 0
        anchors.centerIn: parent
        text: "Add a symbol to begin."
        color: root.dimColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  SymbolDetail {
    visible: root.detailOpen && root.selectedQuote !== null
    quote: root.selectedQuote || ({})
    textColor: root.textColor
    panelFontFamily: root.panelFontFamily
    onBackRequested: root.detailOpen = false
    onRemoveRequested: {
      root.removeRequested(root.selectedIndex)
      root.detailOpen = false
    }
  }
}
