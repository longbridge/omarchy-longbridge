#!/usr/bin/env bash
set -euo pipefail

grep -F 'text: "Longbridge"' components/PanelMenu.qml >/dev/null
grep -F 'https://longbridge.com' components/PanelMenu.qml >/dev/null
grep -F 'text: "Longbridge CLI"' components/PanelMenu.qml >/dev/null
grep -F 'https://open.longbridge.com/docs/cli/' components/PanelMenu.qml >/dev/null
grep -F 'text: "GitHub"' components/PanelMenu.qml >/dev/null
grep -F 'https://github.com/longbridge/omarchy-longbridge' components/PanelMenu.qml >/dev/null
grep -F 'text: "Install CLI"' components/PanelMenu.qml >/dev/null
grep -F 'signal installCliRequested()' components/PanelMenu.qml >/dev/null
grep -F 'root.installCliRequested()' components/PanelMenu.qml >/dev/null
[[ "$(grep -Fc 'Quickshell.execDetached(["xdg-open",' components/PanelMenu.qml)" -eq 3 ]]
! grep -Fi 'exit' components/PanelMenu.qml

grep -F 'width: Style.space(11)' Panel.qml >/dev/null
grep -F 'openPanelIndicatorWidth: 0.01' Panel.qml >/dev/null
grep -F 'openPanelIndicatorHeight: 0.01' Panel.qml >/dev/null
! grep -F 'anchors.right: parent.right' Panel.qml | grep -F 'Style.space(5)'
grep -F 'visible: setup.ready' Panel.qml >/dev/null
grep -F 'panelOpen: root.opened && setup.ready' Panel.qml >/dev/null
grep -F 'active: root.activeTab === 1' Panel.qml >/dev/null
grep -F 'WatchlistView {' Panel.qml >/dev/null
grep -F 'PortfolioView {' Panel.qml >/dev/null
grep -F 'WatchlistService {' Panel.qml >/dev/null
! grep -F 'QuoteService {' Panel.qml
grep -F 'id: panelHeader' Panel.qml >/dev/null
grep -F 'implicitHeight: Style.space(32)' Panel.qml >/dev/null
grep -F 'anchors.verticalCenter: tabSegments.verticalCenter' Panel.qml >/dev/null
grep -F 'y: root.height - word.baselineOffset' components/LongbridgeLogoFull.qml >/dev/null
grep -F 'PanelSeparator {' components/PanelMenu.qml >/dev/null
grep -F 'LongbridgeLogoFull {' Panel.qml >/dev/null
grep -F 'id: headerIdentity' Panel.qml >/dev/null
grep -F 'anchors.leftMargin: 1' Panel.qml >/dev/null
! grep -F 'text: "Markets & Portfolio"' Panel.qml
grep -F 'property bool setupGuideOpen: false' Panel.qml >/dev/null
grep -F 'onInstallCliRequested: root.setupGuideOpen = true' Panel.qml >/dev/null
grep -F 'anchors.verticalCenter: parent.verticalCenter' Panel.qml >/dev/null
! grep -F 'public quotes' Panel.qml
! grep -F 'Longbridge account portfolio' Panel.qml
grep -F 'id: tabSegments' Panel.qml >/dev/null
grep -F 'radius: 0' Panel.qml >/dev/null

