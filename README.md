# Longbridge for Omarchy

Longbridge quotes and portfolio data in the Omarchy bar.

The plugin calls the installed [Longbridge Terminal](https://github.com/longbridge/longbridge-terminal) CLI and renders its JSON output with QML. There is no plugin-specific service, Rust helper, token store, or market-data implementation.

## Requirements

- Omarchy
- `longbridge` available on `PATH`
- A Longbridge login created with `longbridge auth login`

Longbridge Terminal owns authentication, regional routing, market-data access, exchange-rate conversion, and account calculations. OAuth tokens never pass through QML, plugin settings, process arguments, or IPC output.

## Install

Install Longbridge Terminal using the project installer. See the [CLI installation guide](https://open.longbridge.com/docs/cli/install) for other platforms.

```bash
curl -sSL https://github.com/longbridge/longbridge-terminal/raw/main/install | sh
```

Authenticate, then add the plugin:

```bash
longbridge auth login
omarchy plugin add https://github.com/longbridge/omarchy-longbridge.git --enable
```

The Longbridge pulse icon appears in the right section of the bar.

For development, install this checkout through a symlink:

```bash
./install.sh
```

Use `./install.sh --no-restart` to leave the current shell process running. QML edits are read through the symlink.

## Markets

Enter canonical Longbridge symbols such as:

- `AAPL.US`
- `700.HK`
- `000001.SZ`
- `D05.SG`

The watchlist supports up to 20 symbols. While the panel is open, the plugin runs `longbridge quote ... --format json` every 15 seconds. Select a quote to inspect its session open, previous close, high, low, volume, and trade session.

## Portfolio

The Portfolio tab displays total assets, market value, cash, total P/L, intraday P/L, and current stock positions. It runs `longbridge portfolio --format json` when selected and refreshes every 60 seconds while open.

Longbridge Terminal calculates portfolio totals in USD and preserves each holding's native trading currency.

Keyboard controls:

- `J` / `K` or arrow keys: move through quotes
- `Enter`: open symbol detail
- `A`: focus the symbol field
- `X`: remove the selected symbol
- `R`: refresh quotes
- `M` / `P`: switch between Markets and Portfolio
- `Esc`: return or close

## Development

Run all checks with:

```bash
make validate
```

The tests use fixed CLI JSON fixtures and do not contact Longbridge or read OAuth files.

## Update or remove

```bash
omarchy plugin update longbridge.omarchy
omarchy plugin remove longbridge.omarchy
```

Removing the plugin does not remove the Longbridge Terminal login.

## Limitations

- This plugin is read-only and cannot place orders.
- Quotes are polled every 15 seconds; the plugin does not maintain a WebSocket subscription.
- Quote availability and entitlement depend on the Longbridge account and market-data package.
- Historical portfolio charts are not generated.
- An internet connection is required.

Longbridge for Omarchy is not investment advice. Market data may be delayed, interrupted, or unavailable.

## License

Apache-2.0. Longbridge Terminal is a runtime prerequisite and is distributed separately.
