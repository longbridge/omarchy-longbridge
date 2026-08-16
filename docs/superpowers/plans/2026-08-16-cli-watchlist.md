# Longbridge CLI Watchlist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the public/local watchlist with read-only authenticated Longbridge groups and Longbridge quote prices, while fixing exact header centering.

**Architecture:** `WatchlistService.qml` runs `longbridge watchlist --format json`, preserves all groups, then runs `longbridge quote … --format json` for the active group. `CliAdapter.js` validates both payloads; `Model.js` merges membership and quotes. The compact QML view exposes a group dropdown and refresh only.

**Tech Stack:** Qt 6/QML, Quickshell Process, JavaScript adapters/models, Node test runner, shell source tests.

## Global Constraints

- Watchlist membership and prices come only from Longbridge CLI.
- All returned groups remain available; default is the case-insensitive `all` group.
- Empty `holdings` remains selectable.
- The watchlist is read-only: no Add/Remove controls, shortcuts, or remote mutation commands.
- Portfolio command remains exactly `longbridge portfolio --format json`.
- Header logo, title, and menu share a fixed container and exact vertical center.
- Compact 44-unit rows, square segmented main tabs, color rules, mandatory onboarding, and fixed resource links remain unchanged.

---

### Task 1: CLI watchlist and quote adapters

**Files:**
- Create: `tests/fixtures/watchlist.json`
- Modify: `tests/test_cli_adapter.js`
- Modify: `CliAdapter.js`

**Interfaces:**
- Produces: `watchlistCommand()`, `quoteCommand(symbols)`, `parseWatchlist(text)`, and `parseQuotes(text)`.

- [ ] **Step 1: Write failing adapter tests**

Assert exact commands, all-group default ID, every group in source order, empty holdings preservation, pinned/name/market fields, `.SPX.US` acceptance, missing/duplicate-all rejection, and CLI quote snapshot parsing.

- [ ] **Step 2: Run tests and observe failure**

Run: `node --test tests/test_cli_adapter.js`

Expected: FAIL because watchlist/quote interfaces are absent.

- [ ] **Step 3: Implement minimal parsing and commands**

Validate the real CLI array shape, normalize group IDs as strings, preserve security order, and adapt the existing Longbridge quote response including newest extended-hours values.

- [ ] **Step 4: Run adapter tests**

