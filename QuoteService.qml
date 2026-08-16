import QtQuick
import Quickshell.Io
import "QuoteAdapter.js" as QuoteAdapter

Item {
  id: root

  property var symbols: []
  property bool panelOpen: false
  property string quoteState: symbols.length === 0 ? "empty" : "idle"
  property string message: ""
  property double fetchedAtMs: 0
  property var errors: []
  property bool refreshQueued: false
  readonly property bool loading: fetchProcess.running
  readonly property string helperPath: decodeURIComponent(
    String(Qt.resolvedUrl("longbridge-quotes")).replace(/^file:\/\//, "")
  )

  signal quoteEvent(var event)

  function refresh() {
    if (!panelOpen || symbols.length === 0) return
    if (fetchProcess.running) {
      refreshQueued = true
      return
    }
    message = ""
    quoteState = "loading"
    fetchProcess.command = QuoteAdapter.helperCommand(helperPath, symbols)
    fetchProcess.running = true
  }

  onSymbolsChanged: if (panelOpen) Qt.callLater(refresh)
  onPanelOpenChanged: if (panelOpen) Qt.callLater(refresh)

  Process {
    id: fetchProcess
    running: false
    command: []
    stdout: StdioCollector { id: fetchOutput; waitForEnd: true }
    stderr: StdioCollector { id: fetchErrors; waitForEnd: true }
    onExited: function(_exitCode) {
      var parsed = QuoteAdapter.parse(fetchOutput.text)
      if (parsed.ok) {
        root.quoteState = parsed.state
        root.fetchedAtMs = parsed.fetchedAtMs
        root.errors = parsed.errors
        root.message = parsed.state === "partial" ? "Some quotes are unavailable." : ""
        root.quoteEvent(parsed.event)
      } else {
        root.quoteState = "error"
        root.message = parsed.error.message
        root.quoteEvent({ type: "error", code: parsed.error.code, message: parsed.error.message })
      }
      if (root.refreshQueued) {
        root.refreshQueued = false
        Qt.callLater(root.refresh)
      }
    }
  }

  Timer {
    interval: 300000
    repeat: true
    running: root.panelOpen && root.symbols.length > 0
    onTriggered: root.refresh()
  }
}
