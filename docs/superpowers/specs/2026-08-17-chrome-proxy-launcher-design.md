# Chrome Proxy Launcher Design

## Goal

Always launch Google Chrome through the proxy URL stored in the user's
login-shell `http_proxy` environment variable, including launches from the
desktop application menu and URL handlers.

## Design

Create a user-local wrapper that starts a Bash login shell, validates that
`http_proxy` is non-empty, and then replaces itself with
`google-chrome-stable --proxy-server="$http_proxy"`, forwarding all original
arguments unchanged.

Create a user-local override of the packaged Google Chrome desktop entry in
`~/.local/share/applications/`. Change each Chrome `Exec` action (normal,
new-window, and incognito) to call the wrapper while retaining its original
arguments and desktop-entry field codes. Do not modify `/usr/share` files.

The command-line proxy flag is intentional: Chromium documents that it
overrides environment-derived and desktop proxy settings. The proxy value
still has a single source of truth: the existing shell `http_proxy` variable.

## Failure Behavior

If `http_proxy` is missing or empty, the wrapper exits with an error rather
than silently launching Chrome without the requested proxy. Existing Chrome
processes must be fully closed before a newly launched process can adopt the
flag.

## Verification

- Validate the generated desktop entry with `desktop-file-validate` when the
  command is available.
- Run the wrapper with a harmless Chrome command such as `--version` to verify
  login-shell lookup and argument forwarding without opening a browser.
- Inspect all overridden `Exec` lines to ensure normal, new-window, and
  incognito actions use the wrapper.

## Scope

This affects only Google Chrome launches through the overridden desktop entry.
It does not change the graphical session environment, other applications, the
system Chrome package, or the user's existing shell proxy definition.
