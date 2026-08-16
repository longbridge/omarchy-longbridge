# Longbridge for Omarchy

A compact Omarchy watchlist and Longbridge portfolio panel.

The Watchlist uses a bundled Python standard-library helper to fetch public Yahoo Finance chart data. It never invokes the `longbridge` CLI for quotes. The Portfolio tab uses Longbridge Terminal for authenticated account data.

## Requirements

- Omarchy
- Python 3
- Internet access

Longbridge Terminal and a verified login are mandatory before the normal panel opens. If the CLI is missing, the welcome page can install it from Longbridge's official installer and guide login. There is no skip action.

## Install

Add and enable the plugin:

```bash
omarchy plugin add https://github.com/longbridge/omarchy-longbridge.git --enable
```

Open Longbridge from the bar. The welcome page will:

1. Check whether Longbridge Terminal is installed.
2. Offer **Install Longbridge CLI** when it is missing.
3. Offer **Log in to Longbridge** after installation.
4. Verify the session with `longbridge check --format json`.

The install action runs the official command only after you click it:

```bash
curl -sSL https://github.com/longbridge/longbridge-terminal/raw/main/install | sh
```

See the [Longbridge CLI documentation](https://open.longbridge.com/docs/cli/) for manual installation and troubleshooting.

For development, symlink this checkout into Omarchy:

```bash
./install.sh
```

Use `./install.sh --no-restart` to leave the current shell running. This script validates and links the plugin; it never installs Longbridge Terminal automatically.

## Watchlist

The compact Watchlist supports up to 20 canonical symbols:

- `AAPL.US`
- `700.HK`
- `600519.SH`
- `000001.SZ`
- `D05.SG`

The helper maps those symbols to public provider symbols internally. Quotes refresh when the panel opens, after watchlist changes, on explicit refresh, and every five minutes while open. Partial failures retain the last available value and mark only affected rows.

Each 44-unit row shows the symbol, name, price, currency, and percentage movement. Selecting a row opens OHLC, volume, session, timestamp, and removal details.

## Portfolio

Portfolio runs exactly:

```text
longbridge portfolio --format json
```

It refreshes when selected, on explicit refresh, and every 60 seconds while visible. The summary stays compact while holdings use a bounded list with its own scrollbar. Each 44-unit row shows market value and today's movement; quantity, available quantity, market price, average cost, total P/L, and currency appear in selected-row detail.

## Resource menu

The top-right menu opens:

- [Longbridge](https://longbridge.com)
- [Longbridge CLI](https://open.longbridge.com/docs/cli/)
- [GitHub](https://github.com/longbridge/omarchy-longbridge)

It has no exit or destructive actions.

## Keyboard controls

- `J` / `K` or arrow keys: move selection
- `Enter`: open selected detail
- `A`: open the add-symbol control
- `X`: remove the selected watchlist symbol
- `R`: refresh the active tab
- `W` / `M`: switch to Watchlist
- `P`: switch to Portfolio
- `Esc`: return from detail or close the panel

## Privacy and data sources

The plugin does not read or copy Longbridge OAuth files. Setup and Portfolio launch the installed CLI, which owns authentication and account access. Watchlist requests contain only public ticker symbols and go to Yahoo Finance's chart endpoint. No trading or order placement is implemented.

Red and green are reserved for rise/fall text. Icons, surfaces, selection, and borders remain theme-neutral; only the official logo in the panel header uses brand colors.

## Development

Run all checks with:

```bash
make validate
```

Automated tests use fixtures and fake executables. They do not contact Yahoo or Longbridge and do not read OAuth files.

## Update or remove

```bash
omarchy plugin update longbridge.omarchy
omarchy plugin remove longbridge.omarchy
```

Removing the plugin does not remove Longbridge Terminal or its login.

## Limitations

- Read-only; no order placement.
- Watchlist data is polled and may be delayed, interrupted, or unavailable.
- Public-provider symbol coverage can differ from Longbridge market coverage.
- No historical portfolio chart.

Longbridge for Omarchy is not investment advice.

## License

Apache-2.0. Longbridge Terminal is distributed separately.
