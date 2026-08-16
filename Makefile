QMLLINT := /usr/lib/qt6/bin/qmllint
QMLTESTRUNNER := /usr/lib/qt6/bin/qmltestrunner
QML_FILES := Panel.qml LongbridgeCli.qml \
	components/ConnectionBanner.qml \
	components/MarketGroup.qml \
	components/LongbridgeLogo.qml \
	components/PortfolioView.qml \
	components/QuoteTile.qml \
	components/SymbolDetail.qml

.PHONY: test test-python test-js test-qml test-install qml-check validate

test: test-python test-js test-qml test-install

test-python:
	python -m unittest -v tests.test_longbridge_quotes

test-js:
	node --test tests/test_cli_adapter.js tests/test_model.js tests/test_portfolio_model.js

test-install:
	bash tests/test_install.sh

test-qml:
	env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen $(QMLTESTRUNNER) -input tests/qml -import components

qml-check:
	$(QMLLINT) -I /usr/share/omarchy/shell $(QML_FILES)

validate: test qml-check
	omarchy plugin validate .
	git diff --check
