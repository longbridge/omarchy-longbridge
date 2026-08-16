# Omarchy Longbridge Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an installable Omarchy bar widget that shares `longbridge-terminal` OAuth storage and displays genuine Longbridge real-time quote pushes in an original market-pulse UI.

**Architecture:** A focused Rust helper owns extracted OAuth/storage code and the official Longbridge SDK connection, emitting safe NDJSON events to a QML `Process`. Pure JavaScript modules normalize those events into market-grouped UI state; QML renders bar, board, onboarding, and detail states. A versioned launcher downloads and checksum-verifies the release helper into the XDG cache.

**Tech Stack:** Rust 2021, Tokio, official Longbridge Rust SDK, AES-GCM/HKDF secure storage extracted from `longbridge-terminal`, Qt/QML, Quickshell/Omarchy shell APIs, JavaScript model tests, Bash launcher.

## Global Constraints

- The plugin ID is `longbridge.market-pulse` and the only plugin kind is `bar-widget`.
- The first release is read-only: no account, position, order, or trade operations.
- Production OAuth files are exactly `~/.longbridge/openapi/cli-registration` and `~/.longbridge/openapi/cli-auth`.
- Authentication and secure-storage production code is extracted from `../longbridge-terminal`; do not independently reproduce the file format.
- Tokens and decrypted OAuth payloads never cross the helper/QML boundary or appear in arguments, stdout, stderr, IPC, or logs.
- Market decimals remain strings in helper JSON.
- The watchlist contains at most 20 canonical symbols such as `AAPL.US` and `700.HK`.
- The UI is a grouped live market board with inline detail; do not add Stochi-style sparklines, period controls, or Yahoo links.
- Source attribution for extracted Apache-2.0 code is retained in file headers and `NOTICE`.

---

## File map

- `manifest.json`: Omarchy metadata, defaults, and schema.
- `Panel.qml`: panel state, navigation, persistence, and visual composition.
- `QuoteBridge.qml`: helper process lifecycle and retry timers only.
- `Model.js`: canonical-symbol, quote-state, market-group, and formatting functions.
- `Protocol.js`: incremental NDJSON parsing and safe event validation.
- `components/ConnectionBanner.qml`: login/reconnect/stale status.
- `components/MarketGroup.qml`: one market heading and its quote tiles.
- `components/QuoteTile.qml`: one live quote summary.
- `components/SymbolDetail.qml`: selected-symbol session data.
- `helper/src/secure_storage.rs`: extracted CLI encrypted storage.
- `helper/src/auth.rs`: extracted CLI registration/login/refresh behavior adapted only at output boundaries.
- `helper/src/region.rs`: extracted endpoint/DC selection.
- `helper/src/context.rs`: OAuth-backed quote context construction.
- `helper/src/protocol.rs`: serializable safe event types.
- `helper/src/stream.rs`: snapshots, subscriptions, pushes, and reconnect outcome.
- `helper/src/main.rs`: CLI parsing and one-command dispatch.
- `scripts/longbridge-helper`: cached release-binary resolver and SHA-256 verifier.
- `tests/test_model.js`: pure model behavior.
- `tests/test_protocol.js`: incremental helper-output parsing.
- `tests/test_launcher.sh`: launcher cache/checksum behavior using local fixtures.
- `NOTICE`: provenance of extracted Longbridge Terminal files.
- `README.md`: install, login sharing, operation, limitations, and removal.

### Task 1: Helper crate and safe event protocol

**Files:**
- Create: `helper/Cargo.toml`
- Create: `helper/src/lib.rs`
- Create: `helper/src/protocol.rs`
- Create: `helper/src/main.rs`

**Interfaces:**
- Produces: `protocol::Event`, `protocol::Quote`, and `protocol::write_event<W: Write>(&mut W, &Event) -> anyhow::Result<()>`.
- Produces commands: `auth status`, `auth login`, `auth logout`, `stream <SYMBOL>...`, `search <QUERY>`.

- [ ] **Step 1: Write failing protocol tests**

