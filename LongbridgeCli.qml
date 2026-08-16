import QtQuick
import Quickshell
import Quickshell.Io
import "CliAdapter.js" as CliAdapter

Item {
  id: root
  property var watchlist: []
  property bool panelOpen: false
  property bool portfolioActive: false
  property string quoteState: "idle"
  property string quoteMessage: ""
  property string portfolioMessage: ""
  readonly property bool portfolioLoading: portfolioProcess.running
  signal quoteEvent(var event)
  signal portfolioEvent(var event)

  function refreshQuotes() {
    if (quoteProcess.running || watchlist.length === 0) return
    quoteState = "connecting"
    quoteMessage = ""
    quoteProcess.command = CliAdapter.quoteCommand(watchlist)
    quoteProcess.running = true
  }

  function refreshPortfolio() {
    if (portfolioProcess.running) return
    portfolioMessage = ""
    portfolioProcess.command = CliAdapter.portfolioCommand()
    portfolioProcess.running = true
  }

  function emitQuoteFailure(detail, exitCode) {
    var failure = CliAdapter.classifyFailure(detail, exitCode)
    quoteState = failure.code === "not_authenticated" ? "not_authenticated" : "error"
    quoteMessage = failure.message
    quoteEvent({ type: "error", code: failure.code, message: failure.message })
  }

  function emitPortfolioFailure(detail, exitCode) {
    var failure = CliAdapter.classifyFailure(detail, exitCode)
    portfolioMessage = failure.message
    portfolioEvent({ type: "error", code: failure.code, message: failure.message })
  }

  onWatchlistChanged: if (panelOpen) Qt.callLater(refreshQuotes)
  onPanelOpenChanged: if (panelOpen) {
    refreshQuotes()
    if (portfolioActive) refreshPortfolio()
  }
  onPortfolioActiveChanged: if (panelOpen && portfolioActive) refreshPortfolio()

  Process {
    id: quoteProcess
    running: false
    command: []
    stdout: StdioCollector { id: quoteOutput; waitForEnd: true }
    stderr: StdioCollector { id: quoteErrors; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.emitQuoteFailure(quoteErrors.text, exitCode)
        return
      }
      var result = CliAdapter.parseQuotes(quoteOutput.text)
      if (!result.ok) {
        root.emitQuoteFailure("", 1)
        return
      }
      root.quoteState = "live"
      root.quoteMessage = "Updated from Longbridge CLI."
      root.quoteEvent(result.event)
      root.quoteEvent({ type: "subscription", symbols: root.watchlist })
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
        root.emitPortfolioFailure(portfolioErrors.text, exitCode)
        return
      }
      var result = CliAdapter.parsePortfolio(portfolioOutput.text)
      if (!result.ok) {
        root.portfolioMessage = result.error.message
        root.portfolioEvent({ type: "error", code: result.error.code, message: result.error.message })
        return
      }
      root.portfolioMessage = "Updated from Longbridge CLI."
      root.portfolioEvent(result.event)
    }
  }

  Timer {
    interval: 15000
    running: root.panelOpen
    repeat: true
    onTriggered: root.refreshQuotes()
  }

  Timer {
    interval: 60000
    running: root.panelOpen && root.portfolioActive
    repeat: true
    onTriggered: root.refreshPortfolio()
  }
}
