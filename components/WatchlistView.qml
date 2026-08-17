import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../Model.js" as Model

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
  property bool live: false
  property bool connecting: false
  property alias filterText: searchField.text
  readonly property bool searching: searchField.activeFocus
  signal groupSelected(string groupId)
  signal chartRequested(string symbol)

  // Quick filter over the loaded group; matching is case-insensitive across
  // both the symbol and the security name, so "tsm", "TSM.US" and "taiwan"
  // all reach the same row. Filtering is display-only: every symbol in the
  // group stays subscribed.
  readonly property var visibleRows: Model.filterRows(rows, filterText)

  // The list is driven by symbols, not by row objects. Rows are rebuilt on
  // every push, and handing a fresh array to ListView would destroy and
  // recreate every delegate twice a second — the flicker, and the scroll
  // jumping while charts loaded. Keys change only when membership, filter or
  // order changes, so a tick now updates properties in place instead.
  property var rowKeys: []
  property var rowIndex: ({})

  function syncRows() {
    var keys = Model.rowKeys(visibleRows)
    rowIndex = Model.rowsBySymbol(visibleRows)
    if (keys.join("\u0000") !== rowKeys.join("\u0000")) rowKeys = keys
  }

  function rowFor(symbol) {
    return rowIndex[symbol] || { symbol: symbol, ready: false, errorMessage: "" }
  }

  onVisibleRowsChanged: syncRows()
  Component.onCompleted: syncRows()

  function focusSearch() {
    searchField.forceActiveFocus()
    searchField.selectAll()
  }

  function clearSearch() {
    searchField.text = ""
    searchField.focus = false
  }

  function moveSelection(delta) {
    selectedIndex = Math.max(0, Math.min(visibleRows.length - 1, selectedIndex + delta))
  }

  readonly property color dimColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.58)
  readonly property var selectedQuote: visibleRows.length > 0
    ? visibleRows[Math.max(0, Math.min(selectedIndex, visibleRows.length - 1))] : null
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
      width: Style.space(112)
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
    TextField {
      id: searchField
      width: Style.space(150)
      height: groupDropdown.height
      anchors.verticalCenter: parent.verticalCenter
      placeholderText: "Filter"
      foreground: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      rightPadding: clearButton.width + Style.space(6)
      onTextChanged: {
        root.selectedIndex = 0
        root.detailOpen = false
      }
      Keys.onEscapePressed: function(event) {
        root.clearSearch()
        event.accepted = true
      }

      // Only offered once there is something to clear, so the field stays quiet
      // while empty.
      Text {
        id: clearButton
        anchors.right: parent.right
        anchors.rightMargin: Style.space(7)
        anchors.verticalCenter: parent.verticalCenter
        visible: searchField.text !== ""
        text: "✕"
        color: clearHover.hovered
          ? root.textColor
          : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption

        HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.clearSearch() }
      }
    }

    // Holds the live indicator against the right edge while the filter stays
    // beside the group dropdown.
    Item {
      width: Math.max(0, parent.width - groupDropdown.width - searchField.width
        - liveIndicator.width - parent.spacing * 3)
      height: 1
    }
    LiveIndicator {
      id: liveIndicator
      anchors.verticalCenter: parent.verticalCenter
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      live: root.live
      connecting: root.connecting
    }
  }

  Text {
    width: parent.width
    text: root.loading && root.rows.length === 0
      ? "Refreshing…"
      : (root.message || (root.visibleRows.length === root.rows.length
        ? root.rows.length + " symbols"
        : root.visibleRows.length + " of " + root.rows.length + " symbols"))
    color: root.dimColor
    font.family: root.panelFontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignRight
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
      model: root.rowKeys
      currentIndex: root.selectedIndex
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: WatchlistRow {
        required property string modelData
        required property int index
        quote: root.rowFor(modelData)
        textColor: root.textColor
        panelFontFamily: root.panelFontFamily
        selected: index === root.selectedIndex
        stale: quote.ready && Number(quote.timestamp || 0) > 0
          && root.nowMs - Number(quote.timestamp) * 1000 > 300000
        onActivated: {
          root.selectedIndex = index
          root.detailOpen = true
        }
        onChartRequested: function(symbol) { root.chartRequested(symbol) }
      }

      Text {
        visible: root.visibleRows.length === 0
        anchors.centerIn: parent
        text: root.loading
          ? "Loading Longbridge watchlist…"
          : (root.rows.length > 0 ? "No symbol matches this filter." : "This group is empty.")
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
