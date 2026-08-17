#!/usr/bin/env bash
set -euo pipefail

setup_file="components/LongbridgeSetup.qml"
panel_file="Panel.qml"

grep -F 'Install Longbridge CLI' "$setup_file" >/dev/null
grep -F 'Log in to Longbridge' "$setup_file" >/dev/null
grep -F 'SetupAdapter.installDocsUrl()' "$setup_file" >/dev/null
grep -F 'open.longbridge.com/docs/cli/install' SetupAdapter.js README.md install.sh >/dev/null
! grep -RE 'curl[^|]*\|[[:space:]]*(ba)?sh' README.md SetupAdapter.js install.sh components >/dev/null
grep -F '["longbridge", "auth", "login"]' SetupAdapter.js >/dev/null
grep -F '["longbridge", "check", "--format", "json"]' SetupAdapter.js >/dev/null
! grep -Fi 'skip' "$setup_file"
grep -F 'setup.ready' "$panel_file" >/dev/null

printf '%s\n' 'ok - mandatory setup source'