grep -F 'implicitHeight: Style.space(44)' components/WatchlistRow.qml >/dev/null
grep -F 'implicitHeight: Style.space(44)' components/HoldingRow.qml >/dev/null
grep -F 'spacing: Style.space(4)' components/HoldingRow.qml >/dev/null
grep -F 'ListView {' components/WatchlistView.qml >/dev/null
grep -F 'Dropdown {' components/WatchlistView.qml >/dev/null
grep -F 'id: searchField' components/WatchlistView.qml >/dev/null
grep -F 'placeholderText: "Filter"' components/WatchlistView.qml >/dev/null
# The list is keyed by symbol so a price tick updates delegates in place
# instead of rebuilding them, which is what made the chart flicker and the
# view jump while charts loaded.
grep -F 'model: root.rowKeys' components/WatchlistView.qml >/dev/null
grep -F 'quote: root.rowFor(modelData)' components/WatchlistView.qml >/dev/null
grep -F 'id: clearButton' components/WatchlistView.qml >/dev/null
# Keep the clear action easy to hit without making its glyph visually heavy.
grep -F 'width: Style.space(28)' components/WatchlistView.qml >/dev/null
grep -F 'height: Style.space(28)' components/WatchlistView.qml >/dev/null
# The filter is a button until it is asked for, and anything else closes it.
grep -F 'id: searchButton' components/WatchlistView.qml >/dev/null
grep -F 'property bool searchExpanded: false' components/WatchlistView.qml >/dev/null
grep -F 'function releaseSearch()' components/WatchlistView.qml >/dev/null
! grep -F 'text: "All accounts"' components/PortfolioView.qml
# Rows are narrow: no currency column, and the stale marker is a glyph.
! grep -F 'text: "STALE"' components/WatchlistRow.qml
! grep -F 'root.quote.currency' components/WatchlistRow.qml
grep -F 'ToolTip.text: "Last price is more than five minutes old"' components/WatchlistRow.qml >/dev/null
# The detail links out to the full quote page, and opens it the same way the
# resource menu opens its links.
grep -F '"https://longbridge.com/quote/" + symbol' components/SymbolDetail.qml >/dev/null
grep -F 'Quickshell.execDetached(["xdg-open"' components/SymbolDetail.qml >/dev/null
grep -F 'tooltipText: "Open on longbridge.com"' components/SymbolDetail.qml >/dev/null
grep -F 'blocked: root.activeTab === 0 && watchlistView.searching' Panel.qml >/dev/null
grep -F 'watchlistView.focusSearch()' Panel.qml >/dev/null
grep -F 'Quickshell.cachePath("longbridge/watchlist.json")' WatchlistService.qml >/dev/null
grep -F 'onLoaded: root.applyCache(cacheFile.text())' WatchlistService.qml >/dev/null
grep -F 'atomicWrites: true' WatchlistService.qml >/dev/null
grep -F 'groups: watchlistService.groups' Panel.qml >/dev/null
grep -F 'activeGroupId: watchlistService.activeGroupId' Panel.qml >/dev/null
! grep -F 'addRequested' components/WatchlistView.qml
! grep -F 'removeRequested' components/WatchlistView.qml
! grep -F 'text: "Add"' components/WatchlistView.qml
! grep -F 'text: "Remove"' components/SymbolDetail.qml
! grep -F 'key === "a"' Panel.qml
! grep -F 'onDeleteRequested' Panel.qml
grep -F 'ListView {' components/PortfolioView.qml >/dev/null
! grep -F 'LongbridgeLogo' components/PortfolioView.qml
# Prices stream; there is no refresh control on either tab and no update timer.
! grep -F 'tooltipText: "Refresh"' components/PortfolioView.qml
! grep -F 'tooltipText: "Refresh"' components/WatchlistView.qml
! grep -F 'refreshRequested' components/PortfolioView.qml
! grep -F 'refreshRequested' components/WatchlistView.qml
grep -F 'LiveIndicator {' components/PortfolioView.qml >/dev/null
grep -F 'LiveIndicator {' components/WatchlistView.qml >/dev/null
! grep -F 'SequentialAnimation on opacity' components/LiveIndicator.qml
grep -F 'liveColor: root.gainColor' components/PortfolioView.qml >/dev/null
grep -F 'liveColor: root.gainColor' components/WatchlistView.qml >/dev/null
# Semantic UI colors must come from the active system theme. Only the logo may
# retain Longbridge's fixed brand palette.
grep -F 'required property color foregroundColor' components/LongbridgeLogo.qml >/dev/null
! grep -F 'property color foregroundColor: "#' components/LongbridgeLogo.qml
grep -F 'accentColor: Color.accent' Panel.qml >/dev/null
grep -F 'urgentColor: root.urgent' Panel.qml >/dev/null
grep -F 'gainColor: themePalette.green' Panel.qml >/dev/null
grep -F 'lossColor: themePalette.red' Panel.qml >/dev/null
grep -F 'readonly property color green:' ThemePalette.qml >/dev/null
grep -F 'readonly property color red:' ThemePalette.qml >/dev/null
! grep -nE '#[0-9A-Fa-f]{3,8}' \
  components/HoldingRow.qml \
  components/LiveIndicator.qml \
  components/PortfolioView.qml \
  components/Sparkline.qml \
  components/SymbolDetail.qml \
  components/WatchlistRow.qml \
  components/WatchlistView.qml
# Charts live in their own fixed column so every row's line starts at the same x.
grep -F 'Sparkline {' components/WatchlistRow.qml >/dev/null
grep -F 'Sparkline {' components/SymbolDetail.qml >/dev/null
grep -F 'width: Style.space(58)' components/WatchlistRow.qml >/dev/null
grep -F 'width: Style.space(104)' components/WatchlistRow.qml >/dev/null
# One chart request per symbol, not one per tick.
grep -F 'root.chartRequested(symbol)' components/WatchlistRow.qml >/dev/null
grep -F 'if (!symbol || symbol === chartAskedFor) return' components/WatchlistRow.qml >/dev/null
grep -F 'watchlistService.requestChart(symbol)' Panel.qml >/dev/null
# The holdings group is filled from account positions, not the watchlist API.
# Rows painted from the cache ask for charts before the session exists, so the
# queue must wait for it rather than be spent against a stopped server.
grep -F 'if (!session || !session.ready) return' WatchlistService.qml >/dev/null
grep -F 'root.drainCharts()' WatchlistService.qml >/dev/null
grep -F 'trade.stock_positions' WatchlistService.qml >/dev/null
grep -F 'RpcAdapter.holdingsGroupIndex(parsed.groups)' WatchlistService.qml >/dev/null
grep -F 'QuoteFeed {' Panel.qml >/dev/null
grep -F 'LongbridgeRpc {' Panel.qml >/dev/null
grep -F 'feed.setSymbols("watchlist", symbols)' WatchlistService.qml >/dev/null
grep -F 'feed.setSymbols("portfolio", wanted)' PortfolioService.qml >/dev/null
grep -F 'implicitWidth: Style.space(28)' components/PanelMenu.qml >/dev/null
grep -F 'property bool previewInstallGuide: false' components/LongbridgeSetup.qml >/dev/null
grep -F 'property bool cliInstalled: false' components/LongbridgeSetup.qml >/dev/null
grep -F 'property bool dismissible: false' components/LongbridgeSetup.qml >/dev/null
grep -F 'root.cliInstalled = true' components/LongbridgeSetup.qml >/dev/null
grep -F 'dismissible: setup.cliInstalled && root.setupGuideOpen' Panel.qml >/dev/null
grep -F 'visible: root.dismissible' components/LongbridgeSetup.qml >/dev/null
grep -F 'text: "Back"' components/LongbridgeSetup.qml >/dev/null

printf '%s\n' 'ok - compact panel source'
