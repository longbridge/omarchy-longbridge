QMLLINT := /usr/lib/qt6/bin/qmllint
QMLTESTRUNNER := /usr/lib/qt6/bin/qmltestrunner
QML_FILES := Panel.qml WatchlistService.qml PortfolioService.qml \
	components/LongbridgeSetup.qml \
	components/LongbridgeLogo.qml \
	components/HoldingRow.qml \
	components/PanelMenu.qml \
	components/PortfolioView.qml \
	components/WatchlistRow.qml \
	components/WatchlistView.qml \
	components/SymbolDetail.qml

.PHONY: test test-js test-qml test-install qml-check validate

test: test-js test-qml test-install

test-js:
	node --test tests/test_cli_adapter.js tests/test_setup_adapter.js tests/test_model.js tests/test_portfolio_model.js

test-install:
	bash tests/test_install.sh
	bash tests/test_setup_source.sh
	bash tests/test_panel_source.sh

test-qml:
	env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen $(QMLTESTRUNNER) -input tests/qml -import components

qml-check:
	$(QMLLINT) -I /usr/share/omarchy/shell $(QML_FILES)

validate: test qml-check
	omarchy plugin validate .
	git diff --check
