import QtQuick
import Quickshell.Io
import "CliAdapter.js" as CliAdapter

Item {
  id: root

  property bool panelOpen: false
  property bool active: false
  property string message: ""
  readonly property bool loading: portfolioProcess.running
  signal portfolioEvent(var event)

  function refresh() {
    if (!panelOpen || !active || portfolioProcess.running) return
    message = ""
    portfolioProcess.command = CliAdapter.portfolioCommand()
    portfolioProcess.running = true
  }

  onPanelOpenChanged: if (panelOpen && active) Qt.callLater(refresh)
  onActiveChanged: if (panelOpen && active) Qt.callLater(refresh)

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
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: root.panelOpen && root.active
    onTriggered: root.refresh()
  }
}
