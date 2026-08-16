QMLLINT := /usr/lib/qt6/bin/qmllint
QML_FILES := Panel.qml LongbridgeCli.qml \
	components/ConnectionBanner.qml \
	components/MarketGroup.qml \
	components/PortfolioView.qml \
	components/QuoteTile.qml \
	components/SymbolDetail.qml

.PHONY: test test-js test-install qml-check validate

test: test-js test-install

test-js:
	node --test tests/test_cli_adapter.js tests/test_model.js tests/test_portfolio_model.js

test-install:
	bash tests/test_install.sh

qml-check:
	$(QMLLINT) -I /usr/share/omarchy/shell $(QML_FILES)

validate: test qml-check
	omarchy plugin validate .
	git diff --check
