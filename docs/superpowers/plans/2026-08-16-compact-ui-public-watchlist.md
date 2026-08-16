# Compact UI and Public Watchlist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build mandatory Longbridge onboarding, a public-data watchlist that never invokes the Longbridge CLI, and compact bounded watchlist/holding interfaces.

**Architecture:** A bundled Python standard-library helper owns Yahoo Finance HTTP and provider-symbol mapping. Independent QML services own public watchlist and Longbridge portfolio process lifecycles; normalized models feed small QML view components. A mandatory setup page gates the normal panel until CLI installation and login are verified.

**Tech Stack:** Python 3 standard library, Qt 6/QML, Quickshell Process APIs, JavaScript model adapters, Node test runner, Python unittest, shell integration tests.

## Global Constraints

- Plugin name is `Longbridge`; ID is `longbridge.omarchy`.
- No Rust code or third-party Python packages.
- Watchlist runtime must never execute `longbridge`; only portfolio/setup may do so.
- Normal tabs remain unavailable until CLI installation and authenticated login are verified; no skip action exists.
- Portfolio data command is exactly `longbridge portfolio --format json`.
- Bar and item icons are monochrome; the main panel logo may use official colors.
- Red and green are used only for rise/fall numeric or textual values.
- No account icon appears beside “All accounts.”
- The bar has no status dot or panel-open underline.
- The top-right menu has exactly Longbridge, Longbridge CLI, and GitHub external links and no exit action.
- Watchlist and holding rows are 44 spacing units high and render in bounded list views.

---

### Task 1: Public quote helper

**Files:**
- Create: `longbridge-quotes`
- Create: `tests/test_longbridge_quotes.py`
- Create: `tests/fixtures/yahoo_chart.json`
- Modify: `Makefile`

**Interfaces:**
- Consumes: positional canonical symbols such as `AAPL.US`, `700.HK`, and `D05.SG`.
- Produces: `main(argv=None, opener=None, now_ms=None) -> int`, `provider_symbol(symbol) -> str`, `parse_chart(symbol, payload) -> dict`, and the JSON envelope from the design spec.

- [ ] **Step 1: Write failing provider and response tests**

```python
def test_provider_symbols():
    assert module.provider_symbol("AAPL.US") == "AAPL"
    assert module.provider_symbol("700.HK") == "0700.HK"
    assert module.provider_symbol("D05.SG") == "D05.SI"
    assert module.provider_symbol("600519.SH") == "600519.SS"
    assert module.provider_symbol("000001.SZ") == "000001.SZ"

def test_partial_result_preserves_success(capsys):
    exit_code = module.main(["AAPL.US", "BAD.US"], opener=fake_opener, now_ms=lambda: 1000)
    payload = json.loads(capsys.readouterr().out)
    assert exit_code == 0
    assert payload["state"] == "partial"
    assert payload["quotes"][0]["symbol"] == "AAPL.US"
    assert payload["errors"][0]["symbol"] == "BAD.US"
```

- [ ] **Step 2: Run tests and verify failure**

Run: `python -m unittest -v tests.test_longbridge_quotes`

Expected: FAIL because `longbridge-quotes` and its interfaces do not exist.

- [ ] **Step 3: Implement the executable helper**

Use `urllib.request.Request`, `urllib.request.urlopen`, `urllib.parse.quote`, `json`, and `decimal.Decimal`. Apply the exact suffix mapping in the spec, a 10-second timeout, a fixed user agent, one bounded chart request per symbol, per-symbol errors, and decimal strings. Do not import subprocess or access Longbridge files.

- [ ] **Step 4: Add Python tests to the validation target**

```make
test-python:
	python -m unittest -v tests.test_longbridge_quotes
```

Make `test` depend on `test-python` and ensure `longbridge-quotes` is executable.

- [ ] **Step 5: Run helper tests**

Run: `make test-python`

Expected: provider mapping, fixture parsing, partial/total failures, timeout, malformed payload, and safe diagnostics all PASS without network access.

- [ ] **Step 6: Commit**

```bash
git add longbridge-quotes tests/test_longbridge_quotes.py tests/fixtures/yahoo_chart.json Makefile
git commit -m "feat: add public watchlist quote helper"
```

