#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
fake_bin="$test_root/bin"
mkdir -p "$fake_bin" "$test_root/home"

make_fake() {
  local name="$1"
  local body="$2"
  printf '#!/usr/bin/env bash\n%s\n' "$body" >"$fake_bin/$name"
  chmod +x "$fake_bin/$name"
}

make_fake cargo 'exit 91'
make_fake omarchy 'printf "%s\n" "$*" >>"$INSTALL_TEST_LOG"'
make_fake curl 'printf "%s\n" "curl unexpectedly executed" >>"$INSTALL_TEST_LOG"; exit 91'

export HOME="$test_root/home"
export XDG_CONFIG_HOME="$test_root/config"
export INSTALL_TEST_LOG="$test_root/omarchy.log"
export PATH="$fake_bin:/usr/bin:/bin"

if "$repo_root/install.sh" --no-restart >"$test_root/missing.out" 2>"$test_root/missing.err"; then
  printf '%s\n' 'installer unexpectedly succeeded without longbridge' >&2
  exit 1
fi
grep -F 'longbridge is required' "$test_root/missing.err" >/dev/null
[[ ! -e "$INSTALL_TEST_LOG" ]]
! grep -F 'command -v python3' "$repo_root/install.sh"

make_fake longbridge 'exit 0'
"$repo_root/install.sh" --no-restart

install_path="$XDG_CONFIG_HOME/omarchy/plugins/longbridge.omarchy"
[[ -L "$install_path" ]]
[[ "$(readlink -f "$install_path")" == "$repo_root" ]]

# A previous non-symlink install must be moved OUT of the plugins directory.
# Omarchy scans every subdirectory there for a manifest, so a backup left
# beside the install registers a second plugin with the same id and the shell
# loads the stale copy instead of this checkout.
rm "$install_path"
mkdir -p "$install_path"
printf '%s
' '{"schemaVersion":1,"id":"longbridge.omarchy"}' >"$install_path/manifest.json"
"$repo_root/install.sh" --no-restart >"$test_root/backup.out"
grep -F 'Backed up the previous install to' "$test_root/backup.out" >/dev/null
[[ -L "$install_path" ]]
[[ "$(readlink -f "$install_path")" == "$repo_root" ]]
shopt -s nullglob
leftovers=("$XDG_CONFIG_HOME/omarchy/plugins"/*.bak.*)
shopt -u nullglob
[[ ${#leftovers[@]} -eq 0 ]]
backups=("$XDG_CONFIG_HOME/omarchy/plugin-backups"/longbridge.omarchy.bak.*)
[[ ${#backups[@]} -eq 1 ]]
[[ -f "${backups[0]}/manifest.json" ]]
[[ ! -e "$repo_root/longbridge-quotes" ]]
[[ ! -e "$repo_root/QuoteAdapter.js" ]]
[[ ! -e "$repo_root/QuoteService.qml" ]]
! grep -Fi 'Yahoo' "$repo_root/README.md"
grep -Fx "plugin validate $repo_root" "$INSTALL_TEST_LOG" >/dev/null

printf '%s\n' 'ok - CLI watchlist development installer'
