# Omarchy Longbridge Plugin Design

> Superseded by `2026-08-16-longbridge-cli-only-design.md`. The implemented plugin uses Longbridge Terminal as its sole data and authentication boundary and contains no Rust helper.

## Purpose

Build a publishable Omarchy Quattro bar-widget plugin that gives Longbridge users a fast, read-only view of real-time market quotes. The plugin shares OAuth credentials with `longbridge-terminal`, subscribes through the official Longbridge Rust SDK, and uses an original market-pulse interface rather than reproducing Stochi's chart-oriented watchlist.

The first release deliberately excludes positions, account balances, order entry, and trade operations. Its responsibility is authentication, watchlist management, live quote delivery, and clear connection/session state.

## Product identity

The plugin is a live market monitor, not a historical performance viewer.

- The bar widget shows connection health and the strongest current move in the watchlist.
- The compact panel groups instruments by market and emphasizes live price movement.
- A selected instrument opens an inline detail surface for session data.
- Authentication and connection recovery are first-class states.
- Historical period selectors, Yahoo Finance links, and per-row sparklines are omitted.

This gives the plugin a different information hierarchy, interaction model, data source, and visual language from Stochi while still following Omarchy's native `Panel` conventions.

## Repository layout

```text
manifest.json
Panel.qml
QuoteBridge.qml
Model.js
components/
  MarketGroup.qml
  QuoteTile.qml
  SymbolDetail.qml
  ConnectionBanner.qml
helper/
  Cargo.toml
  src/
    main.rs
    auth.rs
    secure_storage.rs
    region.rs
    stream.rs
scripts/
  longbridge-helper
tests/
README.md
LICENSE
NOTICE
```

QML remains responsible for presentation and persisted plugin settings. The Rust helper is responsible for all authentication, credential access, SDK contexts, subscriptions, and network behavior.

## Shared OAuth and token storage

The helper must extract the relevant production code from `../longbridge-terminal`, not reverse-engineer or independently approximate it. The extracted implementation keeps source attribution and preserves the CLI's behavior for:

- dynamic OAuth client registration;
- browser/device login behavior needed by the plugin;
- token refresh;
- region and data-center selection;
- `EncryptedFileTokenStorage`;
- legacy plaintext-token migration;
- file permission hardening;
- atomic token replacement.

Production credentials use the same files as `longbridge-terminal`:

```text
~/.longbridge/openapi/cli-registration
~/.longbridge/openapi/cli-auth
```

Staging uses the CLI's existing `cli-registration-staging` separation. The encrypted token remains compatible with the CLI's `LB\x01` envelope, AES-256-GCM encryption, HKDF-SHA256 machine-derived key, and serialized payload.

The plugin never copies tokens into its own configuration. QML never receives access tokens, refresh tokens, client secrets, registration credentials, or decrypted token payloads. Authentication data must not appear in process arguments, stdout, stderr, IPC status, or logs.

To prevent two applications from corrupting shared state, extracted writes remain atomic. The helper also watches the shared files and reconnects with newly written credentials when another process logs in, logs out, or refreshes. Any concurrency improvement required during extraction must remain file-format compatible and should be contributed back to `longbridge-terminal` rather than becoming a divergent storage implementation.

## Helper command contract

One executable exposes a narrow command interface:

```text
longbridge-helper auth status
longbridge-helper auth login
longbridge-helper auth logout
longbridge-helper stream SYMBOL...
longbridge-helper search QUERY
```

`auth status`, `auth login`, `auth logout`, and `search` produce one JSON result and exit. `stream` stays alive and writes newline-delimited JSON events. Each line is a complete object so QML can process partial reads safely.

Representative event types are:

```json
{"type":"connection","state":"connecting"}
{"type":"snapshot","quotes":[{"symbol":"AAPL.US","last":"232.14"}]}
{"type":"quote","symbol":"AAPL.US","last":"232.18","timestamp":1786861000}
{"type":"subscription","symbols":["AAPL.US","700.HK"]}
{"type":"error","code":"not_authenticated","message":"Connect your Longbridge account."}
```

Numeric market values stay as decimal strings across the Rust/JSON boundary to avoid floating-point corruption. `Model.js` converts only values needed for display calculations.

The stream starts with a snapshot for every requested symbol, subscribes to real-time quote pushes, and then updates individual symbols. A watchlist change restarts the helper with the new complete symbol set; the helper unsubscribes by terminating its SDK context. This simple lifecycle avoids a second writable command channel and is sufficient for the small first-release watchlist.

## Connection lifecycle

The QML bridge owns exactly one streaming `Process`.

1. It checks authentication when loaded or opened.
2. When authenticated and the watchlist is non-empty, it starts `stream`.
3. The helper initializes the OAuth-backed quote context, fetches snapshots, subscribes, and emits connection state.
4. QML applies each event to an immutable symbol map and derives ordered market groups.
5. On unexpected exit, QML shows stale data with a disconnected state and retries with bounded exponential backoff.
6. Opening the panel or changing the watchlist triggers an immediate retry.
7. Intentional shutdown, logout, or an empty watchlist does not retry.

Only the helper refreshes credentials while its stream is active. If `longbridge-terminal` changes the token concurrently, the helper detects the file change and rebuilds its context. Quote rows retain their last timestamp so stale data is visually explicit.

## Interface design

