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
[[ ! -e "$repo_root/longbridge-quotes" ]]
[[ ! -e "$repo_root/QuoteAdapter.js" ]]
[[ ! -e "$repo_root/QuoteService.qml" ]]
! grep -Fi 'Yahoo' "$repo_root/README.md"
grep -Fx "plugin validate $repo_root" "$INSTALL_TEST_LOG" >/dev/null

printf '%s\n' 'ok - CLI watchlist development installer'
