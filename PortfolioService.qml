import QtQuick
import Quickshell.Io
import "CliAdapter.js" as CliAdapter

// Positions, cash and the account overview come from the CLI, which is the
// only place that aggregation exists. Prices do not: the holdings are
// subscribed on the shared feed, so market value and P/L move with the market
// instead of with a refresh timer. The snapshot is re-read on events — the tab
// being opened, or the session reconnecting — never on a schedule.
Item {
  id: root

  property var feed: null
  property bool panelOpen: false
  property bool active: false
  property string message: ""
  property var symbols: []
  readonly property bool loading: portfolioProcess.running
  readonly property bool live: feed ? feed.live && symbols.length > 0 : false

  signal portfolioEvent(var event)

  function refresh() {
    if (!panelOpen || !active || portfolioProcess.running) return
    message = ""
    portfolioProcess.command = CliAdapter.portfolioCommand()
    portfolioProcess.running = true
  }

  function subscribe(positions) {
    var wanted = []
    for (var i = 0; i < positions.length; i++) {
      var symbol = String(positions[i].symbol || "")
      if (symbol) wanted.push(symbol)
    }
    symbols = wanted
    if (feed) feed.setSymbols("portfolio", wanted)
  }

  function applyPushes(quotes) {
    var held = {}
    for (var i = 0; i < symbols.length; i++) held[symbols[i]] = true
    var mine = []
    for (var j = 0; j < quotes.length; j++) if (held[quotes[j].symbol]) mine.push(quotes[j])
    if (mine.length > 0) portfolioEvent({ type: "quotes", quotes: mine })
  }

  onPanelOpenChanged: if (panelOpen && active) Qt.callLater(refresh)
  onActiveChanged: if (panelOpen && active) Qt.callLater(refresh)

  Connections {
    target: root.feed
    function onQuotesUpdated(quotes) { root.applyPushes(quotes) }
  }

  Connections {
    target: root.feed && root.feed.session ? root.feed.session : null
    // Positions can have changed while the session was down, and the feed lost
    // its subscriptions, so both are re-established once on reconnect.
    function onConnected() {
      if (root.panelOpen && root.active) Qt.callLater(root.refresh)
    }
  }

  Process {
    id: portfolioProcess
    running: false
    command: []
    stdout: StdioCollector { id: portfolioOutput; waitForEnd: true }
    stderr: StdioCollector { id: portfolioErrors; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var failure = CliAdapter.classifyFailure(portfolioErrors.text, exitCode)
        root.message = failure.message
        root.portfolioEvent({ type: "error", code: failure.code, message: failure.message })
        return
      }
      var result = CliAdapter.parsePortfolio(portfolioOutput.text)
      if (!result.ok) {
        root.message = result.error.message
        root.portfolioEvent({ type: "error", code: result.error.code, message: result.error.message })
        return
      }
      root.portfolioEvent(result.event)
      root.subscribe(result.event.positions)
    }
  }
}