Add tests in `helper/src/protocol.rs` proving a quote decimal serializes as a JSON string, one event occupies one line, and error serialization contains only `type`, `code`, and `message`. Use literal expected JSON values.

- [ ] **Step 2: Verify RED**

Run: `cargo test --manifest-path helper/Cargo.toml protocol -- --nocapture`

Expected: compilation fails because `Event`, `Quote`, and `write_event` do not exist.

- [ ] **Step 3: Implement the minimal protocol and command parser**

Define tagged `serde` events: `Connection`, `Snapshot`, `Quote`, `Subscription`, `Auth`, `Search`, and `Error`. Keep all price/change/turnover fields as `String`; timestamps are `i64`. Add a Clap command tree, with unimplemented network commands returning the safe JSON error `not_implemented` rather than panicking.

- [ ] **Step 4: Verify GREEN**

Run: `cargo test --manifest-path helper/Cargo.toml protocol -- --nocapture`

Expected: all protocol tests pass with no warnings.

- [ ] **Step 5: Commit**

```bash
git add helper/Cargo.toml helper/src/lib.rs helper/src/main.rs helper/src/protocol.rs
git commit -m "feat: define Longbridge helper protocol"
```

### Task 2: Extract shared encrypted token storage

**Files:**
- Create: `helper/src/secure_storage.rs`
- Create: `helper/tests/storage_compatibility.rs`
- Create: `helper/tests/fixtures/legacy-token.json`
- Modify: `helper/src/lib.rs`
- Create: `NOTICE`

**Interfaces:**
- Produces: `secure_storage::EncryptedFileTokenStorage`, implementing the SDK `TokenStorage` trait.
- Produces: `secure_storage::token_file_path() -> anyhow::Result<PathBuf>` and `secure_storage::harden_file_permissions(&Path)`.

- [ ] **Step 1: Write failing compatibility tests**

Use an isolated temporary home override accepted only under `cfg(test)`. Test literal payload fields, `LB\x01` magic, encrypt/decrypt round trip, tamper rejection, legacy JSON migration, and Unix mode `0600`. Include a test that invokes the CLI source module's algorithm against the same fixed machine-id input and proves each implementation can decrypt the other's bytes.

- [ ] **Step 2: Verify RED**

Run: `cargo test --manifest-path helper/Cargo.toml --test storage_compatibility -- --nocapture`

Expected: compilation fails because `secure_storage` does not exist.

- [ ] **Step 3: Extract the CLI module**

Copy `../longbridge-terminal/src/secure_storage.rs` as the production basis, retain its module documentation, and add an Apache-2.0 provenance comment. Restrict edits to crate paths, a test-only path/machine-id injection seam, and public visibility needed by the helper. Record the source repository and source file in `NOTICE`.

- [ ] **Step 4: Verify GREEN and compare source drift**

Run:

```bash
cargo test --manifest-path helper/Cargo.toml --test storage_compatibility -- --nocapture
cargo test --manifest-path helper/Cargo.toml secure_storage -- --nocapture
```

Expected: all storage tests pass; the test proves bidirectional compatibility.

- [ ] **Step 5: Commit**

```bash
git add helper/src/lib.rs helper/src/secure_storage.rs helper/tests/storage_compatibility.rs helper/tests/fixtures/legacy-token.json NOTICE
git commit -m "feat: share Longbridge CLI token storage"
```

### Task 3: Extract registration, login, refresh, and context code

**Files:**
- Create: `helper/src/auth.rs`
- Create: `helper/src/region.rs`
- Create: `helper/src/context.rs`
- Create: `helper/tests/auth_status.rs`
- Modify: `helper/src/lib.rs`
- Modify: `helper/src/main.rs`
- Modify: `NOTICE`

**Interfaces:**
- Produces: `auth::status() -> anyhow::Result<AuthState>`, `auth::login() -> anyhow::Result<()>`, `auth::logout() -> anyhow::Result<()>`, `auth::refresh_if_expired() -> anyhow::Result<()>`.
- Produces: `context::connect() -> anyhow::Result<(QuoteContext, PushStream)>` using extracted shared storage.

