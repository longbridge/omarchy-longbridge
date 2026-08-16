#!/usr/bin/env bash
set -euo pipefail

grep -F 'text: "Longbridge"' components/PanelMenu.qml >/dev/null
grep -F 'https://longbridge.com' components/PanelMenu.qml >/dev/null
grep -F 'text: "Longbridge CLI"' components/PanelMenu.qml >/dev/null
grep -F 'https://open.longbridge.com/docs/cli/' components/PanelMenu.qml >/dev/null
grep -F 'text: "GitHub"' components/PanelMenu.qml >/dev/null
grep -F 'https://github.com/longbridge/omarchy-longbridge' components/PanelMenu.qml >/dev/null
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
grep -F 'anchors.verticalCenter: parent.verticalCenter' Panel.qml >/dev/null
! grep -F 'public quotes' Panel.qml
! grep -F 'Longbridge account portfolio' Panel.qml
grep -F 'id: tabSegments' Panel.qml >/dev/null
grep -F 'radius: 0' Panel.qml >/dev/null

grep -F 'implicitHeight: Style.space(44)' components/WatchlistRow.qml >/dev/null
grep -F 'implicitHeight: Style.space(44)' components/HoldingRow.qml >/dev/null
grep -F 'spacing: Style.space(4)' components/HoldingRow.qml >/dev/null
grep -F 'ListView {' components/WatchlistView.qml >/dev/null
grep -F 'ListView {' components/PortfolioView.qml >/dev/null
! grep -F 'LongbridgeLogo' components/PortfolioView.qml
grep -F 'PanelActionButton {' components/PortfolioView.qml >/dev/null
grep -F 'iconText: "󰑐"' components/PortfolioView.qml >/dev/null
grep -F 'tooltipText: "Refresh"' components/PortfolioView.qml >/dev/null
! grep -F 'text: "Refresh"' components/PortfolioView.qml
grep -F 'implicitWidth: Style.space(28)' components/PanelMenu.qml >/dev/null

printf '%s\n' 'ok - compact panel source'
