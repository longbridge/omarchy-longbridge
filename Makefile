QMLLINT := /usr/lib/qt6/bin/qmllint
QMLTESTRUNNER := /usr/lib/qt6/bin/qmltestrunner
SMOKE_SECONDS := 15
QML_FILES := Panel.qml LongbridgeRpc.qml QuoteFeed.qml WatchlistService.qml PortfolioService.qml \
	components/LongbridgeSetup.qml \
	components/LiveIndicator.qml \
	components/Sparkline.qml \
	components/LongbridgeLogo.qml \
	components/HoldingRow.qml \
	components/PanelMenu.qml \
	components/PortfolioView.qml \
	components/WatchlistRow.qml \
	components/WatchlistView.qml \
	components/SymbolDetail.qml

.PHONY: test test-js test-qml test-install qml-check validate smoke smoke-live

test: test-js test-qml test-install

test-js:
	node --test tests/test_cli_adapter.js tests/test_rpc_adapter.js tests/test_cache_adapter.js tests/test_chart_adapter.js tests/test_setup_adapter.js tests/test_model.js tests/test_portfolio_model.js

test-install:
	bash tests/test_install.sh
	bash tests/test_setup_source.sh
	bash tests/test_panel_source.sh

test-qml:
	env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen \
		$(QMLTESTRUNNER) -input tests/qml -import components

# Quickshell.Io types only exist inside the quickshell runtime, so the
# `longbridge serve` data path is exercised by running it. `smoke` serves the
# fixtures from tests/bin/longbridge and stays offline; `smoke-live` uses the
# installed CLI and your own Longbridge session.
smoke:
	PATH="$(CURDIR)/tests/bin:$$PATH" timeout $(SMOKE_SECONDS) quickshell -p ./smoke_serve.qml || true

smoke-live:
	timeout $(SMOKE_SECONDS) quickshell -p ./smoke_serve.qml || true

qml-check:
	$(QMLLINT) -I /usr/share/omarchy/shell $(QML_FILES)

validate: test qml-check
	omarchy plugin validate .
	git diff --check