- [ ] **Step 1: Write failing auth-status tests**

With temporary storage roots, prove missing registration/token yields `not_authenticated`, a valid shared token yields `authenticated`, a corrupt encrypted token yields `token_unreadable`, and serialized status never contains fixture access/refresh tokens.

- [ ] **Step 2: Verify RED**

Run: `cargo test --manifest-path helper/Cargo.toml --test auth_status -- --nocapture`

Expected: compilation fails because `auth::status` is absent.

- [ ] **Step 3: Extract CLI code and adapt output boundaries**

Extract only required functions from `../longbridge-terminal/src/auth.rs`, `src/region.rs`, and `src/openapi/context.rs`. Preserve `cli-registration`, callback port `60355`, client registration reuse, browser OAuth, refresh-token DC routing, and the extracted storage implementation. Replace terminal text with typed safe errors at `main.rs`; do not change OAuth request semantics.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
cargo test --manifest-path helper/Cargo.toml --test auth_status -- --nocapture
cargo test --manifest-path helper/Cargo.toml auth -- --nocapture
```

Expected: all auth tests pass and captured output contains no token fixture.

- [ ] **Step 5: Commit**

```bash
git add helper/src/auth.rs helper/src/region.rs helper/src/context.rs helper/src/lib.rs helper/src/main.rs helper/tests/auth_status.rs NOTICE
git commit -m "feat: extract shared Longbridge OAuth flow"
```

### Task 4: Real-time snapshot and subscription stream

**Files:**
- Create: `helper/src/stream.rs`
- Create: `helper/tests/stream_events.rs`
- Modify: `helper/src/lib.rs`
- Modify: `helper/src/main.rs`
- Modify: `helper/src/protocol.rs`

**Interfaces:**
- Consumes: `context::connect`, `protocol::{Event, Quote, write_event}`.
- Produces: `stream::run<S: QuoteSource, W: Write>(source: S, symbols: Vec<String>, output: W) -> anyhow::Result<()>`.
- `QuoteSource` exposes `snapshot`, `subscribe`, and `next_push` so network-free tests exercise the real stream reducer and serializer.

- [ ] **Step 1: Write failing stream tests**

Use a deterministic in-memory `QuoteSource` with complete Longbridge-shaped snapshot and push records. Prove event order is connecting → snapshot → subscription → quote, push updates preserve snapshot `prev_close`, duplicate symbols are removed, invalid symbols return `invalid_symbol`, and upstream failure becomes a safe error event.

- [ ] **Step 2: Verify RED**

Run: `cargo test --manifest-path helper/Cargo.toml --test stream_events -- --nocapture`

Expected: compilation fails because `stream::run` and `QuoteSource` are absent.

- [ ] **Step 3: Implement reducer and SDK adapter**

Normalize canonical symbols, reject empty or more than 20 symbols, fetch `quote` plus `static_info`, subscribe with `SubFlags::QUOTE`, convert `PushEvent::Quote`, and flush every NDJSON line. `main.rs stream` constructs the SDK adapter and delegates to `run`.

- [ ] **Step 4: Verify GREEN**

Run: `cargo test --manifest-path helper/Cargo.toml --test stream_events -- --nocapture`

Expected: all stream tests pass with literal event sequences.

- [ ] **Step 5: Commit**

```bash
git add helper/src/lib.rs helper/src/main.rs helper/src/protocol.rs helper/src/stream.rs helper/tests/stream_events.rs
git commit -m "feat: stream real-time Longbridge quotes"
```

### Task 5: Model and incremental NDJSON parser

**Files:**
- Create: `Model.js`
- Create: `Protocol.js`
- Create: `tests/test_model.js`
- Create: `tests/test_protocol.js`
- Create: `Makefile`

**Interfaces:**
- Produces: `Model.normalizedSymbols`, `Model.applyEvent`, `Model.marketGroups`, `Model.rows`, `Model.formatPrice`, `Model.formatPercent`, `Model.isStale`.
- Produces: `Protocol.consume(buffer, chunk) -> { events, remainder, errors }`.

- [ ] **Step 1: Write failing JavaScript tests**

Load QML-compatible `.js` files through Node's `vm`. Test canonical suffix validation, 20-symbol cap, duplicate removal, immutable snapshot/push reconciliation, US/HK/CN/SG grouping order, stale timestamps, decimal formatting, split NDJSON lines, multiple lines per chunk, and malformed-line recovery.

- [ ] **Step 2: Verify RED**

Run: `node --test tests/test_model.js tests/test_protocol.js`

Expected: failure because `Model.js` and `Protocol.js` do not exist.

- [ ] **Step 3: Implement minimal pure functions**

Use ES5-compatible syntax accepted by QML's JavaScript engine. Do not import Node APIs. Preserve decimal source strings in state and return new objects/arrays on each event.

- [ ] **Step 4: Verify GREEN**

Run: `node --test tests/test_model.js tests/test_protocol.js`

Expected: all JavaScript tests pass.

- [ ] **Step 5: Commit**

```bash
git add Model.js Protocol.js tests/test_model.js tests/test_protocol.js Makefile
git commit -m "feat: model live market pulse state"
```

### Task 6: Checksum-verifying helper launcher

**Files:**
- Create: `scripts/longbridge-helper`
- Create: `scripts/helper-release.env`
- Create: `tests/test_launcher.sh`
- Modify: `Makefile`

**Interfaces:**
- Produces executable `scripts/longbridge-helper`, forwarding all arguments only after resolving a verified helper binary.
- Consumes `HELPER_VERSION`, `HELPER_SHA256`, and `HELPER_URL` from `scripts/helper-release.env`.

- [ ] **Step 1: Write failing launcher tests**

Use temporary `XDG_CACHE_HOME` and a `file://` fixture. Prove valid artifacts execute and are cached, checksum mismatch exits nonzero without executing, cached tampering is detected, and `LONGBRIDGE_HELPER_DEV` is honored only when `LONGBRIDGE_PLUGIN_DEV=1`.