Run: `node --test tests/test_cli_adapter.js`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add CliAdapter.js tests/test_cli_adapter.js tests/fixtures/watchlist.json
git commit -m "feat: parse Longbridge watchlist groups"
```

### Task 2: Sequential watchlist service and model

**Files:**
- Create: `WatchlistService.qml`
- Modify: `Model.js`
- Modify: `tests/test_model.js`
- Delete: `QuoteService.qml`
- Delete: `QuoteAdapter.js`
- Delete: `tests/test_quote_adapter.js`

**Interfaces:**
- Consumes: parsed groups, active group ID, and parsed quote snapshots.
- Produces: `groups`, `activeGroupId`, `activeSecurities`, loading/state/message, and merged rows.

- [ ] **Step 1: Write failing model tests**

Assert group/security order, default all selection, empty holdings switching, selected-group disappearance returning to all, watchlist names overriding quote names, and index symbols remaining visible.

- [ ] **Step 2: Run tests and observe failure**

Run: `node --test tests/test_model.js`

Expected: FAIL because group state does not exist.

- [ ] **Step 3: Implement group-aware model**

Add immutable `applyGroups`, `selectGroup`, `activeGroup`, and membership-aware quote reconciliation without the old local validator filtering CLI symbols.

- [ ] **Step 4: Implement sequential service**

Run the watchlist process first. On success update groups, then run quotes for active securities. Switching groups runs only the quote process. Refresh runs both stages. Empty groups skip quotes. Preserve last successful state on failure and coalesce refreshes.

- [ ] **Step 5: Run model tests and source isolation**

Run:

```bash
node --test tests/test_model.js
rg -n '\["longbridge", "watchlist", "--format", "json"\]' CliAdapter.js
rg -n '\["longbridge", "quote"' CliAdapter.js
```

Expected: tests PASS and exact commands exist only in the CLI adapter.

- [ ] **Step 6: Commit**

```bash
git add WatchlistService.qml Model.js tests/test_model.js QuoteService.qml QuoteAdapter.js tests/test_quote_adapter.js
git commit -m "feat: load authenticated Longbridge watchlist"
```

### Task 3: Read-only group-filter UI and centered header

**Files:**
- Modify: `components/WatchlistView.qml`
- Modify: `components/SymbolDetail.qml`
- Modify: `Panel.qml`
- Modify: `tests/test_panel_source.sh`
- Modify: `tests/test_setup_source.sh`
- Modify: `Makefile`

**Interfaces:**
- Consumes: groups, active group ID, rows, and service refresh/select actions.
- Produces: compact group dropdown, read-only details, and fixed centered header.

- [ ] **Step 1: Write failing source tests**

Assert `Dropdown` group control, no Add/Remove text or mutation signals, no A/X keyboard handlers, `WatchlistService`, fixed header `Item`, and vertical-center anchors on logo/title/menu.

- [ ] **Step 2: Run source tests and observe failure**

Run: `bash tests/test_panel_source.sh`

Expected: FAIL on old controls/service/header.

- [ ] **Step 3: Implement read-only group UI**

Place a compact `Dropdown` beside a ghost refresh icon. Bind options to every group and select by ID. Remove add mode, local persistence, remove actions, and shortcuts. Retain selected quote detail with Back only.

- [ ] **Step 4: Implement fixed header geometry**

Use a 28-unit `Item`; anchor logo left/center, menu right/center, and title between them at the same vertical center.

- [ ] **Step 5: Run UI tests and lint**

Run: `bash tests/test_panel_source.sh && make qml-check`

Expected: source tests PASS; lint exits 0 with only known standalone `qs.*` context warnings.

- [ ] **Step 6: Commit**

```bash
git add components/WatchlistView.qml components/SymbolDetail.qml Panel.qml tests/test_panel_source.sh tests/test_setup_source.sh Makefile
git commit -m "feat: add read-only watchlist group filter"
```

### Task 4: Remove public provider and complete migration

**Files:**
- Delete: `longbridge-quotes`
- Delete: `tests/test_longbridge_quotes.py`
- Delete: `tests/fixtures/yahoo_chart.json`
- Modify: `install.sh`
- Modify: `tests/test_install.sh`
- Modify: `README.md`
- Modify: `manifest.json`
- Modify: `Makefile`

**Interfaces:**
- Produces: CLI-only runtime/docs and final acceptance evidence.

- [ ] **Step 1: Write failing cleanup assertions**

Assert install requires `longbridge`, no Python/Yahoo helper references remain, README documents groups/read-only behavior, and only welcome-page actions can install the CLI.

- [ ] **Step 2: Run installer/source tests and observe failure**

Run: `bash tests/test_install.sh && bash tests/test_panel_source.sh`

Expected: FAIL while public-helper requirements remain.

- [ ] **Step 3: Remove provider artifacts and update installation/docs**

Restore the CLI prerequisite in `install.sh`, remove Python targets/files, and document real Longbridge groups and prices.

- [ ] **Step 4: Run full validation**

Run: `make validate`

Expected: all JavaScript, QML, shell, lint, plugin validation, and diff checks PASS.

- [ ] **Step 5: Run live acceptance**

Run `longbridge watchlist --format json`, then quote at least one returned active-group symbol. Reload the development-linked shell and inspect `all` plus `holdings`, including empty-group state and centered header.

- [ ] **Step 6: Commit**

```bash
git add -A longbridge-quotes tests/test_longbridge_quotes.py tests/fixtures/yahoo_chart.json install.sh tests/test_install.sh README.md manifest.json Makefile
git commit -m "refactor: finish CLI watchlist migration"
```
