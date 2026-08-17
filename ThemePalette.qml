import QtQuick
import Quickshell
import Quickshell.Io

// Market direction uses the active theme's ANSI green/red roles. Omarchy's
// public Color singleton currently exposes red as urgent but not green, so this
// narrow bridge reads the same colors.toml source and keeps theme semantics.
QtObject {
  id: root

  required property color fallbackGreen
  required property color fallbackRed
  property color parsedGreen: fallbackGreen
  property color parsedRed: fallbackRed
  readonly property color green: parsedGreen
  readonly property color red: parsedRed

  function paletteColor(raw, role, fallback) {
    var match = String(raw || "").match(new RegExp("^\\s*" + role + "\\s*=\\s*[\\\"']?(#[0-9A-Fa-f]{6})", "m"))
    return match ? match[1] : fallback
  }

  function load(raw) {
    parsedGreen = paletteColor(raw, "green", fallbackGreen)
    parsedRed = paletteColor(raw, "red", fallbackRed)
  }

  onFallbackGreenChanged: colorsFile.reload()
  onFallbackRedChanged: colorsFile.reload()

  property FileView colorsFile: FileView {
    id: colorsFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.load(text())
    onFileChanged: reload()
    onLoadFailed: root.load("")
  }
}