- [ ] **Step 2: Verify RED**

Run: `bash tests/test_launcher.sh`

Expected: failure because the launcher is absent.

- [ ] **Step 3: Implement the launcher**

Use `curl --fail --location`, `sha256sum --check`, a temporary sibling download, atomic rename, and explicit executable permissions. Resolve files relative to the launcher, never through the current directory.

- [ ] **Step 4: Verify GREEN**

Run: `bash tests/test_launcher.sh`

Expected: every launcher case passes and no unverified fixture executes.

- [ ] **Step 5: Commit**

```bash
git add scripts/longbridge-helper scripts/helper-release.env tests/test_launcher.sh Makefile
git commit -m "feat: verify cached Longbridge helper releases"
```

### Task 7: QML bridge and original market-pulse panel

**Files:**
- Create: `QuoteBridge.qml`
- Create: `Panel.qml`
- Create: `components/ConnectionBanner.qml`
- Create: `components/MarketGroup.qml`
- Create: `components/QuoteTile.qml`
- Create: `components/SymbolDetail.qml`
- Modify: `Makefile`

**Interfaces:**
- Consumes: launcher commands, `Protocol.consume`, and `Model.applyEvent`.
- Produces IPC methods `open`, `close`, `toggle`, `reconnect`, and credential-free `status`.

- [ ] **Step 1: Add failing static/load checks**

Add `make qml-check` that runs `qmllint` on every QML file and a shell smoke test that loads the plugin with an injected fake helper emitting fixture NDJSON. Assert the bridge reaches `live`, applies a push, and exposes no fixture token through IPC status.

- [ ] **Step 2: Verify RED**

Run: `make qml-check`

Expected: failure because QML files do not exist.

- [ ] **Step 3: Implement QML components**

