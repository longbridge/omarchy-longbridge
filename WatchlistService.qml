import QtQuick
import Quickshell.Io
import "CliAdapter.js" as CliAdapter

Item {
  id: root

  property bool panelOpen: false
  property bool active: false
  property var groups: []
  property string defaultGroupId: ""
  property string activeGroupId: ""
  property string watchlistState: "idle"
  property string message: ""
  property bool refreshQueued: false
  readonly property bool loading: watchlistProcess.running || quoteProcess.running

  signal groupsEvent(var groups, string defaultGroupId)
  signal groupSelected(string groupId)
  signal quoteEvent(var event)

  function activeGroup() {
    for (var i = 0; i < groups.length; i++) if (String(groups[i].id) === activeGroupId) return groups[i]
    return null
  }

  function activeSymbols() {
    var group = activeGroup()
    var securities = group && group.securities ? group.securities : []
    var result = []
    for (var i = 0; i < securities.length; i++) result.push(String(securities[i].symbol))
    return result
  }

  function refresh() {
    if (!panelOpen || !active) return
    if (loading) {
      refreshQueued = true
      return
    }
    watchlistState = "loading"
    message = ""
    watchlistProcess.command = CliAdapter.watchlistCommand()
    watchlistProcess.running = true
  }

  function selectGroup(groupId) {
    var wanted = String(groupId || "")
    if (wanted === activeGroupId) return
    for (var i = 0; i < groups.length; i++) {
      if (String(groups[i].id) === wanted) {
        activeGroupId = wanted
        groupSelected(wanted)
        if (loading) {
          refreshQueued = true
          return
        }
        fetchQuotes()
        return
      }
    }
  }

  function fetchQuotes() {
    var symbols = activeSymbols()
    if (symbols.length === 0) {
      watchlistState = "ready"
      message = ""
      quoteEvent({ type: "snapshot", quotes: [], errors: [] })
      finishQueuedRefresh()
      return
    }
    watchlistState = "loading"
    quoteProcess.command = CliAdapter.quoteCommand(symbols)
    quoteProcess.running = true
  }

  function finishQueuedRefresh() {
    if (!refreshQueued) return
    refreshQueued = false
    Qt.callLater(refresh)
  }

  onPanelOpenChanged: if (panelOpen && active) Qt.callLater(refresh)
  onActiveChanged: if (panelOpen && active) Qt.callLater(refresh)

  Process {
    id: watchlistProcess
    running: false
    command: []
    stdout: StdioCollector { id: watchlistOutput; waitForEnd: true }
    stderr: StdioCollector { id: watchlistErrors; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var failure = CliAdapter.classifyFailure(watchlistErrors.text, exitCode)
        root.watchlistState = "error"
        root.message = failure.message
        root.finishQueuedRefresh()
        return
      }
      var parsed = CliAdapter.parseWatchlist(watchlistOutput.text)
      if (!parsed.ok) {
        root.watchlistState = "error"
        root.message = parsed.error.message
        root.finishQueuedRefresh()
        return
      }
      var previous = root.activeGroupId
      root.groups = parsed.groups
      root.defaultGroupId = parsed.defaultGroupId
      var found = false
      for (var i = 0; i < root.groups.length; i++) if (String(root.groups[i].id) === previous) found = true
      root.activeGroupId = found ? previous : root.defaultGroupId
      root.groupsEvent(root.groups, root.defaultGroupId)
      root.groupSelected(root.activeGroupId)
      root.fetchQuotes()
    }
  }

  Process {
    id: quoteProcess
    running: false
    command: []
    stdout: StdioCollector { id: quoteOutput; waitForEnd: true }
    stderr: StdioCollector { id: quoteErrors; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var failure = CliAdapter.classifyFailure(quoteErrors.text, exitCode)
        root.watchlistState = "error"
        root.message = failure.message
        root.quoteEvent({ type: "error", code: failure.code, message: failure.message })
        root.finishQueuedRefresh()
        return
      }
      var parsed = CliAdapter.parseQuotes(quoteOutput.text)
      if (!parsed.ok) {
        root.watchlistState = "error"
        root.message = parsed.error.message
        root.quoteEvent({ type: "error", code: parsed.error.code, message: parsed.error.message })
      } else {
        root.watchlistState = "ready"
        root.message = ""
        root.quoteEvent(parsed.event)
      }
      root.finishQueuedRefresh()
    }
  }

  Timer {
    interval: 300000
    repeat: true
    running: root.panelOpen && root.active
    onTriggered: root.refresh()
  }
}
