import QtQuick
import qs.Commons

// The mark and the wordmark as one lockup. Alignment lives here rather than in
// every header that uses it: the word's baseline sits exactly on the bottom
// edge of the mark, which anchoring the two boxes to each other can only
// approximate — a text box carries descender space below its baseline.
Item {
  id: root

  required property color foreground
  property string fontFamily: Style.font.family
  property int fontSize: Style.font.heading
  // Tied to the wordmark rather than to whatever sits beside it: the mark is a
  // letterform here, so it scales with the type it is set with. Matching a
  // control's box height instead made it read as a badge.
  property real markSize: Math.round(fontSize * 1.08)
  property real gap: Style.space(8)
  property bool brandColors: true
  property string label: "Longbridge"

  implicitWidth: mark.width + root.gap + word.implicitWidth
  implicitHeight: mark.height
  baselineOffset: mark.height

  LongbridgeLogo {
    id: mark
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    width: root.markSize
    height: width
    foregroundColor: root.foreground
    brandColors: root.brandColors
  }

  Text {
    id: word
    anchors.left: mark.right
    anchors.leftMargin: root.gap
    anchors.right: parent.right
    // Not anchored vertically: the baseline is placed on the mark's foot, and
    // the descenders fall below it the way they do in any line of type.
    y: root.height - word.baselineOffset
    text: root.label
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    font.bold: true
    elide: Text.ElideRight
  }
}
