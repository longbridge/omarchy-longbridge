import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "PortfolioModel.js" as PortfolioModel
import "components"

Panel {
  id: root
  moduleName: "longbridge.omarchy"
  ipcTarget: "longbridge.omarchy"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var watchlist: Model.normalizedSymbols(setting("watchlist", ["AAPL.US", "700.HK", "D05.SG"]))
  readonly property var groups: Model.marketGroups(marketState)
  readonly property var flatRows: Model.rows(marketState)
  readonly property var selectedQuote: flatRows.length > 0
    ? flatRows[Math.max(0, Math.min(selectedIndex, flatRows.length - 1))] : null
  property var marketState: Model.initialState(watchlist)
  property int selectedIndex: 0
  property bool detailOpen: false
  property double nowMs: Date.now()
  property string feedback: ""
  property int activeTab: 0
  property var portfolioState: PortfolioModel.initialState()
  // This plugin uses no bar-side status or open-panel decorations.
  // A positive sub-pixel hint rounds to zero in the bar's indicator sizing.
  readonly property real openPanelIndicatorWidth: 0.01
  readonly property real openPanelIndicatorHeight: 0.01

  function persistWatchlist(symbols) {
    var entry = { id: root.moduleName, watchlist: Model.normalizedSymbols(symbols) }
    var current = root.settings || ({})
    for (var key in current) if (key !== "id" && key !== "watchlist") entry[key] = current[key]
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function addSymbol(value) {
    var symbol = Model.normalizedSymbol(value)
    if (!Model.symbolIsValid(symbol)) {
      feedback = "Use a Longbridge symbol such as AAPL.US or 700.HK."
      return
    }
    if (watchlist.indexOf(symbol) >= 0) {
      feedback = symbol + " is already watched."
      return
    }
    if (watchlist.length >= 20) {
      feedback = "Longbridge supports up to 20 symbols."
      return
    }
    persistWatchlist(watchlist.concat([symbol]))
    addField.text = ""
    feedback = symbol + " added."
  }

  function removeSelected() {
    if (!selectedQuote) return
    var next = []
    for (var i = 0; i < watchlist.length; i++) if (watchlist[i] !== selectedQuote.symbol) next.push(watchlist[i])
    persistWatchlist(next)
    selectedIndex = Math.max(0, Math.min(selectedIndex, next.length - 1))
    detailOpen = false
  }

  function moveSelection(delta) {
    if (flatRows.length === 0) return
    selectedIndex = Math.max(0, Math.min(flatRows.length - 1, selectedIndex + delta))
  }

  function activateSelected() {
    if (selectedQuote) detailOpen = true
  }

  function groupOffset(groupIndex) {
    var offset = 0
    for (var i = 0; i < groupIndex; i++) offset += groups[i].rows.length
    return offset
  }

  onWatchlistChanged: {
    marketState = Model.initialState(watchlist)
  }

  QuoteService {
    id: quoteService
    symbols: root.watchlist
    panelOpen: root.opened && setup.ready
    onQuoteEvent: function(event) { root.marketState = Model.applyEvent(root.marketState, event) }
  }

  PortfolioService {
    id: portfolioService
    panelOpen: root.opened && setup.ready
    active: root.activeTab === 1
    onPortfolioEvent: function(event) { root.portfolioState = PortfolioModel.applyEvent(root.portfolioState, event) }
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function reconnect(): string { quoteService.refresh(); return "ok" }
    function status(): string {
      return JSON.stringify({
        connection: quoteService.quoteState,
        symbols: root.watchlist,
        subscribed: root.marketState.subscribed,
        selected: root.selectedQuote ? root.selectedQuote.symbol : ""
      })
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    iconComponent: Component {
      Item {
        LongbridgeLogo {
          anchors.centerIn: parent
          width: Style.space(11)
          height: width
          foregroundColor: root.foreground
          brandColors: false
        }
      }
    }
    tooltipText: "Longbridge · " + quoteService.quoteState
    active: quoteService.quoteState === "error"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }

  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: addField.activeFocus
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveSelection(dy) }
      onActivateRequested: root.activateSelected()
      onDeleteRequested: root.removeSelected()
      onCloseRequested: {
        if (root.detailOpen) root.detailOpen = false
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        var key = String(text || "").toLowerCase()
        if (key === "a") addField.forceActiveFocus()
        else if (key === "r") quoteService.refresh()
        else if (key === "m") root.activeTab = 0
        else if (key === "p") root.activeTab = 1
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: contentColumn
          width: parent.width
          spacing: Style.spacing.panelGap

          LongbridgeSetup {
            id: setup
            width: parent.width
            visible: !ready
            panelOpen: root.opened
            textColor: root.foreground
            panelFontFamily: root.fontFamily
          }

          Row {
            visible: setup.ready
            width: parent.width
            spacing: Style.space(10)

            LongbridgeLogo {
              width: Style.space(20)
              height: width
              foregroundColor: root.foreground
              brandColors: true
            }

            Column {
              width: parent.parent.width - parent.children[0].width - parent.spacing
              Text {
                width: parent.width
                text: "Longbridge"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: root.watchlist.length + " symbols · " + quoteService.quoteState
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }

          Row {
            visible: setup.ready
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: ["Markets", "Portfolio"]
              Rectangle {
                required property string modelData
                required property int index
                implicitWidth: tabText.implicitWidth + Style.space(22)
                implicitHeight: Style.space(30)
                radius: height / 2
                color: index === root.activeTab ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15) : "transparent"
                border.width: index === root.activeTab ? 1 : 0
                border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.24)
                Text { id: tabText; anchors.centerIn: parent; text: modelData; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: index === root.activeTab }
                MouseArea { anchors.fill: parent; onClicked: root.activeTab = index }
              }
            }
          }

          ConnectionBanner {
            visible: setup.ready && root.activeTab === 0
            connectionState: quoteService.quoteState
            detail: quoteService.message
            textColor: root.foreground
            warningColor: root.urgent
            panelFontFamily: root.fontFamily
            onActionRequested: {
              quoteService.refresh()
            }
          }

          SymbolDetail {
            visible: setup.ready && root.activeTab === 0 && root.detailOpen && root.selectedQuote !== null
            quote: root.selectedQuote || ({})
            textColor: root.foreground
            panelFontFamily: root.fontFamily
            onBackRequested: root.detailOpen = false
            onRemoveRequested: root.removeSelected()
          }

          Column {
            visible: setup.ready && root.activeTab === 0 && !root.detailOpen
            width: parent.width
            spacing: Style.space(8)

            Row {
              width: parent.width
              spacing: Style.space(7)

              TextField {
                id: addField
                width: parent.width - addButton.width - parent.spacing
                placeholderText: "AAPL.US or 700.HK"
                foreground: root.foreground
                maximumLength: 24
                Keys.onReturnPressed: root.addSymbol(text)
              }

              Button {
                id: addButton
                text: "Add"
                iconText: "+"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: addField.text.trim() !== ""
                onClicked: root.addSymbol(addField.text)
              }
            }

            Text {
              visible: root.feedback !== ""
              width: parent.width
              text: root.feedback
              color: Qt.darker(root.foreground, 1.5)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }

            Text {
              visible: root.watchlist.length === 0
              width: parent.width
              text: "Add a canonical Longbridge symbol to begin."
              color: Qt.darker(root.foreground, 1.5)
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
              model: root.groups
              delegate: MarketGroup {
                required property var modelData
                required property int index
                market: modelData.market
                rows: modelData.rows
                selectedIndex: root.selectedIndex
                indexOffset: root.groupOffset(index)
                nowMs: root.nowMs
                textColor: root.foreground
                panelFontFamily: root.fontFamily
                onRowActivated: function(globalIndex) {
                  root.selectedIndex = globalIndex
                  root.detailOpen = true
                }
                onRowHovered: function(globalIndex) { root.selectedIndex = globalIndex }
              }
            }
          }


          PortfolioView {
            visible: setup.ready && root.activeTab === 1
            portfolio: root.portfolioState
            loading: portfolioService.loading
            bridgeMessage: portfolioService.message
            textColor: root.foreground
            accentColor: Color.accent
            warningColor: root.urgent
            panelFontFamily: root.fontFamily
            onRefreshRequested: portfolioService.refresh()
          }

          Text {
            visible: setup.ready && root.activeTab === 0
            width: parent.width
            text: "A add  ·  J/K select  ·  Enter detail  ·  X remove  ·  R reconnect"
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