### Task 2: Split quote and portfolio adapters/services

**Files:**
- Create: `QuoteAdapter.js`
- Create: `QuoteService.qml`
- Create: `PortfolioService.qml`
- Create: `tests/test_quote_adapter.js`
- Modify: `CliAdapter.js`
- Delete: `LongbridgeCli.qml`
- Modify: `tests/test_cli_adapter.js`
- Modify: `Makefile`

**Interfaces:**
- Consumes: helper envelope and Longbridge portfolio JSON.
- Produces: `QuoteAdapter.parse(text)`, `QuoteAdapter.helperCommand(path, symbols)`, `CliAdapter.portfolioCommand()`, quote events, and portfolio events.

- [ ] **Step 1: Write failing adapter isolation tests**

```javascript
assert.deepStrictEqual(QuoteAdapter.helperCommand("/plugin/longbridge-quotes", ["AAPL.US"]), ["/plugin/longbridge-quotes", "AAPL.US"])
assert.deepStrictEqual(CliAdapter.portfolioCommand(), ["longbridge", "portfolio", "--format", "json"])
assert.strictEqual(Object.prototype.hasOwnProperty.call(CliAdapter, "quoteCommand"), false)
```

Add parsing assertions for `ready`, `partial`, per-symbol errors, and malformed top-level envelopes.

- [ ] **Step 2: Run tests and verify failure**

Run: `node --test tests/test_quote_adapter.js tests/test_cli_adapter.js`

Expected: FAIL because the quote adapter does not exist and CLI quote construction still exists.

- [ ] **Step 3: Implement adapters**

Move quote-envelope parsing into `QuoteAdapter.js`, keep canonical symbols and decimal strings, and remove all quote command/parsing code from `CliAdapter.js`. Preserve only portfolio parsing and safe CLI error classification.

- [ ] **Step 4: Implement independent services**

`QuoteService.qml` resolves `longbridge-quotes` relative to itself, refreshes on open/watchlist changes/manual requests/five-minute timer, coalesces concurrent refreshes, and emits snapshot/error events. `PortfolioService.qml` runs only the exact portfolio command on active-tab/manual/60-second triggers.

- [ ] **Step 5: Add and run source isolation checks**

Run:

```bash
test "$(rg -n '\["longbridge", "portfolio", "--format", "json"\]' -g '*.qml' -g '*.js' | wc -l)" -eq 1
! rg -n 'longbridge.*quote|quoteCommand' -g '*.qml' -g '*.js'
```

Expected: one portfolio command and no Longbridge quote command.

- [ ] **Step 6: Run JavaScript tests**

Run: `node --test tests/test_quote_adapter.js tests/test_cli_adapter.js tests/test_model.js tests/test_portfolio_model.js`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add QuoteAdapter.js QuoteService.qml PortfolioService.qml CliAdapter.js tests/test_quote_adapter.js tests/test_cli_adapter.js Makefile
git rm LongbridgeCli.qml
git commit -m "refactor: isolate public quotes from portfolio CLI"
```

### Task 3: Mandatory setup and welcome page

**Files:**
- Create: `SetupAdapter.js`
- Create: `components/LongbridgeSetup.qml`
- Create: `tests/test_setup_adapter.js`
- Create: `tests/test_setup_source.sh`
- Modify: `Makefile`

**Interfaces:**
- Produces: availability command, install command, login command, check command, parsed setup states, and `setupComplete` signal/property.

- [ ] **Step 1: Write failing setup command tests**

```javascript
assert.deepStrictEqual(SetupAdapter.availabilityCommand(), ["sh", "-lc", "command -v longbridge"])
assert.deepStrictEqual(SetupAdapter.loginCommand(), ["longbridge", "auth", "login"])
assert.deepStrictEqual(SetupAdapter.checkCommand(), ["longbridge", "check", "--format", "json"])
assert.ok(SetupAdapter.installCommand().join(" ").includes("github.com/longbridge/longbridge-terminal/raw/main/install"))
```

Assert authenticated and unauthenticated `check` fixture classification.

- [ ] **Step 2: Run setup tests and verify failure**

Run: `node --test tests/test_setup_adapter.js`

Expected: FAIL because `SetupAdapter.js` does not exist.

- [ ] **Step 3: Implement setup adapter and QML state machine**

Implement states `checking`, `needs_install`, `installing`, `needs_login`, `logging_in`, `verifying`, `ready`, and `failed`. Opening the panel may check state but must never install or log in automatically. Render the official installer source before the install button. Disable actions while processes run. Recheck after child success.

- [ ] **Step 4: Add source-level mandatory-gate tests**

`tests/test_setup_source.sh` asserts no `Skip` text, exact official installer URL, exact login/check commands, and normal panel tabs gated by setup readiness.

- [ ] **Step 5: Run setup tests**

Run: `node --test tests/test_setup_adapter.js && bash tests/test_setup_source.sh`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add SetupAdapter.js components/LongbridgeSetup.qml tests/test_setup_adapter.js tests/test_setup_source.sh Makefile
git commit -m "feat: add mandatory Longbridge onboarding"
```

