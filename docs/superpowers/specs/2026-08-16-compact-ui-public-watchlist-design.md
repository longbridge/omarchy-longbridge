# Compact UI and Public Watchlist Design

## Goal

Redesign the Longbridge Omarchy panel for dense watchlist and portfolio scanning. Watchlist prices come from a bundled public-market-data fetcher and must never invoke the `longbridge` executable. Portfolio data continues to come from `longbridge portfolio --format json` so account information remains consistent with Longbridge Terminal.

## Product boundaries

The plugin remains read-only and QML-based. It contains no Rust code, does not read or copy Longbridge credentials, and does not place orders. The bundled watchlist helper uses Python 3's standard library and requires no third-party packages. Longbridge Terminal installation and verified login are mandatory onboarding requirements, but only the Portfolio tab uses the CLI as a runtime data source.

The panel uses the name `Longbridge` and plugin ID `longbridge.omarchy`. Bar and item icons are monochrome. The official color logo may appear in the main panel header, but not beside the Portfolio tab's “All accounts” heading. Red and green are reserved for numeric or textual fall/rise values; surfaces, borders, selection, and icons stay neutral.

## Runtime architecture

`QuoteService.qml` owns watchlist refresh lifecycle and launches a repository-local executable Python helper named `longbridge-quotes`. It resolves the helper relative to the installed plugin instead of relying on `PATH`. The helper fetches public Yahoo Finance chart data over HTTPS and prints one JSON document to stdout. It never runs `longbridge`, reads token storage, or receives credentials.

`PortfolioService.qml` owns portfolio refresh lifecycle and is the only component permitted to launch `longbridge`. Its command is exactly:

```text
longbridge portfolio --format json
```

The two services expose separate loading, update-time, message, and error states. Selecting or refreshing one tab does not start the other service. This separation is enforced by source-level and command-construction tests.

`LongbridgeSetup.qml` owns a mandatory first-run welcome flow and the explicit CLI installation and authentication actions. The panel checks executable availability before exposing its normal tabs. When the CLI is missing, the welcome page explains the requirement and offers an **Install Longbridge CLI** button. Clicking the button runs the official installer; installation never starts automatically. After the executable becomes available, the welcome page offers **Log in to Longbridge**, runs `longbridge auth login`, and confirms the resulting session with `longbridge check --format json`.

There is no skip action. The Watchlist and Portfolio tabs remain hidden until both CLI availability and authenticated-session verification succeed. This setup gate does not make the CLI a watchlist data source: after onboarding, every watchlist refresh still launches only the bundled public-data helper. If authentication later expires, the panel returns to the welcome flow until login is verified again.

## Watchlist helper contract

The helper accepts canonical plugin symbols as positional arguments:

```text
longbridge-quotes AAPL.US 700.HK D05.SG
```

It maps supported Longbridge-style suffixes to Yahoo symbols without changing persisted settings:

| Plugin symbol | Provider symbol |
| --- | --- |
| `AAPL.US` | `AAPL` |
| `700.HK` | `0700.HK` |
| `D05.SG` | `D05.SI` |
| `600519.SH` | `600519.SS` |
| `000001.SZ` | `000001.SZ` |

US symbols drop `.US`. Numeric Hong Kong tickers are left-padded to four digits. Singapore `.SG` becomes `.SI`, and Shanghai `.SH` becomes `.SS`. Unknown or malformed suffixes produce a per-symbol error rather than a guessed mapping.

The helper sends a bounded request per symbol to Yahoo's chart endpoint, with an explicit user agent and timeout. Sequential requests keep the implementation deterministic and the configured watchlist remains capped at 20 entries. A failed symbol does not discard successful symbols.

Stdout uses this stable envelope:

```json
{
  "state": "partial",
  "fetched_at_ms": 1786861000000,
  "quotes": [
    {
      "symbol": "AAPL.US",
      "name": "Apple Inc.",
      "currency": "USD",
      "last": "232.18",
      "prev_close": "231.20",
      "open": "231.85",
      "high": "233.10",
      "low": "230.90",
      "volume": "41230000",
      "timestamp": 1786861000,
      "trade_status": "REGULAR",
      "trade_session": "Intraday"
    }
  ],
  "errors": [
    {"symbol": "BAD.US", "code": "not_found", "message": "Quote unavailable."}
  ]
}
```

`state` is `ready` when every requested symbol succeeds, `partial` when at least one succeeds and at least one fails, and `error` when none succeeds. Decimal market values are serialized as strings. Stderr contains only short diagnostic summaries and no full upstream response bodies.

## Refresh and state behavior

The watchlist refreshes when the panel opens, after the persisted watchlist changes, on explicit refresh, and every five minutes while the panel is open. Concurrent requests coalesce into one queued refresh. Successful results reconcile by canonical plugin symbol so a partial response preserves the last successful value for failed symbols while marking those rows stale or unavailable.

The Portfolio tab refreshes when first selected while the panel is open, on explicit refresh, and every 60 seconds while selected. It does not poll while hidden. Its last successful snapshot remains visible after command, authentication, or network failure.

Neither tab claims real-time streaming. Update ages and refresh actions communicate the polling model. The bar icon has no status dot and the plugin suppresses Omarchy's panel-open underline.

## Compact panel layout

The panel targets a fitted width of 390 Omarchy spacing units and a maximum fitted height of 620. A shallow header contains the official in-panel logo, plugin name, concise status text, and refresh action. A compact two-tab switch follows it. Controls use neutral theme colors.

### Watchlist tab

The watchlist body uses a bounded `ListView` rather than placing every row in the outer content column. Each row is 44 spacing units high and contains:

