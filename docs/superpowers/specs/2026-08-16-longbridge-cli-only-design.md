# Longbridge CLI-Only Plugin Design

## Goal

Longbridge for Omarchy will use the installed `longbridge` command-line application as its only data and authentication boundary. The plugin will contain QML and JavaScript only; it will not compile, download, or execute a plugin-specific Rust helper.

## Runtime architecture

QML starts short-lived `Process` instances using the executable name `longbridge`, allowing normal `PATH` resolution. The plugin never reads OAuth files or receives access or refresh tokens.

The Markets tab runs:

```text
longbridge quote SYMBOL... --format json
```

It refreshes immediately when the configured watchlist changes, when the panel opens, when the user requests refresh, and every 15 seconds while the panel is open. There is no claim of push streaming or continuous WebSocket subscription.

The Portfolio tab runs:

```text
longbridge portfolio --format json
```

It refreshes when selected, when the user requests refresh, and every 60 seconds while selected and open. The CLI remains responsible for quotes, exchange rates, account aggregation, P/L calculations, regional routing, and shared authentication.

## Data adapters

JavaScript adapters convert the CLI's native JSON into stable view models. Quote adaptation preserves symbol, price, previous close, OHLC, volume, turnover, status, and the newest applicable extended-hours quote. Portfolio adaptation preserves the USD overview, holdings, cash, current P/L, and intraday P/L exposed by the CLI.

The adapters reject malformed top-level payloads and normalize absent optional fields without inventing financial values. Money remains numeric only inside formatting and aggregation code; source decimal strings are preserved in model records where available.

## Authentication and errors

The plugin does not implement login or logout. If `longbridge` is missing, the panel instructs the user to install Longbridge Terminal. If a command reports an authentication error, the panel instructs the user to run `longbridge auth login` in a terminal. Other failures display a short, credential-free message and retain the last successful data instead of clearing the panel.

Stderr is not surfaced verbatim in QML because it may contain request diagnostics. IPC status reports only connection state, watched symbols, selected tab, and the last successful refresh time.

## Repository and installation changes

The following Rust/helper artifacts will be removed:

- `helper/`
- `scripts/longbridge-helper`
- `scripts/helper-release.env`
- helper launcher tests and release-checksum documentation

`install.sh` will check for `longbridge`, validate the plugin, and create the development symlink at `~/.config/omarchy/plugins/longbridge.omarchy`. It will not invoke Cargo.

The manifest remains named `Longbridge` with ID `longbridge.omarchy`.

## Brand icon

`LongbridgeLogo.qml` recreates the official seven-rectangle Longbridge mark from the referenced 69×69 SVG. It uses the original relative geometry: `(0,0,3,69)`, `(7,0,10,69)`, `(21,60,9,9)`, `(33,60,3,9)`, `(40,52,10,17)`, `(53,43,9,26)`, and `(66,26,3,43)`.

The component supports two explicit treatments. In the bar, all seven rectangles use the injected Omarchy foreground color so the compact mark remains legible in both dark and light themes. Inside the panel header and portfolio account badge, the three originally black rectangles use the injected foreground color while the remaining rectangles use the official teal `#00DBB6`, yellow `#FFE000`, and orange `#FC5200`. A `brandColors` property selects the treatment.

The component preserves a square aspect ratio and scales all geometry from the 69-unit source view box. No SVG is fetched at runtime and no bitmap asset is generated.

Cards, quote tiles, position rows, borders, selection surfaces, and other containers use only neutral/theme colors. Red and green are reserved for numeric or textual rise/fall indicators; they are not used as item backgrounds, border accents, icons, or selection colors. The official colored Longbridge logo within the panel is a brand-identity exception, not a market-direction signal.

## Testing

JavaScript fixture tests cover quote arrays, extended-hours selection, portfolio overview/holdings mapping, malformed JSON shapes, and safe error classification. A shell test uses a fake `longbridge` executable to verify exact argument construction without network access. QML lint and `omarchy plugin validate` remain part of `make validate`.

A manual verification runs the installed CLI against the user's existing login, then installs the plugin through `./install.sh` and confirms both tabs render. Automated tests must not read the user's token files or contact Longbridge.

## Out of scope

- WebSocket quote subscriptions
- Plugin-managed OAuth or token storage
- Trading or order placement
- Historical portfolio chart generation
- Bundling or downloading the Longbridge CLI
