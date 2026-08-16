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

export HOME="$test_root/home"
export XDG_CONFIG_HOME="$test_root/config"
export INSTALL_TEST_LOG="$test_root/omarchy.log"
export PATH="$fake_bin:/usr/bin:/bin"

if "$repo_root/install.sh" --no-restart >"$test_root/missing.out" 2>"$test_root/missing.err"; then
  printf '%s\n' 'installer unexpectedly succeeded without longbridge' >&2
  exit 1
fi
grep -F 'https://open.longbridge.com/docs/cli/install' "$test_root/missing.err" >/dev/null
grep -F 'curl -sSL https://github.com/longbridge/longbridge-terminal/raw/main/install | sh' "$test_root/missing.err" >/dev/null

make_fake longbridge 'exit 0'
"$repo_root/install.sh" --no-restart

install_path="$XDG_CONFIG_HOME/omarchy/plugins/longbridge.omarchy"
[[ -L "$install_path" ]]
[[ "$(readlink -f "$install_path")" == "$repo_root" ]]
grep -Fx "plugin validate $repo_root" "$INSTALL_TEST_LOG" >/dev/null

printf '%s\n' 'ok - CLI-only development installer'
