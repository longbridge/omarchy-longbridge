import QtQuick
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
  readonly property var quoteRows: Model.rows(marketState)
  readonly property real openPanelIndicatorWidth: 0.01
  readonly property real openPanelIndicatorHeight: 0.01

  property var marketState: Model.initialState(watchlist)
  property var portfolioState: PortfolioModel.initialState()
  property int activeTab: 0
  property double nowMs: Date.now()
  property string feedback: ""

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
      feedback = "Use a symbol such as AAPL.US or 700.HK."
      return
    }
    if (watchlist.indexOf(symbol) >= 0) {
      feedback = symbol + " is already watched."
      return
    }
    if (watchlist.length >= 20) {
      feedback = "The watchlist supports up to 20 symbols."
      return
    }
    persistWatchlist(watchlist.concat([symbol]))
    feedback = symbol + " added."
  }

  function removeWatchlistIndex(index) {
    if (index < 0 || index >= watchlist.length) return
    var next = watchlist.slice()
    next.splice(index, 1)
    persistWatchlist(next)
    watchlistView.selectedIndex = Math.max(0, Math.min(index, next.length - 1))
  }

  function moveSelection(delta) {
    if (activeTab === 0) {
      watchlistView.selectedIndex = Math.max(0, Math.min(quoteRows.length - 1, watchlistView.selectedIndex + delta))
    } else {
      var count = (portfolioState.positions || []).length
      portfolioView.selectedIndex = Math.max(0, Math.min(count - 1, portfolioView.selectedIndex + delta))
    }
  }

  onWatchlistChanged: marketState = Model.initialState(watchlist)

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
    function refresh(): string {
      if (root.activeTab === 0) quoteService.refresh()
      else portfolioService.refresh()
      return "ok"
    }
    function status(): string {
      return JSON.stringify({
        setup: setup.setupState,
        tab: root.activeTab === 0 ? "watchlist" : "portfolio",
        quotes: quoteService.quoteState,
        symbols: root.watchlist
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
    tooltipText: "Longbridge"
    active: false
    onPressed: function(buttonCode) { if (buttonCode === Qt.LeftButton) root.toggle() }
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
      onMoveRequested: function(dx, dy) { if (dy !== 0 && setup.ready) root.moveSelection(dy) }
      onActivateRequested: {
        if (!setup.ready) return
        if (root.activeTab === 0 && root.quoteRows.length > 0) watchlistView.detailOpen = true
        else if (root.activeTab === 1 && root.portfolioState.positions.length > 0) portfolioView.detailOpen = true
      }
      onDeleteRequested: if (setup.ready && root.activeTab === 0) root.removeWatchlistIndex(watchlistView.selectedIndex)
      onCloseRequested: {
        if (watchlistView.detailOpen) watchlistView.detailOpen = false
        else if (portfolioView.detailOpen) portfolioView.detailOpen = false
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (!setup.ready) return
        var key = String(text || "").toLowerCase()
        if (key === "a" && root.activeTab === 0) watchlistView.addMode = true
        else if (key === "r" && root.activeTab === 0) quoteService.refresh()
        else if (key === "r") portfolioService.refresh()
        else if (key === "w" || key === "m") root.activeTab = 0
        else if (key === "p") root.activeTab = 1
      }

      Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

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
          spacing: Style.space(9)

          LongbridgeLogo {
            width: Style.space(20)
            height: width
            foregroundColor: root.foreground
            brandColors: true
          }
          Column {
            width: Math.max(0, contentColumn.width - Style.space(20) - panelMenu.width - Style.space(18))
            spacing: 0
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
              text: root.activeTab === 0
                ? root.watchlist.length + " public quotes"
                : "Longbridge account portfolio"
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.58)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
          PanelMenu {
            id: panelMenu
            anchors.verticalCenter: parent.verticalCenter
            textColor: root.foreground
            panelFontFamily: root.fontFamily
          }
        }

        Row {
          visible: setup.ready
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: ["Watchlist", "Portfolio"]
            Rectangle {
              required property string modelData
              required property int index
              implicitWidth: tabLabel.implicitWidth + Style.space(20)
              implicitHeight: Style.space(28)
              radius: height / 2
              color: index === root.activeTab
                ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                : "transparent"
              border.width: index === root.activeTab ? 1 : 0
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
              Text {
                id: tabLabel
                anchors.centerIn: parent
                text: modelData
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: index === root.activeTab
              }
              TapHandler { onTapped: root.activeTab = index }
            }
          }
        }

        WatchlistView {
          id: watchlistView
          visible: setup.ready && root.activeTab === 0
          width: parent.width
          rows: root.quoteRows
          loading: quoteService.loading
          message: root.feedback || quoteService.message
          nowMs: root.nowMs
          textColor: root.foreground
          panelFontFamily: root.fontFamily
          onAddRequested: function(symbol) { root.addSymbol(symbol) }
          onRemoveRequested: function(index) { root.removeWatchlistIndex(index) }
          onRefreshRequested: quoteService.refresh()
        }

        PortfolioView {
          id: portfolioView
          visible: setup.ready && root.activeTab === 1
          width: parent.width
          portfolio: root.portfolioState
          loading: portfolioService.loading
          bridgeMessage: portfolioService.message
          textColor: root.foreground
          accentColor: Color.accent
          warningColor: root.urgent
          panelFontFamily: root.fontFamily
          onRefreshRequested: portfolioService.refresh()
        }
      }
    }
  }
}
