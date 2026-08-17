import QtQuick
import Quickshell
import Quickshell.Io
import "CliAdapter.js" as CliAdapter
import "RpcAdapter.js" as RpcAdapter

// One long-lived `longbridge serve` process shared by the panel: it
// authenticates and opens the market WebSocket once, answers JSON-RPC requests
// on stdin/stdout, and pushes live quotes as notifications. It exits when
// stdin closes, so it never outlives the panel.
Item {
  id: root

  property bool serving: false
  // Authenticating and opening the market WebSocket costs about a second, and
  // it is paid on process start, not per request. Closing the panel therefore
  // parks the session instead of killing it: reopening within the linger
  // window is instant and keeps the existing subscriptions streaming.
  property int lingerMs: 600000
  // idle | starting | ready | error
  property string status: "idle"
  property string errorCode: ""
  property string message: ""
  readonly property bool ready: status === "ready"
  readonly property int inflight: pendingCount

  signal connected()
  signal notified(string method, var params)
  signal failed(string code, string message)
  // The CLI re-wrote its credential store: `longbridge auth login` may have
  // switched accounts, and a running server holds whoever it authenticated as.
  signal authChanged()

  property var pending: ({})
  property var outbox: []
  property int pendingCount: 0
  property int nextId: 0
  property int attempts: 0
  property string lastError: ""

  readonly property int maxAttempts: 3

  function call(method, params, callback) {
    // Nothing may queue against a stopped server: the panel is closed, so the
    // caller has to hear back now rather than wait for a process that will not
    // start.
    if (!serving) {
      if (callback) callback({ code: "disconnected", message: "Longbridge data connection closed." }, null)
      return 0
    }
    var id = ++nextId
    pending[id] = callback || null
    pendingCount++
    outbox.push(RpcAdapter.requestLine(id, method, params))
    if (!serve.running) start()
    else flush()
    return id
  }

  // A user-driven refresh clears the backoff budget so a transient failure
  // never leaves the panel permanently disconnected.
  function retry() {
    attempts = 0
    if (serving && !serve.running) start()
  }

  function start() {
    if (!serving || serve.running) return
    status = "starting"
    lastError = ""
    serve.command = RpcAdapter.serveCommand()
    serve.running = true
  }

  function stop() {
    restartTimer.stop()
    if (serve.running) serve.running = false
    outbox = []
    failPending("disconnected", "Longbridge data connection closed.")
    status = "idle"
  }

  function flush() {
    if (!serve.running) return
    var queued = outbox
    outbox = []
    for (var i = 0; i < queued.length; i++) serve.write(queued[i])
  }

  function failPending(code, message) {
    var ids = Object.keys(pending)
    var callbacks = []
    for (var i = 0; i < ids.length; i++) {
      if (pending[ids[i]]) callbacks.push(pending[ids[i]])
      delete pending[ids[i]]
    }
    pendingCount = 0
    for (var j = 0; j < callbacks.length; j++) callbacks[j]({ code: code, message: message }, null)
  }

  function settle(id, error, result) {
    if (!(id in pending)) return
    var callback = pending[id]
    delete pending[id]
    pendingCount = Math.max(0, pendingCount - 1)
    if (callback) callback(error || null, result)
  }

  function handleLine(line) {
    var incoming = RpcAdapter.parseMessage(line)
    if (incoming.kind === "response") {
      if (incoming.id === initializeId) {
        if (incoming.error) {
          reportFailure(incoming.error.code, incoming.error.message)
          return
        }
        root.status = "ready"
        root.attempts = 0
        root.errorCode = ""
        root.message = ""
        root.connected()
        return
      }
      settle(incoming.id, incoming.error, incoming.result)
    } else if (incoming.kind === "notification") {
      root.notified(incoming.method, incoming.params)
    }
  }

  function reportFailure(code, text) {
    status = "error"
    errorCode = code
    message = text
    failed(code, text)
  }

  property int initializeId: 0
  property bool reauthenticating: false

  // The session authenticates once at process start, so a new login only takes
  // effect after a restart — the panel would otherwise keep serving the
  // previous account until the linger window expired.
  function reauthenticate() {
    lingerTimer.stop()
    attempts = 0
    authChanged()
    if (!serve.running) {
      if (serving) start()
      return
    }
    reauthenticating = true
    serve.running = false
  }

  onServingChanged: {
    if (serving) {
      lingerTimer.stop()
      attempts = 0
      start()
    } else if (serve.running && lingerMs > 0) {
      lingerTimer.restart()
    } else {
      stop()
    }
  }

  Process {
    id: serve
    running: false
    command: []
    stdinEnabled: true

    onStarted: {
      root.initializeId = ++root.nextId
      serve.write(RpcAdapter.requestLine(root.initializeId, "initialize", null))
      root.flush()
    }

    onExited: function(exitCode) {
      var failure = CliAdapter.classifyFailure(root.lastError, exitCode)
      root.failPending(failure.code, failure.message)
      if (root.reauthenticating) {
        root.reauthenticating = false
        if (root.serving) root.start()
        else root.status = "idle"
        return
      }
      if (!root.serving) {
        root.status = "idle"
        return
      }
      root.attempts++
      if (failure.code === "cli_missing" || root.attempts >= root.maxAttempts) {
        root.reportFailure(failure.code, failure.message)
        return
      }
      root.status = "starting"
      restartTimer.interval = 2000 * root.attempts
      restartTimer.restart()
    }

    stdout: SplitParser { onRead: function(line) { root.handleLine(line) } }
    stderr: SplitParser { onRead: function(line) { if (String(line).replace(/^\s+|\s+$/g, "")) root.lastError = line } }
  }

  Timer {
    id: restartTimer
    repeat: false
    onTriggered: root.start()
  }

  FileView {
    id: authFile
    path: Quickshell.env("HOME") + "/.longbridge/openapi/cli-auth"
    watchChanges: true
    printErrors: false
    // Token refreshes rewrite this file too, so a short debounce keeps a burst
    // of writes from restarting the session repeatedly.
    onFileChanged: authDebounce.restart()
  }

  Timer {
    id: authDebounce
    interval: 1500
    repeat: false
    onTriggered: root.reauthenticate()
  }

  Timer {
    id: lingerTimer
    repeat: false
    interval: root.lingerMs
    onTriggered: if (!root.serving) root.stop()
  }

  Component.onDestruction: stop()
}
