# Longbridge CLI Watchlist Design

> Supersedes the public-watchlist data-source sections of `2026-08-16-compact-ui-public-watchlist-design.md`. The compact UI, mandatory onboarding, portfolio, color, icon, and resource-menu requirements remain in force except where this document explicitly changes them.

## Goal

Replace the incorrect provider-backed/local-settings watchlist with the user's authenticated Longbridge watchlist and Longbridge quote data. Keep the watchlist read-only and retain the compact bounded interface.

## Data flow

`WatchlistService.qml` owns a sequential two-command refresh:

1. Run `longbridge watchlist --format json`.
2. Parse every returned group and preserve each group's ID, name, security order, names, markets, and pinned state.
3. Select the active group, defaulting to the case-insensitive group named `all`.
4. Run `longbridge quote SYMBOL... --format json` for the symbols in the active group.
5. Merge quote records into the active group's securities by canonical Longbridge symbol.

No Yahoo request, Python quote helper, local membership setting, or fallback symbol list remains. The CLI watchlist is the sole membership source and the CLI quote command is the sole price source. An empty active group renders a normal empty state without running the quote command.

The service refreshes when the authenticated panel opens, on explicit refresh, and every five minutes while the Watchlist tab is active. Concurrent refresh requests coalesce. A watchlist-command failure preserves the last successful membership and prices. A quote-command failure preserves the last successful prices and marks the visible data stale.

## Parsing and models

`CliAdapter.js` adds these exact interfaces:

- `watchlistCommand()` returns `["longbridge", "watchlist", "--format", "json"]`.
- `quoteCommand(symbols)` returns `["longbridge", "quote", ...symbols, "--format", "json"]`.
- `parseWatchlist(text)` validates the group array and returns every normalized group plus the default `all` group ID.
- `parseQuotes(text)` adapts the CLI quote array into the existing normalized quote snapshot.

The `all` group name match is case-insensitive. Missing or duplicated `all` groups are invalid data rather than triggers for guessing or flattening other groups. Group and security source order are preserved. Empty groups, including the built-in `holdings` group, remain selectable. The service accepts symbols returned by Longbridge even when they fall outside the earlier local validator, including index-style symbols such as `.SPX.US`.

The watchlist view model retains group `id` and `name`, plus security `symbol`, `name`, `market`, `is_pinned`, quote fields, per-symbol error state, and timestamps. Longbridge watchlist names take precedence over quote-response names so the visible label matches the user's saved list.

## Read-only interface

The Watchlist tab has no Add, Remove, or local-membership controls. Keyboard shortcuts `A` and `X` are removed. Selecting a symbol still opens price detail, but the detail surface has only a Back action. The refresh icon remains available.

A compact group dropdown sits beside the Refresh icon. It lists every Longbridge group in source order, including `all` and `holdings`, and displays the active group name. `all` is selected after initial load. Choosing another group immediately switches the bounded list and fetches quotes only for that group's securities. The active group ID may be retained for the current plugin session, but is not written back to the account or used to alter membership.

Pinned entries remain in the order returned by Longbridge. The tab does not expose remote watchlist mutation commands. Changes or groups created in Longbridge Terminal or another Longbridge client appear on the next refresh; if the active group disappears, selection returns to `all`.

## Header alignment correction

The panel header uses a fixed-height `Item`, not a `Row`. The 20-unit logo anchors to the left and vertical center. The single-line “Longbridge” title anchors immediately to the logo's right and to the same vertical center. The 28-unit resource-menu trigger anchors to the right and vertical center. This explicit geometry avoids implicit-height differences between logo, font metrics, and menu control.

The useless watchlist status subtitle remains removed. The header displays only the logo, title, and resource menu.

## Repository cleanup

Remove:

- `longbridge-quotes`;
- `QuoteAdapter.js`;
- `QuoteService.qml`;
- public-provider fixtures and tests;
- Python runtime checks and Yahoo documentation.

Add `WatchlistService.qml` and CLI watchlist fixtures/tests. `install.sh` returns to requiring the `longbridge` executable because mandatory onboarding and all runtime data now depend on it; it still must not install anything automatically outside the explicit welcome-page action.

## Testing

Fixture tests cover the real watchlist group schema, case-insensitive default `all` selection, missing/duplicate `all`, preservation of every group, empty `holdings`, group/security source ordering, active-group switching and disappearance, pinned/name/market preservation, index-style symbols, quote merging, malformed quotes, and safe failure classification.

Command tests assert exact watchlist and quote argument arrays. Source tests assert the public helper and Yahoo references are absent, local watchlist mutation controls and shortcuts are absent, the group dropdown includes all returned groups, only the Watchlist service runs quote commands, and Portfolio still runs exactly `longbridge portfolio --format json`.

Header source tests assert a fixed-height `Item` with logo, title, and menu all anchored to the same vertical center. Full acceptance remains `make validate`, `omarchy plugin validate .`, live `longbridge watchlist --format json`, live quotes for returned symbols, and visual inspection after shell reload.

## Completion criteria

The correction is complete when the group filter exposes every authenticated Longbridge group (including `holdings`), visible membership/order/names follow the selected group, prices come from Longbridge quotes, the panel performs no public-provider quote requests or watchlist mutations, stale data survives transient failures, the fixed header is visibly centered, all tests pass, and live inspection confirms the real account groups render.
