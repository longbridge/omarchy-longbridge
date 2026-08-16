import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../SetupAdapter.js" as SetupAdapter

Column {
  id: root

  required property color textColor
  required property string panelFontFamily
  property bool panelOpen: false
  property bool previewInstallGuide: false
  property bool cliInstalled: false
  property bool dismissible: false
  property string setupState: "idle"
  property string message: "Checking Longbridge…"
  readonly property bool ready: setupState === "ready"
  readonly property bool showingInstall: previewInstallGuide
    || setupState === "needs_install" || setupState === "install_failed"
  readonly property bool busy: availabilityProcess.running || installProcess.running
    || loginProcess.running || verifyProcess.running
  signal setupCompleted()
  signal dismissed()

  width: parent ? parent.width : 0
  spacing: Style.space(16)

  function checkAvailability() {
    if (busy) return
    setupState = "checking"
    message = "Checking Longbridge…"
    availabilityProcess.command = SetupAdapter.availabilityCommand()
    availabilityProcess.running = true
  }

  function installCli() {
    if (busy) return
    setupState = "installing"
    message = "Installing Longbridge CLI…"
    installProcess.command = SetupAdapter.installCommand()
    installProcess.running = true
  }

  function login() {
    if (busy) return
    setupState = "logging_in"
    message = "Complete Longbridge login in the browser…"
    loginProcess.command = SetupAdapter.loginCommand()
    loginProcess.running = true
  }

  function verifyLogin() {
    if (verifyProcess.running) return
    setupState = "verifying"
    message = "Verifying Longbridge login…"
    verifyProcess.command = SetupAdapter.checkCommand()
    verifyProcess.running = true
  }

  onPanelOpenChanged: if (panelOpen && setupState === "idle") Qt.callLater(checkAvailability)

  Item {
    width: parent.width
    implicitHeight: Style.space(54)

    LongbridgeLogo {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(28)
      height: width
      foregroundColor: root.textColor
      brandColors: true
    }

    Column {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(40)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)
      Text {
        text: "Welcome to Longbridge"
        color: root.textColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }
      Text {
        width: parent.width
        text: "Connect Longbridge Terminal to continue."
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.58)
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }
    }
  }

  Rectangle {
    width: parent.width
    implicitHeight: setupColumn.implicitHeight + Style.space(28)
    radius: Style.cornerRadius
    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.04)
    border.width: 1
    border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)

    Column {
      id: setupColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(14)
      spacing: Style.space(10)

      Text {
        width: parent.width
        text: root.showingInstall
          ? "Install the official Longbridge CLI"
          : "Sign in to your Longbridge account"
        color: root.textColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        width: parent.width
        visible: root.showingInstall
        text: "Installer source: github.com/longbridge/longbridge-terminal"
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.58)
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WrapAnywhere
      }
      Text {
        width: parent.width
        text: root.message
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.68)
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }
      Button {
        visible: root.showingInstall
        text: "Install Longbridge CLI"
        foreground: root.textColor
        bordered: true
        enabled: !root.busy
        onClicked: root.installCli()
      }
      Button {
        visible: root.dismissible
        text: "Back"
        foreground: root.textColor
        bordered: false
        enabled: !root.busy
        onClicked: root.dismissed()
      }
      Button {
        visible: root.setupState === "needs_login" || root.setupState === "login_failed"
        text: "Log in to Longbridge"
        foreground: root.textColor
        bordered: true
        enabled: !root.busy
        onClicked: root.login()
      }
      Button {
        visible: root.setupState === "check_failed"
        text: "Try again"
        foreground: root.textColor
        bordered: true
        enabled: !root.busy
        onClicked: root.checkAvailability()
      }
    }
  }

  Process {
    id: availabilityProcess
    running: false
    command: []
    stdout: StdioCollector { id: availabilityOutput; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0 && String(availabilityOutput.text || "").trim() !== "") {
        root.cliInstalled = true
        root.verifyLogin()
      } else {
        root.cliInstalled = false
        root.setupState = "needs_install"
        root.message = "Longbridge CLI is required before this plugin can be used."
      }
    }
  }

  Process {
    id: installProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.checkAvailability()
      else {
        root.setupState = "install_failed"
        root.message = "Longbridge CLI installation failed. Try again."
      }
    }
  }

  Process {
    id: loginProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.verifyLogin()
      else {
        root.setupState = "login_failed"
        root.message = "Longbridge login was not completed."
      }
    }
  }

  Process {
    id: verifyProcess
    running: false
    command: []
    stdout: StdioCollector { id: verifyOutput; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      var result = exitCode === 0 ? SetupAdapter.parseCheck(verifyOutput.text)
        : ({ ok: false, authenticated: false, message: "Could not verify Longbridge login." })
      if (result.ok && result.authenticated) {
        root.setupState = "ready"
        root.message = result.message
        root.setupCompleted()
      } else if (result.ok) {
        root.setupState = "needs_login"
        root.message = result.message
      } else {
        root.setupState = "check_failed"
        root.message = result.message
      }
    }
  }
}