### Task 4: Compact watchlist components

**Files:**
- Create: `components/WatchlistRow.qml`
- Create: `components/WatchlistView.qml`
- Modify: `Model.js`
- Modify: `tests/test_model.js`
- Delete: `components/MarketGroup.qml`
- Delete: `components/QuoteTile.qml`

**Interfaces:**
- Consumes: normalized rows, selected index, loading/message state, and watchlist mutation signals.
- Produces: dense 44-unit rows, bounded list navigation, collapsed add mode, and selected quote detail.

- [ ] **Step 1: Extend failing model tests**

Assert flat watchlist order, per-symbol partial error reconciliation, preserved stale quote values, movement formatting, and canonical suffix display.

- [ ] **Step 2: Run model tests and verify failure**

Run: `node --test tests/test_model.js`

Expected: at least the new reconciliation assertions FAIL.

- [ ] **Step 3: Implement model behavior**

Add focused functions for helper snapshot/error application while retaining immutable updates and last-known values.

- [ ] **Step 4: Implement compact QML views**

Use a bounded `ListView` with `ScrollBar.AsNeeded`. Each delegate has `implicitHeight: Style.space(44)`, neutral hover/selection surfaces, symbol/name left, price/currency right, and rise/fall color only on percentage text. Add mode remains collapsed until requested.

- [ ] **Step 5: Run model and QML lint checks**

Run: `node --test tests/test_model.js && /usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell components/WatchlistRow.qml components/WatchlistView.qml`

Expected: tests PASS; lint exits successfully with only known unresolved `qs.*` environment warnings.

- [ ] **Step 6: Commit**

```bash
git add Model.js tests/test_model.js components/WatchlistRow.qml components/WatchlistView.qml
git rm components/MarketGroup.qml components/QuoteTile.qml
git commit -m "feat: add compact public watchlist"
```

### Task 5: Compact bounded portfolio holdings

**Files:**
- Create: `components/HoldingRow.qml`
- Modify: `components/PortfolioView.qml`
- Modify: `PortfolioModel.js`
- Modify: `tests/test_portfolio_model.js`

**Interfaces:**
- Consumes: normalized portfolio and service state.
- Produces: compact summary, bounded holding list, selected holding detail, refresh signal.

- [ ] **Step 1: Write failing portfolio detail tests**

Assert selected holding detail retains quantity, available quantity, market price, cost, total P/L, and currency for a 12-position fixture.

- [ ] **Step 2: Run tests and verify failure**

Run: `node --test tests/test_portfolio_model.js`

Expected: new fixture/detail assertions FAIL before normalization is extended.

- [ ] **Step 3: Extend portfolio normalization**

Preserve all detail fields as decimal strings and produce stable row identity/order.

- [ ] **Step 4: Implement compact holding UI**

Keep “All accounts” text-only. Render compact net assets/day gain and three neutral metrics. Use a bounded `ListView` with `implicitHeight: Style.space(44)` delegates and an internal scrollbar. Put quantity/cost/P/L detail only in the selected detail surface.

- [ ] **Step 5: Run tests and lint**

Run: `node --test tests/test_portfolio_model.js && /usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell components/HoldingRow.qml components/PortfolioView.qml`

Expected: PASS with only known import-context warnings.

- [ ] **Step 6: Commit**