### Bar widget

The bar control uses a pulse/radio-wave mark rather than Stochi's chart icon. Its state is visible through a small accent dot:

- accent: connected and receiving data;
- dim: market data connected but idle/closed session;
- warning: reconnecting or partially subscribed;
- urgent: authentication or connection failure.

The tooltip reports connection state, watched-symbol count, and update age. It never cycles through miniature stock charts.

### Compact panel

The main panel is a market board. US, HK, CN, and SG instruments appear in labeled groups, with only groups represented by the watchlist rendered. Each quote tile contains:

- symbol and localized security name;
- last price and currency;
- absolute and percentage move;
- a vertical direction rail whose color follows the configured market color convention;
- trade-session badge and live-update pulse;
- stale or per-symbol error state.

The board supports arrow keys or `J`/`K` for selection, Enter for inline detail, `A` to add a symbol, `X` to remove the selected symbol, `R` to reconnect, and Escape to back out or close.

### Symbol detail

Selecting a tile replaces the board body with a focused, reversible detail surface. It shows last price, previous close, open, session high/low, volume, timestamp, trade session, and subscription health. It does not open Yahoo Finance or imitate Stochi's expanded management view.

### Onboarding and management

An unauthenticated panel explains that credentials are shared with Longbridge Terminal and offers **Connect Longbridge**. Login is run by the helper, which opens the authorization URL through the desktop browser while QML shows progress and cancel/retry affordances.

Authenticated users add instruments through a compact search command backed by Longbridge. Search results use canonical Longbridge symbols such as `AAPL.US` and `700.HK`. Watchlist edits are persisted through Omarchy's plugin settings API and capped at 20 symbols for predictable subscription and layout behavior.

## Manifest and packaging

The root `manifest.json` uses the current Omarchy schema, declares a single `bar-widget` entry point, uses `Longbridge` as its display name, and uses `longbridge.omarchy` as its stable plugin ID. The `longbridge` namespace follows the repository's `longbridge/omarchy-longbridge` GitHub publisher identity.

The repository is installable with `omarchy plugin add <git-url> --enable` and validates with `omarchy plugin validate`. The helper launcher resolves relative to the plugin directory. Packaging must not assume the sibling `longbridge-terminal` checkout exists on user machines.

The helper source is included for auditability and reproducible builds. Tagged GitHub releases publish a Linux x86-64 helper artifact and checksum. The repository's launcher resolves the plugin version, downloads the matching artifact into the user's XDG cache on first use, verifies its embedded SHA-256 checksum before execution, and reuses it thereafter. A missing network connection or checksum mismatch produces a visible setup error and never executes an unverified file. Contributors can point the launcher at a local debug build through a development-only environment override. Users do not need Rust, the sibling CLI checkout, or a system-wide helper installation.

Copied or adapted Apache-2.0 code retains required notices. Repository licensing must remain compatible with the extracted source, and `NOTICE` identifies Longbridge Terminal as the source of the authentication and secure-storage implementation.

## Error handling

Errors are stable codes plus safe user-facing messages. Important states include:

- helper missing or incompatible;
- not authenticated;
- login cancelled or timed out;
- token decryption failed after machine-ID change;
- token refresh failed;
- network offline;
- WebSocket disconnected/reconnecting;
- symbol rejected or quote entitlement unavailable;
- partial subscription failure;
- malformed helper output.

The panel preserves last-known quotes during transient failures and clearly marks them stale. Authentication failures stop automatic retry until credentials change or the user chooses Connect. Network failures retry with bounded exponential backoff and jitter. No error path logs secrets or raw OAuth responses.

## Testing and verification

### Rust helper

- Unit tests for extracted encrypted storage using fixtures compatible with the CLI.
- Cross-compatibility tests: a token fixture written by CLI code loads in the plugin helper, and helper output loads in CLI code.
- Tests for legacy migration, permissions, atomic writes, and corrupted/tampered ciphertext.
- Event-serialization and decimal-preservation tests.
- Mocked stream tests for snapshot, pushes, reconnect, partial subscription errors, and graceful shutdown.
- Secret-leak scans over stdout/stderr fixtures.

### QML and JavaScript

- Model tests for canonical symbols, market grouping, immutable quote reconciliation, sorting, stale state, and keyboard selection.
- Bridge parser tests for split lines, multiple events per read, malformed lines, and process restarts.
- IPC status exposes operational state without credentials.
- QML lint/load checks against the installed Omarchy shell APIs.

### Plugin acceptance

- `omarchy plugin validate` passes.
- Installation from a clean clone succeeds through the documented command.
- OAuth login in either this plugin or `longbridge-terminal` is recognized by the other.
- Live quote pushes update the visible row without polling.
- Logout and token refresh propagate safely between both applications.
- The panel is visually inspected in unauthenticated, connecting, live, stale, error, empty, compact-board, and symbol-detail states.
- README documents installation, shared credential behavior, permissions, limitations, update/removal, and non-affiliation.

## Success criteria

The feature is complete when a clean Omarchy user can install and enable the repository, connect a Longbridge account or reuse an existing CLI login, add canonical Longbridge symbols, receive genuine real-time quote pushes, recover intelligibly from connection failures, and manage the watchlist in an interface that is recognizably different from Stochi. Compatibility is proven against the actual CLI storage implementation, not merely against a separately written description of its format.
