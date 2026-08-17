import QtQuick
import qs.Commons

// Streaming state for a tab. There is no refresh control to replace it with:
// the panel either has a live subscription or it says why it does not, and
// both answers are readable at a glance. Its state color follows the active
// theme rather than introducing a plugin-specific palette.
Row {
  id: root

  required property color textColor
  required property color liveColor
  required property string panelFontFamily
  property bool live: false
  property bool connecting: false
  // The theme's market green reads as "active" at a glance; the label carries
  // the state for anyone who cannot distinguish it by color.
  property string label: root.live ? "LIVE" : (root.connecting ? "CONNECTING" : "OFFLINE")

  spacing: Style.space(5)

  Rectangle {
    id: dot
    objectName: "liveDot"
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(6)
    height: width
    radius: width / 2
    color: root.live
      ? root.liveColor
      : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.30)

  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, root.live ? 0.70 : 0.45)
    font.family: root.panelFontFamily
    font.pixelSize: Style.font.caption
  }
}
