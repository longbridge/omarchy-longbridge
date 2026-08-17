# Longbridge for Omarchy

A compact Omarchy watchlist and Longbridge portfolio panel.

The Watchlist loads your authenticated Longbridge groups and streams live prices over `longbridge serve`. The Portfolio tab uses Longbridge Terminal for account data.

![Longbridge watchlist panel](assets/longbridge-panel.png)

## Requirements

- Omarchy
- Longbridge Terminal available on `PATH`, new enough to provide `longbridge serve` (check with `longbridge serve --help`)
- Internet access

Longbridge Terminal and a verified login are mandatory before the normal panel opens. The plugin welcome page verifies installation and login, and can guide recovery. There is no skip action.

## Install

Add and enable the plugin:

```bash
omarchy plugin add https://github.com/longbridge/omarchy-longbridge.git --enable
```

Open Longbridge from the bar. The welcome page will:

1. Check whether Longbridge Terminal is installed.
2. Link to the official Longbridge CLI installation guide when it is missing.
3. Offer **Log in to Longbridge** after installation.
4. Verify the session with `longbridge check --format json`.

The plugin does not download or execute an installer. Use the [Longbridge CLI installation guide](https://open.longbridge.com/docs/cli/install) to install it and for troubleshooting.

For development, symlink this checkout into Omarchy:

```bash
./install.sh
```

Use `./install.sh --no-restart` to leave the current shell running. This script validates and links the plugin; it never installs Longbridge Terminal automatically.

## Watchlist

While the panel is open the plugin runs one long-lived

```text
longbridge serve
```

process and talks newline-delimited JSON-RPC 2.0 to it over stdin and stdout. That process authenticates and opens the market WebSocket once, so the panel gets a single connection instead of a new CLI launch per refresh.

The last watchlist state — groups, the selected group, and the most recent quote for each symbol — is written to `<quickshell cache>/longbridge/watchlist.json` and read back at shell start. A restart therefore paints the previous rows in a few milliseconds and refreshes them in the background, instead of showing an empty panel while the session starts. Rows older than five minutes carry the usual stale marker until the live data lands, and a cache that is missing, unreadable, or from an older format is ignored rather than trusted.

Starting that session is the slow part — about 1.5 seconds, nearly all of it process start, authentication and the WebSocket handshake, against roughly 150ms for the requests that follow. So closing the panel parks the session rather than killing it: the process and its subscriptions stay live for ten minutes, and a reopen inside that window shows prices immediately, with the quotes that arrived while the panel was closed already buffered. After ten idle minutes the process is stopped, and `serve` also exits on stdin EOF, so it never outlives the shell.

Groups come from `quote.watchlist`; the dropdown includes `all`, `holdings`, and custom groups in Longbridge order. The selected group is read-only; edit membership in Longbridge Terminal or another Longbridge client.

`holdings` is a special case: the watchlist API always returns that group empty, because its members are the account's own positions. It is filled from `trade.stock_positions`, which is how Longbridge Terminal fills it too (`src/tui/systems/watchlist.rs`).

Prices for the selected group come from `quote.quote`, with `quote.static_info` supplying each security's currency. That snapshot exists only to establish what a push cannot carry — name, currency and the session's previous close. From then on the panel calls `quote.subscribe` and lives on the `quote.updated` notifications the server pushes.

Nothing polls. There is no refresh button and no update interval; a request is made only when something happens:

- the panel opens, or the Watchlist tab is selected,
- the session reconnects, having dropped its subscriptions,
- a group is selected, changing which symbols are on screen,
- a symbol crosses into another trading session, which is the one thing a push cannot describe on its own, since it carries no previous close.

Pushes are folded per symbol and applied every 500ms — a render tick, not a fetch — so a fast-moving group repaints twenty times a minute instead of once per notification. A `LIVE` indicator sits where a refresh button would be — a green dot while the feed is streaming, dimmed and labelled `CONNECTING` or `OFFLINE` otherwise: the panel either has a live subscription or says why it does not.

Rows are ordered the way Longbridge Terminal orders them (`src/data/watchlist.rs`): symbols in their normal trading session first, then by market — US, HK, Shanghai and Shenzhen, Singapore — and stable within a key, so equal rows keep the order Longbridge returned rather than picking up an alphabetical tiebreaker. A symbol whose market opens therefore rises to the top on its own. Failures retain the last available membership and prices, and a dropped server is restarted with backoff.

A filter sits beside the group dropdown as a search button, expanding into a box at the same height when clicked or when `/` or `F` is pressed. It narrows the loaded group as you type, and closes again when you click elsewhere with nothing typed — a live filter stays open, so a short list always shows its reason. Matching is case-insensitive across both symbol and name, so `tsm`, `TSM.US` and `taiwan` all reach the same row. Filtering is display-only — every symbol in the group stays subscribed — and the count line reads `12 of 54 symbols` while a filter is active. `Esc` or the `✕` inside the box clears it.

The list is keyed by symbol, so a price tick updates the rows in place rather than rebuilding them. Handing a fresh row array to the list on every push destroyed and recreated every delegate twice a second, which flickered the charts and jumped the scroll position while charts were still loading.

Each 44-unit row carries an intraday sparkline in its own fixed column, drawn from sixty five-minute closes (`quote.candlesticks`) in the row's own rise or fall colour, with a dashed rule at the previous close — the level the percentage beside it is measured against. The forming bar tracks the live price, so the line moves with the number. A row asks for its own chart the first time it is drawn and no more than three requests are in flight at once, so a group of hundreds only fetches what the list actually shows. Rows restored from the cache ask before the session has started, so that queue waits for the session rather than being spent against a server that is not running yet; the selected row's detail draws the same series full width.

Each 44-unit row shows the symbol, name, price and percentage movement, plus a clock glyph when the last tick is over five minutes old. Currency is not repeated per row — the market is already in the symbol — and appears with the price in the detail view, which also carries OHLC, volume, session and timestamp. Pushed updates are folded per symbol and applied every 500ms, so prices stay current without repainting the list on every tick.

## Portfolio

Portfolio runs exactly:

```text
longbridge portfolio --format json
```

Positions, cash and the account overview stay on the CLI: `serve` returns raw OpenAPI payloads, and this aggregation — cross-currency totals, day and total P/L — has no JSON-RPC equivalent.

Prices do not. The holdings are registered on the same quote feed as the watchlist, so market value, day P/L and total P/L move with the market between snapshots. A row is repriced in its own currency; the summary re-totals through the rate implied by each holding's `market_value` and `market_value_usd` pair, which the snapshot already carries, so no exchange-rate lookup has to be kept fresh. The snapshot itself is re-read when the tab is opened or the session reconnects — never on a timer.

Total assets is the headline, with the live indicator beside it. Today's P/L and total P/L take a line of their own at full precision, over an allocation bar by market and cash, then cash, market value, risk level and credit limit. Holdings use a bounded list with its own scrollbar. Each 44-unit row shows market value and today's movement; quantity, available quantity, market price, average cost, total P/L, and currency appear in selected-row detail.

## Resource menu

The top-right menu opens:

- [Longbridge](https://longbridge.com)
- [Longbridge CLI](https://open.longbridge.com/docs/cli/)
- [GitHub](https://github.com/longbridge/omarchy-longbridge)

It has no exit or destructive actions.

## Keyboard controls

- `J` / `K` or arrow keys: move selection
- `Enter`: open selected detail
- `/` or `F`: focus the watchlist filter
- `A`: open the add-symbol control
- `X`: remove the selected watchlist symbol
- `R`: reload the active tab (prices stream on their own; this re-reads membership and positions)
- `W` / `M`: switch to Watchlist
- `P`: switch to Portfolio
- `Esc`: clear the filter, return from detail, or close the panel

## Privacy and data sources

The only data written to disk is the watchlist cache described above: symbols, group names, and last prices, under the shell's own cache directory. No account, portfolio, order, or credential data is cached.

The plugin does not read or copy Longbridge OAuth files. Setup, Watchlist, quotes, and Portfolio all run the installed CLI, which owns authentication and account access. The Watchlist calls only read methods plus `quote.subscribe`/`quote.unsubscribe`; the watchlist-editing and order methods `serve` exposes are never called. No trading or order placement is implemented.

Red and green are reserved for rise/fall text, the sparklines that show the same movement, and the live dot. The portfolio's allocation bar uses a separate categorical palette — blue, violet, amber, teal — precisely so it cannot be read as gain or loss. Icons, surfaces, selection, and borders remain theme-neutral; only the official logo in the panel header uses brand colors.

## Development

Run all checks with:

```bash
make validate
```

Automated tests use fixtures and fake executables. They do not contact Longbridge or read OAuth files.

Quickshell's `Process` type only exists inside the quickshell runtime, so the JSON-RPC data path is exercised by running it:

```bash
make smoke       # against tests/bin/longbridge, offline
make smoke-live  # against the installed CLI and your own session
```

Both print groups, the snapshot, subscription state, and live pushes for fifteen seconds.

## Update or remove

```bash
omarchy plugin update longbridge.omarchy
omarchy plugin remove longbridge.omarchy
```

Removing the plugin does not remove Longbridge Terminal or its login.

## Limitations

- Read-only; no order placement.
- Watchlist membership changes made in other Longbridge clients appear when the panel is reopened, since `serve` pushes quotes but not watchlist edits.
- Live quotes depend on your Longbridge market-data entitlements and may be delayed, interrupted, or unavailable.
- No historical portfolio chart.

Longbridge for Omarchy is not investment advice.

## License

Apache-2.0. Longbridge Terminal is distributed separately.
