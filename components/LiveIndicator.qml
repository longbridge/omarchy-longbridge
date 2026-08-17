import QtQuick
import qs.Commons

// Streaming state for a tab. There is no refresh control to replace it with:
// the panel either has a live subscription or it says why it does not, and
// both answers are readable at a glance. Theme-neutral by rule — red and green
// belong to rise and fall alone.
Row {
  id: root

  required property color textColor
  required property string panelFontFamily
  property bool live: false
  property bool connecting: false
  // Green reads as "streaming" at a glance, the way it does everywhere else a
  // feed is running; the label carries the state for anyone who cannot use it.
  property color liveColor: "#63d297"
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

    SequentialAnimation on opacity {
      running: root.live || root.connecting
      loops: Animation.Infinite
      NumberAnimation { from: 1.0; to: 0.35; duration: root.live ? 1400 : 700; easing.type: Easing.InOutQuad }
      NumberAnimation { from: 0.35; to: 1.0; duration: root.live ? 1400 : 700; easing.type: Easing.InOutQuad }
    }
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, root.live ? 0.70 : 0.45)
    font.family: root.panelFontFamily
    font.pixelSize: Style.font.caption
  }
}
