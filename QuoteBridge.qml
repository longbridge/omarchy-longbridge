import QtQuick
import Quickshell
import Quickshell.Io
import "Protocol.js" as Protocol

Item {
  id: root

  property var symbols: []
  property string connectionState: "idle"
  property string message: ""
  property int retryAttempt: 0
  property bool intentionalStop: false
  readonly property bool running: streamProcess.running
  readonly property string helperPath: decodeURIComponent(
    String(Qt.resolvedUrl("scripts/longbridge-helper")).replace(/^file:\/\//, "")
  )

  signal eventReceived(var event)

  function command(name, values) {
    var result = [root.helperPath, name]
    var source = values || []
    for (var i = 0; i < source.length; i++) result.push(String(source[i]))
    return result
  }

  function start() {
    retryTimer.stop()
    if (streamProcess.running || root.symbols.length === 0) return
    intentionalStop = false
    connectionState = "connecting"
    message = ""
    streamProcess.command = command("stream", root.symbols)
    streamProcess.running = true
  }

  function stop() {
    intentionalStop = true
    retryTimer.stop()
    if (streamProcess.running) streamProcess.running = false
    connectionState = "idle"
  }

  function restart() {
    intentionalStop = false
    retryAttempt = 0
    if (streamProcess.running) streamProcess.running = false
    Qt.callLater(start)
  }

  function checkAuth() {
    if (authProcess.running) return
    authProcess.command = command("auth", ["status"])
    authProcess.running = true
  }

  function login() {
    if (authProcess.running) return
    connectionState = "authenticating"
    authProcess.command = command("auth", ["login"])
    authProcess.running = true
  }

  function applyLine(line) {
    var parsed = Protocol.consume("", String(line || "") + "\n")
    if (parsed.errors.length > 0) {
      connectionState = "error"
      message = "The Longbridge helper returned an unreadable event."
    }
    for (var i = 0; i < parsed.events.length; i++) {
      var event = parsed.events[i]
      if (event.type === "connection") connectionState = String(event.state || "connecting")
      else if (event.type === "subscription") {
        connectionState = "live"
        retryAttempt = 0
      } else if (event.type === "error") {
        connectionState = event.code === "not_authenticated" ? "not_authenticated" : "error"
        message = String(event.message || "Longbridge connection failed.")
      } else if (event.type === "auth") connectionState = String(event.state || "unknown")
      eventReceived(event)
    }
  }

  onSymbolsChanged: restart()

  Component.onCompleted: checkAuth()

  Process {
    id: streamProcess
    running: false
    command: []
    stdout: SplitParser { onRead: function(line) { root.applyLine(line) } }
    stderr: SplitParser {
      onRead: function(line) {
        if (String(line || "").trim() !== "") root.message = "Longbridge helper could not continue."
      }
    }
    onExited: function(exitCode) {
      if (root.intentionalStop || root.symbols.length === 0) return
      root.connectionState = "disconnected"
      root.retryAttempt = Math.min(root.retryAttempt + 1, 6)
      retryTimer.interval = Math.min(30000, 1000 * Math.pow(2, root.retryAttempt - 1))
      retryTimer.restart()
    }
  }

  Process {
    id: authProcess
    running: false
    command: []
    stdout: SplitParser { onRead: function(line) { root.applyLine(line) } }
    stderr: SplitParser {
      onRead: function(line) {
        if (String(line || "").trim() !== "") root.message = "Longbridge authentication failed."
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 0 && root.connectionState === "authenticated") root.start()
    }
  }

  Timer {
    id: retryTimer
    interval: 1000
    repeat: false
    onTriggered: root.start()
  }
}
