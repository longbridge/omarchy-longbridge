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
  signal refreshRequested()

  readonly property color dimColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.58)
  readonly property real dayGain: Number(portfolio.dayGainValue || 0)
  readonly property real totalGain: Number(portfolio.totalGainValue || 0)
  readonly property color gainColor: "#63d297"
  readonly property color lossColor: "#ff6b7a"
  readonly property color trendColor: dayGain < 0 ? lossColor : gainColor
  width: parent ? parent.width : 0
  spacing: Style.space(12)

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
    return (amount < 0 ? "−" : "+") + money(amount, currency, compact)
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
    spacing: Style.space(10)
    Rectangle {
      width: Style.space(34); height: width; radius: width / 2
      color: root.alpha(root.textColor, 0.07)
      LongbridgeLogo { anchors.centerIn: parent; width: Style.space(18); height: width; foregroundColor: root.textColor; brandColors: true }
    }
    Column {
      width: parent.parent.width - Style.space(44)
      Text { text: "All accounts"; color: root.textColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.body; font.bold: true }
      Text { text: "Updated " + root.relativeTime(root.portfolio.updatedAt) + " · all values in " + root.portfolio.currency; color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption }
    }
  }

  Text {
    text: root.money(root.portfolio.netAssets, root.portfolio.currency, false)
    color: root.textColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.display; font.bold: true
  }
  Text {
    text: root.signedMoney(root.dayGain, root.portfolio.currency, false) + " today"
    color: root.trendColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true
  }

  Row {
    width: parent.width; spacing: Style.space(8)
    Repeater {
      model: [
        { label: "CASH · " + root.portfolio.currency, value: root.money(root.portfolio.totalCash, root.portfolio.currency, true) },
        { label: "MARKET VALUE", value: root.money(root.portfolio.marketValue, root.portfolio.currency, true) },
        { label: "POSITIONS", value: String((root.portfolio.positions || []).length) }
      ]
      Rectangle {
        required property var modelData
        width: (parent.width - parent.spacing * 2) / 3; implicitHeight: Style.space(62)
        radius: Style.cornerRadius; color: root.alpha(root.textColor, 0.04); border.width: 1; border.color: root.alpha(root.textColor, 0.12)
        Column {
          anchors.centerIn: parent; spacing: Style.space(3)
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.value; color: root.textColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
        }
      }
    }
  }

  Rectangle { width: parent.width; height: 1; color: root.alpha(root.textColor, 0.10) }
  Text { text: "POSITIONS · LIVE MARKET VALUE"; color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption; font.bold: true }

  Column {
    width: parent.width; spacing: Style.space(8)
    Repeater {
      model: root.portfolio.positions || []
      Rectangle {
        required property var modelData
        readonly property real gain: Number(modelData.day_gain || 0)
        readonly property color rowColor: gain < 0 ? root.lossColor : root.gainColor
        width: parent.width; implicitHeight: Style.space(70); radius: Style.cornerRadius
        color: root.alpha(root.textColor, 0.025); border.width: 1; border.color: root.alpha(root.textColor, 0.12)
        Text { id: symbolLabel; anchors.left: parent.left; anchors.top: parent.top; anchors.margins: Style.space(10); text: modelData.symbol; color: root.textColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
        Text { anchors.left: symbolLabel.right; anchors.right: valueLabel.left; anchors.verticalCenter: symbolLabel.verticalCenter; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8); text: modelData.name || ""; color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
        Text { id: valueLabel; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Style.space(10); text: root.money(modelData.market_value, modelData.currency, true); color: root.textColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
        Text { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: Style.space(10); text: modelData.quantity + " shares · avg " + root.money(modelData.cost_price, modelData.currency, false); color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption }
        Text { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: Style.space(10); text: "Today " + root.signedMoney(modelData.day_gain, modelData.currency, true); color: rowColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
      }
    }
    Text { visible: !root.loading && (root.portfolio.positions || []).length === 0; width: parent.width; text: root.portfolio.error || "No stock positions in this account."; color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.bodySmall; horizontalAlignment: Text.AlignHCenter; padding: Style.space(14) }
  }

  Row {
    width: parent.width
    Text { width: parent.width - refreshButton.width; text: root.bridgeMessage || (root.totalGain === 0 ? "Live Longbridge account data" : "Total P/L in report currency " + root.signedMoney(root.totalGain, root.portfolio.currency, true)); color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
    Button { id: refreshButton; text: root.loading ? "Loading…" : "Refresh"; enabled: !root.loading; foreground: root.textColor; fontFamily: root.panelFontFamily; onClicked: root.refreshRequested() }
  }
}