Follow installed Omarchy `Panel`, setting persistence, `Process`, and `IpcHandler` patterns. Implement one process, bounded retry timers, stale preservation, grouped board navigation, add/remove/search, inline detail, login, reconnect, and accessible empty/error states. Use a pulse/radio-wave bar glyph and direction rails; do not add charts.

- [ ] **Step 4: Verify GREEN and inspect states**

Run:

```bash
make qml-check
node --test tests/test_model.js tests/test_protocol.js
```

Expected: lint/load checks and all model tests pass. Capture manual screenshots for unauthenticated, live board, stale, and detail states during the final acceptance task.

- [ ] **Step 5: Commit**

```bash
git add Panel.qml QuoteBridge.qml components Makefile
git commit -m "feat: add Longbridge market pulse panel"
```

### Task 8: Manifest, documentation, and acceptance

**Files:**
- Create: `manifest.json`
- Create: `README.md`
- Modify: `Makefile`
- Modify: `LICENSE` only if required to retain compatible attribution.

**Interfaces:**
- Produces a repository installable through `omarchy plugin add <git-url> --enable`.

- [ ] **Step 1: Add failing plugin validation target**

Add `make validate` to run Rust tests, JavaScript tests, launcher tests, QML checks, `git diff --check`, and `omarchy plugin validate .`. Run it before creating the manifest to establish the expected validation failure.

- [ ] **Step 2: Verify RED**

Run: `make validate`

Expected: `omarchy plugin validate .` fails because `manifest.json` is absent.

- [ ] **Step 3: Add manifest and user documentation**

Declare `longbridge.market-pulse`, version `0.1.0`, `bar-widget`, on-demand activation, right-section placement, default symbols `AAPL.US`, `700.HK`, and `D05.SG`, and settings for watchlist and positive-color convention. Document install/update/remove, shared login paths and behavior, helper download/checksum, keyboard controls, market-data entitlement, privacy, non-affiliation, and read-only limitation.

- [ ] **Step 4: Run full acceptance**

Run:

```bash
make validate
LONGBRIDGE_HELPER_DEV=helper/target/debug/longbridge-helper LONGBRIDGE_PLUGIN_DEV=1 scripts/longbridge-helper auth status
```

Expected: all automated checks pass; auth status is valid JSON and contains no credential fields. Then install from the local repository with Omarchy's supported development path, visually inspect all required states, and verify a real quote push changes a row without polling.

- [ ] **Step 5: Commit**

```bash
git add manifest.json README.md Makefile LICENSE
git commit -m "docs: publish Omarchy Longbridge plugin"
```

### Task 9: Compatibility and completion audit

**Files:**
- Modify only files implicated by failing evidence.

**Interfaces:**
- Verifies every success criterion in the design specification.

- [ ] **Step 1: Run format and complete automated suite**

Run:

```bash
cargo fmt --manifest-path helper/Cargo.toml --check
cargo clippy --manifest-path helper/Cargo.toml --all-targets -- -D warnings
make validate
```

Expected: all commands exit zero with no warnings.

- [ ] **Step 2: Compare extracted code and storage behavior**

Review the extraction diff against `../longbridge-terminal/src/{auth,secure_storage,region}.rs`, account for every behavioral change, and rerun bidirectional storage fixtures. Confirm both applications recognize the same real local login without printing token content.

- [ ] **Step 3: Verify live runtime evidence**

With user credentials already present, start the helper stream for two entitled symbols, retain safe event output, and prove at least one `quote` push follows the initial `snapshot`. Exercise helper restart after token-file modification without logging credentials.

- [ ] **Step 4: Verify visual and installation evidence**

Validate the plugin, load it in Omarchy, inspect unauthenticated/connect, empty, live grouped board, detail, stale, partial error, and reconnect states, and confirm its presentation does not reproduce Stochi's sparkline/period/manage layouts.

- [ ] **Step 5: Commit audit fixes and record results**

Commit only necessary fixes with a scoped message. Do not mark the goal complete unless every design success criterion has direct current-state evidence.
