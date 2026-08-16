import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Column {
  id: root

  required property var groups
  required property string activeGroupId
  required property var rows
  required property color textColor
  required property string panelFontFamily
  property bool loading: false
  property string message: ""
  property int selectedIndex: 0
  property bool detailOpen: false
  property double nowMs: Date.now()
  signal groupSelected(string groupId)
  signal refreshRequested()

  readonly property color dimColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.58)
  readonly property var selectedQuote: rows.length > 0
    ? rows[Math.max(0, Math.min(selectedIndex, rows.length - 1))] : null
  readonly property var groupOptions: {
    var result = []
    for (var i = 0; i < groups.length; i++)
      result.push({ value: String(groups[i].id), label: String(groups[i].name || "Unnamed") })
    return result
  }

  width: parent ? parent.width : 0
  spacing: Style.space(8)

  Row {
    width: parent.width
    spacing: Style.space(7)

    Dropdown {
      id: groupDropdown
      width: Style.space(170)
      showLabel: false
      value: root.activeGroupId
      options: root.groupOptions
      foreground: root.textColor
      fontFamily: root.panelFontFamily
      onChanged: function(value) {
        root.selectedIndex = 0
        root.detailOpen = false
        root.groupSelected(value)
      }
    }
    Text {
      width: Math.max(0, parent.width - groupDropdown.width - refreshButton.width - parent.spacing * 2)
      anchors.verticalCenter: parent.verticalCenter
      text: root.loading ? "Refreshing…" : (root.message || root.rows.length + " symbols")
      color: root.dimColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignRight
    }
    PanelActionButton {
      id: refreshButton
      iconText: "󰑐"
      tooltipText: "Refresh"
      foreground: root.textColor
      fontFamily: root.panelFontFamily
      size: Style.space(28)
      bordered: false
      enabled: !root.loading
      onClicked: root.refreshRequested()
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
        text: root.loading ? "Loading Longbridge watchlist…" : "This group is empty."
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
  }
}
