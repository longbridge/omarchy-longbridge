import QtQuick
import qs.Commons
import qs.Ui

CursorSurface {
  id: root

  required property string connectionState
  property string detail: ""
  property color textColor: Color.foreground
  property color warningColor: Color.urgent
  property string panelFontFamily: Style.font.family
  signal actionRequested()

  readonly property bool needsLogin: connectionState === "not_authenticated"
  readonly property bool failed: connectionState === "error" || connectionState === "disconnected"

  width: parent ? parent.width : implicitWidth
  implicitHeight: Style.space(42)
  bordered: true

  Rectangle {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(7)
    height: width
    radius: width / 2
    color: root.connectionState === "live" ? Color.accent
      : (root.failed || root.needsLogin ? root.warningColor : Qt.darker(root.textColor, 1.5))
  }

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(28)
    anchors.right: actionButton.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(1)

    Text {
      width: parent.width
      text: root.needsLogin ? "Connect Longbridge"
        : root.connectionState === "live" ? "Live market stream"
        : root.connectionState === "connecting" ? "Connecting to Longbridge"
        : root.connectionState === "disconnected" ? "Stream interrupted"
        : "Longbridge market data"
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: root.detail
      visible: text !== ""
      color: Qt.darker(root.textColor, 1.5)
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Button {
    id: actionButton
    anchors.right: parent.right
    anchors.rightMargin: Style.space(7)
    anchors.verticalCenter: parent.verticalCenter
    visible: root.needsLogin || root.failed
    text: root.needsLogin ? "Connect" : "Retry"
    bordered: true
    foreground: root.textColor
    fontFamily: root.panelFontFamily
    fontSize: Style.font.caption
    onClicked: root.actionRequested()
  }
}

