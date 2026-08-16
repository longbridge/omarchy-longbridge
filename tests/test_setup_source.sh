#!/usr/bin/env bash
set -euo pipefail

setup_file="components/LongbridgeSetup.qml"
panel_file="Panel.qml"

grep -F 'Install Longbridge CLI' "$setup_file" >/dev/null
grep -F 'Log in to Longbridge' "$setup_file" >/dev/null
grep -F 'github.com/longbridge/longbridge-terminal/raw/main/install' SetupAdapter.js >/dev/null
grep -F '["longbridge", "auth", "login"]' SetupAdapter.js >/dev/null
grep -F '["longbridge", "check", "--format", "json"]' SetupAdapter.js >/dev/null
! grep -Fi 'skip' "$setup_file"
grep -F 'setup.ready' "$panel_file" >/dev/null

printf '%s\n' 'ok - mandatory setup source'
