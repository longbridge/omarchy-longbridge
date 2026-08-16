QMLLINT := /usr/lib/qt6/bin/qmllint
QML_FILES := Panel.qml QuoteBridge.qml \
	components/ConnectionBanner.qml \
	components/MarketGroup.qml \
	components/QuoteTile.qml \
	components/SymbolDetail.qml

.PHONY: test test-js test-rust qml-check

test: test-js test-rust

test-js:
	node --test tests/test_model.js tests/test_protocol.js

test-rust:
	cargo test --manifest-path helper/Cargo.toml

qml-check:
	$(QMLLINT) -I /usr/share/omarchy/shell $(QML_FILES)