- symbol and short security name on the left;
- last price and currency on the right;
- percentage movement as the only red/green element;
- a small neutral stale/error label when necessary.

Market group headings are omitted from the dense list because they consume vertical space and interrupt scanning. Market identity remains available through the canonical suffix. Selecting a row reveals a compact detail block below or in place of the list with OHLC, volume, session, timestamp, and remove action. The add-symbol field is collapsed behind an `Add` action when not in use. Keyboard selection and add/remove/refresh shortcuts remain supported.

### Portfolio tab

The Portfolio tab starts with the text-only “All accounts” heading and update age. It does not show an account icon. Net assets and today's gain form a compact summary, followed by three small neutral metric cells for cash, market value, and position count.

Holdings render in a bounded `ListView` that receives the majority of remaining panel height and owns its scrollbar. The summary never scrolls away during ordinary holding-list navigation. Each 44-unit holding row shows symbol and truncated name on the left, market value on the right, and today's monetary movement beneath it. Only the movement value uses rise/fall color.

Selecting a holding opens a compact detail surface containing quantity, available quantity, market price, average cost, total P/L, and currency. These fields are omitted from normal rows so dozens of holdings remain quickly scannable. Empty, loading, stale, and command-failure states occupy the list body without expanding the panel. Missing-CLI and unauthenticated states return to the mandatory welcome flow.

## Error handling

The watchlist distinguishes helper missing, Python unavailable, network failure, invalid provider response, unsupported symbol mapping, and quote-not-found. User-facing text stays concise. Existing values remain visible with stale state after transient failures. A partial response marks only affected symbols.

The Portfolio service distinguishes missing `longbridge`, unauthenticated CLI, malformed portfolio output, and general command failure. Missing or unauthenticated results send the panel back to the corresponding welcome step. Raw stderr is classified but never displayed verbatim.

CLI installation and login have explicit `idle`, `running`, `succeeded`, and `failed` states. Buttons are disabled while their process is running, and progress copy explains which action is active. A failed install returns to the install action; a cancelled or failed login returns to the login action. After either success, the setup component rechecks executable availability and authentication rather than trusting only the child process exit code. The normal tab content is not instantiated or activated before verification. No setup action closes or disables the plugin, there is no skip action, and there is no exit menu.

## Files and component boundaries

- `longbridge-quotes`: provider mapping, HTTPS requests, upstream parsing, stable JSON output.
- `QuoteService.qml`: helper process lifecycle, polling, refresh coalescing, and QML-facing quote state.
- `PortfolioService.qml`: Longbridge CLI lifecycle and portfolio state.
- `components/LongbridgeSetup.qml`: mandatory welcome page, CLI availability, explicit official installation, login, and authenticated-session verification.
- `QuoteAdapter.js`: validates and adapts the public-helper envelope.
- `CliAdapter.js`: contains portfolio-only parsing and command construction; quote CLI construction is removed.
- `components/WatchlistView.qml`: compact list, add mode, selection, and quote detail composition.
- `components/WatchlistRow.qml`: one dense quote row.
- `components/PortfolioView.qml`: compact account summary, bounded holding list, and detail state.
- `components/HoldingRow.qml`: one dense holding row.
- `Panel.qml`: tab composition, shared header, keyboard routing, and service activation only.

Components receive normalized view models and do not parse provider or CLI payloads. Service components do not own presentation.

## Installation

`install.sh` keeps the development symlink workflow. It verifies that Python 3 exists for the watchlist helper and explains that Longbridge Terminal is required for Portfolio. The repository installer does not install external dependencies automatically.

Inside the panel, the user-triggered **Install Longbridge CLI** action runs the official installer command exactly as documented by Longbridge:

```sh
curl -sSL https://github.com/longbridge/longbridge-terminal/raw/main/install | sh
```

Because the command downloads and executes software, the panel displays the exact source and explains what will happen before the user clicks. The process receives no plugin data or credentials. Login is a separate explicit action after installation.

## Testing and verification

Python tests cover every suffix mapping, numeric Hong Kong padding, malformed symbols, valid chart parsing, missing metadata, HTTP failure, timeout, partial success, total failure, decimal-string output, and diagnostic safety. Network behavior is tested with injected fixture responses; automated tests do not contact Yahoo or Longbridge.

JavaScript tests cover helper-envelope validation, partial reconciliation, stale preservation, and existing portfolio adaptation. Command tests prove that watchlist refresh resolves only `longbridge-quotes` and that the only `longbridge` command in runtime source is the exact portfolio command.

QML tests or deterministic source checks cover 44-unit rows, bounded list views, account-icon absence, monochrome bar treatment, and suppressed dot/underline decorations. `qmllint`, `omarchy plugin validate .`, installer tests, Python tests, JavaScript tests, and `git diff --check` form the automated acceptance suite.

Setup tests use fake `curl`, shell, and `longbridge` executables to cover missing CLI, explicit installation, installer failure, login success, login cancellation/failure, and post-login verification. They assert that opening the panel alone never starts installation or login, that no skip control exists, that normal tabs remain unavailable before verified login, and that post-onboarding watchlist refreshes never execute `longbridge`.

Visual acceptance inspects both tabs at empty, loading, populated, partial/stale, and error states. A populated fixture must demonstrate that at least twelve holdings remain navigable without increasing the panel beyond its maximum height.

## Completion criteria

The redesign is complete when mandatory onboarding prevents use until the official CLI is explicitly installed and login is verified; the watchlist can then load supported symbols without executing `longbridge`; Portfolio still loads through the exact Longbridge CLI command; both tabs preserve last-known data through failures; the holding list remains bounded and usable with many entries; all color and icon constraints are satisfied; installation documents both runtime requirements; and automated plus visual verification pass.
