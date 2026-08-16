# Longbridge CLI-Only Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the plugin-specific Rust helper with QML processes that consume `longbridge --format json` directly.

**Architecture:** `LongbridgeCli.qml` owns short-lived quote and portfolio processes. `CliAdapter.js` converts native CLI JSON into the existing quote and portfolio view models, while `Panel.qml` schedules polling only while relevant UI is open. The installed Longbridge CLI owns OAuth, API routing, quote enrichment, FX conversion, and portfolio calculations.

**Tech Stack:** QML, Quickshell `Process`, JavaScript, Bash, Node test runner, Omarchy plugin tooling

## Global Constraints

- No Rust source, Cargo manifest, helper binary, release download, or plugin-managed token storage remains.
- Commands resolve `longbridge` through `PATH` and always request `--format json`.
- Markets poll every 15 seconds while the panel is open; Portfolio polls every 60 seconds while selected and open.
- Errors shown in QML are credential-free and retain the last successful data.
- Plugin name is `Longbridge`; plugin ID is `longbridge.omarchy`.
- Do not use a git worktree.

---

### Task 1: Native CLI JSON adapters

**Files:**
- Create: `CliAdapter.js`
- Create: `tests/fixtures/quote.json`
- Create: `tests/fixtures/portfolio.json`
- Create: `tests/test_cli_adapter.js`
- Modify: `Makefile`

**Interfaces:**
- Consumes: JSON output from `longbridge quote ... --format json` and `longbridge portfolio --format json`.
- Produces: `parseQuotes(text) -> { ok, event?, error? }`, `parsePortfolio(text) -> { ok, event?, error? }`, and `classifyFailure(stderr, exitCode) -> { code, message }`.

- [ ] **Step 1: Write failing fixture-based tests**

Test literal CLI fixtures for quote field mapping, latest extended-hours price selection, portfolio overview and holding mapping, malformed top-level rejection, and authentication-safe errors.

- [ ] **Step 2: Verify the tests fail**

Run: `node --test tests/test_cli_adapter.js`
Expected: FAIL because `CliAdapter.js` does not exist.

- [ ] **Step 3: Implement the minimal adapter**

Parse only arrays/objects documented by the fixtures. Return existing internal event shapes: `{type:"snapshot", quotes:[...]}` and `{type:"portfolio", ...}`. Never include stderr in returned messages.

- [ ] **Step 4: Verify adapter and existing model tests pass**

