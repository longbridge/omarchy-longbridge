#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_id="longbridge.omarchy"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
plugin_home="$config_home/omarchy/plugins"
install_path="$plugin_home/$plugin_id"
restart_shell=true

usage() {
  printf 'Usage: %s [--no-restart]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-restart)
      restart_shell=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

command -v longbridge >/dev/null 2>&1 || {
  printf '%s\n' 'longbridge is required. Install Longbridge Terminal:' >&2
  printf '%s\n' 'curl -sSL https://github.com/longbridge/longbridge-terminal/raw/main/install | sh' >&2
  printf '%s\n' 'https://open.longbridge.com/docs/cli/install' >&2
  exit 1
}
command -v omarchy >/dev/null 2>&1 || {
  printf '%s\n' 'omarchy is required to install this plugin.' >&2
  exit 1
}

printf '%s\n' 'Validating plugin…'
omarchy plugin validate "$project_dir"

mkdir -p "$plugin_home"
if [[ -L "$install_path" && "$(readlink -f "$install_path")" == "$project_dir" ]]; then
  :
elif [[ -e "$install_path" || -L "$install_path" ]]; then
  backup_path="$install_path.bak.$(date +%Y%m%d%H%M%S)"
  mv "$install_path" "$backup_path"
  printf 'Backed up the previous install to %s\n' "$backup_path"
  ln -s "$project_dir" "$install_path"
else
  ln -s "$project_dir" "$install_path"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  omarchy plugin enable "$plugin_id" >/dev/null 2>&1 || true
fi

if $restart_shell; then
  omarchy restart shell >/dev/null 2>&1 || true
fi

printf 'Longbridge installed for development at %s\n' "$install_path"
printf '%s\n' 'QML edits are read through the symlink; run longbridge auth login if needed.'
