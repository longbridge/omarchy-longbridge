import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  required property color textColor
  required property string panelFontFamily
  signal installCliRequested()

  implicitWidth: Style.space(28)
  implicitHeight: Style.space(28)

  function openLongbridge() {
    Quickshell.execDetached(["xdg-open", "https://longbridge.com"])
    menu.close()
  }

  function openCliDocs() {
    Quickshell.execDetached(["xdg-open", "https://open.longbridge.com/docs/cli/"])
    menu.close()
  }

  function openGitHub() {
    Quickshell.execDetached(["xdg-open", "https://github.com/longbridge/omarchy-longbridge"])
    menu.close()
  }

  function showInstallGuide() {
    menu.close()
    root.installCliRequested()
  }

  Button {
    id: menuButton
    anchors.fill: parent
    text: "⋮"
    foreground: root.textColor
    bordered: false
    onClicked: menu.opened ? menu.close() : menu.open()
  }

  QQC.Popup {
    id: menu
    x: menuButton.width - width
    y: menuButton.height + Style.space(4)
    width: Style.space(176)
    implicitHeight: menuItems.implicitHeight + Style.space(8)
    padding: Style.space(4)
    modal: false
    focus: true
    closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside
    background: Rectangle {
      radius: Style.cornerRadius
      color: Color.background
      border.width: 1
      border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.16)
    }
    contentItem: Column {
      id: menuItems
      spacing: Style.space(2)
      MenuRow { text: "Longbridge"; onActivated: root.openLongbridge() }
      MenuRow { text: "Longbridge CLI"; onActivated: root.openCliDocs() }
      MenuRow { text: "GitHub"; onActivated: root.openGitHub() }

      // Links above, the thing that changes this machine below.
      Item {
        width: menu.width - menu.leftPadding - menu.rightPadding
        implicitHeight: Style.space(7)
        PanelSeparator {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          foreground: root.textColor
        }
      }

      MenuRow { text: "Install CLI"; onActivated: root.showInstallGuide() }
    }
  }

  component MenuRow: Rectangle {
    id: row
    required property string text
    signal activated()
    width: menu.width - menu.leftPadding - menu.rightPadding
    implicitHeight: Style.space(34)
    radius: Style.cornerRadius
    color: hover.hovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08) : "transparent"
    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(9)
      anchors.verticalCenter: parent.verticalCenter
      text: row.text
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.bodySmall
    }
    HoverHandler { id: hover }
    TapHandler { onTapped: row.activated() }
  }
}