```bash
git add components/HoldingRow.qml components/PortfolioView.qml PortfolioModel.js tests/test_portfolio_model.js
git commit -m "feat: compact portfolio holdings"
```

### Task 6: Panel composition and resource menu

**Files:**
- Create: `components/PanelMenu.qml`
- Create: `tests/test_panel_source.sh`
- Modify: `Panel.qml`
- Delete: `components/ConnectionBanner.qml`
- Modify: `Makefile`

**Interfaces:**
- Consumes: setup, quote, and portfolio services.
- Produces: mandatory welcome gate, compact tabs, bounded tab bodies, keyboard routing, and fixed-link menu.

- [ ] **Step 1: Write failing panel source tests**

Assert exact labels/URLs, three `xdg-open` actions, no `Exit`, no account logo, no status dot, 11-unit centered bar logo, sub-pixel open indicator suppression, setup gate, and separate service activation.

- [ ] **Step 2: Run source tests and verify failure**

Run: `bash tests/test_panel_source.sh`

Expected: FAIL because the menu and new composition do not exist.

- [ ] **Step 3: Implement `PanelMenu.qml`**

Use a neutral icon button and popup menu. Each fixed action calls `Quickshell.execDetached(["xdg-open", fixedUrl])`, then closes the popup. Include no other actions.

- [ ] **Step 4: Recompose `Panel.qml`**

Keep the centered 11-unit monochrome bar logo and indicator suppression. Show only `LongbridgeSetup` until ready. After readiness, instantiate/activate compact header, resource menu, tabs, `WatchlistView`, and `PortfolioView`. Remove the outer all-content Flickable so each long list owns scrolling.

- [ ] **Step 5: Run panel source tests and lint**

Run: `bash tests/test_panel_source.sh && /usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell Panel.qml components/PanelMenu.qml`

Expected: source tests PASS; lint exits successfully with only known import-context warnings.

- [ ] **Step 6: Commit**

```bash
git add Panel.qml components/PanelMenu.qml tests/test_panel_source.sh Makefile
git rm components/ConnectionBanner.qml
git commit -m "feat: compose compact Longbridge panel"
```

### Task 7: Installer, documentation, and completion audit

**Files:**
- Modify: `install.sh`
- Modify: `tests/test_install.sh`
- Modify: `README.md`
- Modify: `Makefile`

**Interfaces:**
- Produces: documented and tested Python/CLI requirements plus full acceptance suite.

- [ ] **Step 1: Extend failing installer tests**

Assert Python 3 is checked, the public helper is executable through the development symlink, missing CLI is explained as resolvable inside the welcome page, and installation does not run automatically from `install.sh`.

- [ ] **Step 2: Run installer tests and verify failure**

Run: `bash tests/test_install.sh`

Expected: new assertions FAIL.

- [ ] **Step 3: Update installer and README**

Document mandatory welcome setup, official install source, verified login, Yahoo-backed watchlist polling, Longbridge-backed portfolio, exact three resource links, compact list behavior, and privacy/error boundaries.

- [ ] **Step 4: Run the complete automated suite**

Run: `make validate`

Expected: Python, JavaScript, QML, shell, lint, and `omarchy plugin validate .` checks PASS.

- [ ] **Step 5: Prove runtime command isolation**

Run:

```bash
! rg -n 'longbridge.*quote|quoteCommand' -g '*.qml' -g '*.js' -g '*.py'
rg -n '\["longbridge", "portfolio", "--format", "json"\]' PortfolioService.qml
```

Expected: no watchlist CLI path and exactly one portfolio data command.

- [ ] **Step 6: Perform fixture visual acceptance**

Load empty, setup, populated watchlist, partial/stale watchlist, 12-holding portfolio, and error fixtures in the available QML/Omarchy runtime. Confirm panel height stays bounded, both lists scroll independently, rows are legible, and color/icon constraints hold. If the shell runtime is unavailable, record that limitation without claiming visual completion.

- [ ] **Step 7: Check scope and working tree**

Run: `git diff --check && git status --short`

Expected: no whitespace errors; only intentional changes remain.

- [ ] **Step 8: Commit**

```bash
git add install.sh tests/test_install.sh README.md Makefile
git commit -m "docs: finish compact Longbridge setup"
```