Run: `node --test tests/test_cli_adapter.js tests/test_model.js tests/test_portfolio_model.js tests/test_protocol.js`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add CliAdapter.js tests/fixtures tests/test_cli_adapter.js Makefile
git commit -m "feat: adapt Longbridge CLI JSON"
```

### Task 2: QML CLI process bridge

**Files:**
- Create: `LongbridgeCli.qml`
- Create: `tests/test_cli_runner.sh`
- Modify: `Panel.qml`
- Delete: `QuoteBridge.qml`
- Delete: `PortfolioBridge.qml`
- Delete: `Protocol.js`
- Delete: `tests/test_protocol.js`

**Interfaces:**
- Consumes: watchlist, panel-open state, active tab, and `CliAdapter.js` functions from Task 1.
- Produces: `quoteEvent(var)`, `portfolioEvent(var)`, `quoteState`, `portfolioState`, `refreshQuotes()`, and `refreshPortfolio()`.

- [ ] **Step 1: Write a failing fake-CLI integration test**

Create a temporary executable named `longbridge` that records its arguments and returns fixture JSON. Exercise the runner entrypoints and assert exact argument sequences `quote AAPL.US 700.HK --format json` and `portfolio --format json`.

- [ ] **Step 2: Verify the integration test fails**

Run: `bash tests/test_cli_runner.sh`
Expected: FAIL because the CLI runner does not exist.

- [ ] **Step 3: Implement the QML bridge and panel polling**

Use separate quote and portfolio `Process` objects with `StdioCollector`. On successful exit, adapt stdout and emit an event. On failure, classify stderr without displaying it. Add 15-second quote and 60-second portfolio timers gated by panel visibility and selected tab.

- [ ] **Step 4: Remove obsolete NDJSON bridge files and verify**

Run: `bash tests/test_cli_runner.sh && make qml-check`
Expected: runner PASS; qml-check exits 0 with only known unresolved `qs.*` import warnings outside a live Omarchy shell.

- [ ] **Step 5: Commit**

```bash
git add LongbridgeCli.qml Panel.qml Makefile tests/test_cli_runner.sh
git rm QuoteBridge.qml PortfolioBridge.qml Protocol.js tests/test_protocol.js
git commit -m "feat: query Longbridge CLI from QML"
```

### Task 3: Remove Rust helper and simplify development installation

**Files:**
- Delete: `helper/`
- Delete: `scripts/longbridge-helper`
- Delete: `scripts/helper-release.env`
- Delete: `tests/test_launcher.sh`
- Modify: `install.sh`
- Modify: `.gitignore`
- Modify: `Makefile`

**Interfaces:**
- Consumes: installed `longbridge` and `omarchy` executables.
- Produces: `./install.sh [--no-restart]`, with no Cargo dependency.

- [ ] **Step 1: Write failing installer behavior tests**

Run `install.sh` with controlled `PATH` fixtures and assert it fails clearly when `longbridge` is absent, succeeds without Cargo when both required executables exist, validates the plugin, and creates the development symlink under a temporary `XDG_CONFIG_HOME`.

- [ ] **Step 2: Verify installer tests fail**

Run: `bash tests/test_install.sh`
Expected: FAIL because the existing installer requires Cargo.

- [ ] **Step 3: Simplify installer and build targets**

Remove Cargo build and helper tests from `install.sh` and `Makefile`. Check `longbridge` and `omarchy`, validate, link, rescan, enable, and optionally restart.

- [ ] **Step 4: Delete helper artifacts and verify**

Run: `bash tests/test_install.sh && make test`
Expected: all shell and JavaScript tests PASS without Cargo.

- [ ] **Step 5: Commit**

```bash
git add install.sh .gitignore Makefile tests/test_install.sh
git rm -r helper scripts tests/test_launcher.sh
git commit -m "refactor: remove plugin Rust helper"
```

### Task 4: Documentation and end-to-end validation

**Files:**
- Modify: `README.md`
- Modify: `NOTICE`
- Modify: `docs/superpowers/specs/2026-08-16-omarchy-longbridge-design.md`

**Interfaces:**
- Consumes: completed CLI-only plugin from Tasks 1-3.
- Produces: accurate install, login, polling, privacy, and limitations documentation.

- [ ] **Step 1: Update documentation**

Document `longbridge auth login`, PATH dependency, polling intervals, CLI-owned token storage, portfolio behavior, and removal of helper releases. Remove claims about WebSocket pushes and plugin-owned OAuth code.

- [ ] **Step 2: Run complete static verification**

Run: `make validate`
Expected: JavaScript and shell tests PASS, qml-check exits 0, `omarchy plugin validate .` succeeds, and `git diff --check` reports no errors.

- [ ] **Step 3: Run live read-only CLI checks**

Run: `longbridge quote AAPL.US --format json` and `longbridge portfolio --format json`.
Expected: valid JSON using the user's existing CLI login; do not retain or report account values.

- [ ] **Step 4: Run development install**

Run: `./install.sh --no-restart`.
Expected: plugin validates, links at `$XDG_CONFIG_HOME/omarchy/plugins/longbridge.omarchy`, and enables if the shell is running.

- [ ] **Step 5: Commit**

```bash
git add README.md NOTICE docs/superpowers/specs/2026-08-16-omarchy-longbridge-design.md
git commit -m "docs: document CLI-only Longbridge plugin"
```
