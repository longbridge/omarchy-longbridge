import QtQuick

Item {
  id: root
  property color foregroundColor: "#ffffff"
  property bool brandColors: false
  readonly property real scaleUnit: Math.min(width, height) / 69
  readonly property real offsetX: (width - 69 * scaleUnit) / 2
  readonly property real offsetY: (height - 69 * scaleUnit) / 2
  implicitWidth: 69
  implicitHeight: 69

  Rectangle {
    objectName: "foregroundTall"
    x: root.offsetX; y: root.offsetY
    width: 3 * root.scaleUnit; height: 69 * root.scaleUnit
    color: root.foregroundColor
  }
  Rectangle {
    objectName: "tealTall"
    x: root.offsetX + 7 * root.scaleUnit; y: root.offsetY
    width: 10 * root.scaleUnit; height: 69 * root.scaleUnit
    color: root.brandColors ? "#00DBB6" : root.foregroundColor
  }
  Rectangle {
    objectName: "yellowSquare"
    x: root.offsetX + 21 * root.scaleUnit; y: root.offsetY + 60 * root.scaleUnit
    width: 9 * root.scaleUnit; height: 9 * root.scaleUnit
    color: root.brandColors ? "#FFE000" : root.foregroundColor
  }
  Rectangle {
    objectName: "foregroundShort"
    x: root.offsetX + 33 * root.scaleUnit; y: root.offsetY + 60 * root.scaleUnit
    width: 3 * root.scaleUnit; height: 9 * root.scaleUnit
    color: root.foregroundColor
  }
  Rectangle {
    objectName: "orangeBlock"
    x: root.offsetX + 40 * root.scaleUnit; y: root.offsetY + 52 * root.scaleUnit
    width: 10 * root.scaleUnit; height: 17 * root.scaleUnit
    color: root.brandColors ? "#FC5200" : root.foregroundColor
  }
  Rectangle {
    objectName: "foregroundBlock"
    x: root.offsetX + 53 * root.scaleUnit; y: root.offsetY + 43 * root.scaleUnit
    width: 9 * root.scaleUnit; height: 26 * root.scaleUnit
    color: root.foregroundColor
  }
  Rectangle {
    objectName: "orangeTall"
    x: root.offsetX + 66 * root.scaleUnit; y: root.offsetY + 26 * root.scaleUnit
    width: 3 * root.scaleUnit; height: 43 * root.scaleUnit
    color: root.brandColors ? "#FC5200" : root.foregroundColor
  }
}
