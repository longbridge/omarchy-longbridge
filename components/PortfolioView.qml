import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Column {
  id: root

  required property var portfolio
  required property color textColor
  required property color accentColor
  required property color warningColor
  required property string panelFontFamily
  property bool loading: false
  property string bridgeMessage: ""
  property int selectedIndex: 0
  property bool detailOpen: false
  signal refreshRequested()

  readonly property color dimColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.58)
  readonly property real dayGain: Number(portfolio.dayGainValue || 0)
  readonly property real totalGain: Number(portfolio.totalGainValue || 0)
  readonly property color gainColor: "#63d297"
  readonly property color lossColor: "#ff6b7a"
  readonly property color trendColor: dayGain < 0 ? lossColor : gainColor
  readonly property var selectedHolding: (portfolio.positions || []).length > 0
    ? portfolio.positions[Math.max(0, Math.min(selectedIndex, portfolio.positions.length - 1))] : null

  width: parent ? parent.width : 0
  spacing: Style.space(8)

  function alpha(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity) }
  function money(value, currency, compact) {
    var amount = Number(value || 0)
    var suffix = ""
    if (compact && Math.abs(amount) >= 1000000) { amount /= 1000000; suffix = "M" }
    else if (compact && Math.abs(amount) >= 1000) { amount /= 1000; suffix = "K" }
    return String(currency || "") + " " + Math.abs(amount).toLocaleString(Qt.locale(), "f", compact ? 1 : 2) + suffix
  }
  function signedMoney(value, currency, compact) {
    var amount = Number(value || 0)
    return (amount > 0 ? "+" : amount < 0 ? "−" : "") + money(amount, currency, compact)
  }
  function relativeTime(timestamp) {
    if (!timestamp) return "waiting"
    var seconds = Math.max(0, Date.now() / 1000 - Number(timestamp))
    if (seconds < 60) return "just now"
    if (seconds < 3600) return Math.floor(seconds / 60) + "m ago"
    return Math.floor(seconds / 3600) + "h ago"
  }

  Row {
    width: parent.width
    spacing: Style.space(8)
    Column {
      width: Math.max(0, root.width - refreshButton.width - Style.space(8))
      spacing: 0
      Text {
        text: "All accounts"
        color: root.textColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        text: "Updated " + root.relativeTime(root.portfolio.updatedAt) + " · " + root.portfolio.currency
        color: root.dimColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption
      }
    }
    PanelActionButton {
      id: refreshButton
      iconText: "󰑐"
      tooltipText: "Refresh"
      foreground: root.textColor
      fontFamily: root.panelFontFamily
      size: Style.space(28)
      bordered: false
      enabled: !root.loading
      onClicked: root.refreshRequested()
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(12)
    Text {
      text: root.money(root.portfolio.netAssets, root.portfolio.currency, false)
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }
    Text {
      anchors.baseline: parent.children[0].baseline
      text: root.signedMoney(root.dayGain, root.portfolio.currency, false) + " today"
      color: root.trendColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(6)
    Repeater {
      model: [
        { label: "CASH", value: root.money(root.portfolio.totalCash, root.portfolio.currency, true) },
        { label: "MARKET", value: root.money(root.portfolio.marketValue, root.portfolio.currency, true) },
        { label: "POSITIONS", value: String((root.portfolio.positions || []).length) }
      ]
      Rectangle {
        required property var modelData
        width: (root.width - Style.space(12)) / 3
        implicitHeight: Style.space(46)
        radius: Style.cornerRadius
        color: root.alpha(root.textColor, 0.04)
        border.width: 1
        border.color: root.alpha(root.textColor, 0.12)
        Column {
          anchors.centerIn: parent
          spacing: 0
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.value; color: root.textColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
        }
      }
    }
  }

  Rectangle {
    visible: !root.detailOpen
    width: parent.width
    height: Math.min(Style.space(308), Math.max(Style.space(88), holdingsList.contentHeight))
    radius: Style.cornerRadius
    color: root.alpha(root.textColor, 0.025)
    border.width: 1
    border.color: root.alpha(root.textColor, 0.10)
    clip: true

    ListView {
      id: holdingsList
      anchors.fill: parent
      anchors.margins: 1
      model: root.portfolio.positions || []
      currentIndex: root.selectedIndex
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: HoldingRow {
        required property var modelData
        required property int index
        holding: modelData
        textColor: root.textColor
        panelFontFamily: root.panelFontFamily
        selected: index === root.selectedIndex
        onActivated: {
          root.selectedIndex = index
          root.detailOpen = true
        }
      }

      Text {
        visible: !root.loading && (root.portfolio.positions || []).length === 0
        anchors.centerIn: parent
        text: root.portfolio.error || "No stock positions in this account."
        color: root.dimColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  Rectangle {
    visible: root.detailOpen && root.selectedHolding !== null
    width: parent.width
    implicitHeight: detailColumn.implicitHeight + Style.space(24)
    radius: Style.cornerRadius
    color: root.alpha(root.textColor, 0.04)
    border.width: 1
    border.color: root.alpha(root.textColor, 0.12)
    Column {
      id: detailColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(12)
      spacing: Style.space(7)
      Row {
        width: parent.width
        Text { width: parent.width - backButton.width; text: String(root.selectedHolding && root.selectedHolding.symbol || ""); color: root.textColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.body; font.bold: true }
        Button { id: backButton; text: "Back"; foreground: root.textColor; bordered: true; onClicked: root.detailOpen = false }
      }
      Grid {
        columns: 2
        columnSpacing: Style.space(18)
        rowSpacing: Style.space(4)
        Repeater {
          model: root.selectedHolding ? [
            { label: "QUANTITY", value: root.selectedHolding.quantity },
            { label: "AVAILABLE", value: root.selectedHolding.available_quantity },
            { label: "MARKET PRICE", value: root.money(root.selectedHolding.last, root.selectedHolding.currency, false) },
            { label: "AVERAGE COST", value: root.money(root.selectedHolding.cost_price, root.selectedHolding.currency, false) },
            { label: "TOTAL P/L", value: root.signedMoney(root.selectedHolding.total_gain, root.selectedHolding.currency, false) },
            { label: "CURRENCY", value: root.selectedHolding.currency }
          ] : []
          Column {
            required property var modelData
            width: (root.width - Style.space(18)) / 2
            spacing: 0
            Text { text: modelData.label; color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption }
            Text { text: modelData.value; color: root.textColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
          }
        }
      }
    }
  }

  Text {
    visible: root.bridgeMessage !== ""
    width: parent.width
    text: root.bridgeMessage
    color: root.dimColor
    font.family: root.panelFontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }
}
