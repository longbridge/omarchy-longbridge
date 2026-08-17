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
  readonly property var quoteRows: Model.rows(marketState)
  readonly property real openPanelIndicatorWidth: 0.01
  readonly property real openPanelIndicatorHeight: 0.01

  property var marketState: Model.initialState([])
  property var portfolioState: PortfolioModel.initialState()
  property int activeTab: 0
  property bool setupGuideOpen: false
  property double nowMs: Date.now()

  function moveSelection(delta) {
    if (activeTab === 0) {
      watchlistView.moveSelection(delta)
    } else {
      var count = (portfolioState.positions || []).length
      portfolioView.selectedIndex = Math.max(0, Math.min(count - 1, portfolioView.selectedIndex + delta))
    }
  }

  // One `longbridge serve` session and one push feed for the whole panel: the
  // watchlist and the portfolio register the symbols they show and are fed by
  // the same subscription. Nothing in the panel polls for prices.
  LongbridgeRpc {
    id: session
    serving: root.opened && setup.ready
  }

  QuoteFeed {
    id: feed
    session: session
    active: root.opened
  }

  WatchlistService {
    id: watchlistService
    session: session
    feed: feed
    panelOpen: root.opened && setup.ready
    active: root.activeTab === 0
    onGroupsEvent: function(groups, defaultGroupId) {
      root.marketState = Model.applyGroups(root.marketState, groups, defaultGroupId)
    }
    onGroupSelected: function(groupId) {
      root.marketState = Model.selectGroup(root.marketState, groupId)
    }
    onQuoteEvent: function(event) { root.marketState = Model.applyEvent(root.marketState, event) }
  }

  PortfolioService {
    id: portfolioService
    feed: feed
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
      if (root.activeTab === 0) watchlistService.refresh()
      else portfolioService.refresh()
      return "ok"
    }
    function status(): string {
      return JSON.stringify({
        setup: setup.setupState,
        tab: root.activeTab === 0 ? "watchlist" : "portfolio",
        watchlist: watchlistService.watchlistState,
        group: watchlistService.activeGroupId,
        session: session.status,
        live: feed.live,
        subscribed: feed.symbolCount,
        charts: Object.keys(watchlistService.charts).length
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
      // The watchlist filter is an inline editor: while it holds focus every
      // key belongs to it, including the panel's single-letter shortcuts.
      blocked: root.activeTab === 0 && watchlistView.searching
      onMoveRequested: function(dx, dy) { if (dy !== 0 && setup.ready) root.moveSelection(dy) }
      onActivateRequested: {
        if (!setup.ready) return
        if (root.activeTab === 0 && watchlistView.visibleRows.length > 0) watchlistView.detailOpen = true
        else if (root.activeTab === 1 && root.portfolioState.positions.length > 0) portfolioView.detailOpen = true
      }
      onCloseRequested: {
        if (root.activeTab === 0 && watchlistView.filterText !== "") watchlistView.clearSearch()
        else if (watchlistView.detailOpen) watchlistView.detailOpen = false
        else if (portfolioView.detailOpen) portfolioView.detailOpen = false
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (!setup.ready) return
        var key = String(text || "").toLowerCase()
        if ((key === "/" || key === "f") && root.activeTab === 0) watchlistView.focusSearch()
        else if (key === "r" && root.activeTab === 0) watchlistService.refresh()
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
          visible: !ready || root.setupGuideOpen
          panelOpen: root.opened
          previewInstallGuide: root.setupGuideOpen
          dismissible: setup.cliInstalled && root.setupGuideOpen
          textColor: root.foreground
          panelFontFamily: root.fontFamily
          onDismissed: root.setupGuideOpen = false
        }

        Item {
          id: panelHeader
          visible: setup.ready && !root.setupGuideOpen
          width: parent.width
          implicitHeight: Style.space(32)

          LongbridgeLogo {
            id: headerLogo
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(24)
            height: width
            foregroundColor: root.foreground
            brandColors: true
          }
          Column {
            id: headerIdentityText
            anchors.left: headerLogo.right
            anchors.leftMargin: Style.space(8)
            anchors.right: tabSegments.left
            anchors.rightMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)
            Text {
              width: parent.width
              text: "Longbridge"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: "Markets & Portfolio"
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
          PanelMenu {
            id: panelMenu
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textColor: root.foreground
            panelFontFamily: root.fontFamily
            onInstallCliRequested: root.setupGuideOpen = true
          }

          // The tabs ride in the header rather than owning a row of their own,
          // which buys the list a row of height in a panel this short.
          Rectangle {
            id: tabSegments
            anchors.right: panelMenu.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(150)
            // Same height as the menu button beside it, so the header reads as
            // one row of controls rather than two sizes.
            height: panelMenu.height
            radius: 0
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
            Row {
              anchors.fill: parent
              Repeater {
                model: ["Watchlist", "Portfolio"]
                Rectangle {
                  required property string modelData
                  required property int index
                  width: tabSegments.width / 2
                  height: tabSegments.height
                  radius: 0
                  color: index === root.activeTab
                    ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                    : "transparent"
                  Rectangle {
                    visible: index === 1
                    anchors.left: parent.left
                    width: 1
                    height: parent.height
                    color: tabSegments.border.color
                  }
                  Text {
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
          }
        }

        WatchlistView {
          id: watchlistView
          visible: setup.ready && !root.setupGuideOpen && root.activeTab === 0
          width: parent.width
          groups: watchlistService.groups
          activeGroupId: watchlistService.activeGroupId
          rows: root.quoteRows
          loading: watchlistService.loading
          message: watchlistService.message
          nowMs: root.nowMs
          live: watchlistService.live
          connecting: session.status === "starting"
          textColor: root.foreground
          panelFontFamily: root.fontFamily
          onGroupSelected: function(groupId) { watchlistService.selectGroup(groupId) }
          onChartRequested: function(symbol) { watchlistService.requestChart(symbol) }
        }

        PortfolioView {
          id: portfolioView
          visible: setup.ready && !root.setupGuideOpen && root.activeTab === 1
          width: parent.width
          portfolio: root.portfolioState
          loading: portfolioService.loading
          bridgeMessage: portfolioService.message
          textColor: root.foreground
          accentColor: Color.accent
          warningColor: root.urgent
          panelFontFamily: root.fontFamily
          live: portfolioService.live
          connecting: session.status === "starting"
        }
      }
    }
  }
}
