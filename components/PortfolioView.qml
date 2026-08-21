import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../PortfolioModel.js" as PortfolioModel

Column {
  id: root

  required property var portfolio
  required property color textColor
  required property color accentColor
  required property color warningColor
  required property color gainColor
  required property color lossColor
  required property string panelFontFamily
  property bool loading: false
  property string bridgeMessage: ""
  property int selectedIndex: 0
  property bool detailOpen: false
  property bool live: false
  property bool connecting: false

  readonly property color dimColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.58)
  readonly property real dayGain: Number(portfolio.dayGainValue || 0)
  readonly property real totalGain: Number(portfolio.totalGainValue || 0)
  readonly property color trendColor: dayGain < 0 ? lossColor : gainColor
  readonly property var allocation: PortfolioModel.allocation(portfolio)
  // Keyed by symbol for the same reason as the watchlist: the positions array
  // is rebuilt on every live tick, and handing that to the list rebuilt every
  // delegate and threw the scroll position back to the top.
  property var holdingKeys: []
  property var holdingIndex: ({})

  readonly property var selectedHolding: holdingKeys.length > 0
    ? holdingFor(holdingKeys[Math.max(0, Math.min(selectedIndex, holdingKeys.length - 1))]) : null

  function holdingFor(symbol) {
    return holdingIndex[symbol] || { symbol: symbol, currency: "", quantity: "0", market_value: "0", day_gain: "0", total_gain: "0" }
  }

  function syncHoldings() {
    var rows = portfolio.positions || []
    var keys = []
    var index = {}
    for (var i = 0; i < rows.length; i++) {
      var symbol = String(rows[i].symbol || "")
      if (!symbol) continue
      keys.push(symbol)
      index[symbol] = rows[i]
    }
    holdingIndex = index
    if (keys.join("\u0000") === holdingKeys.join("\u0000")) return
    var offset = holdingsList.contentY
    holdingKeys = keys
    Qt.callLater(function() {
      holdingsList.contentY = Math.max(0, Math.min(offset, Math.max(0, holdingsList.contentHeight - holdingsList.height)))
    })
  }

  onPortfolioChanged: syncHoldings()
  Component.onCompleted: syncHoldings()

  width: parent ? parent.width : 0
  spacing: Style.space(8)

  function alpha(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity) }
  function gainLossColor(value) { return Number(value || 0) < 0 ? root.lossColor : root.gainColor }
  // Risk uses the theme's accent for safe and warning role for elevated risk;
  // the label carries the exact level without relying on color alone.
  function riskColor(level) {
    var value = Number(level)
    if (value === 0) return root.gainColor
    if (value === 1 || value === 2) return root.warningColor
    if (value === 3) return root.lossColor
    return root.textColor
  }

  function allocationColor(label, index) {
    if (label === "US") return root.accentColor
    if (label === "HK") return root.warningColor
    if (label === "CN") return root.alpha(root.accentColor, 0.72)
    if (label === "SG") return root.alpha(root.warningColor, 0.72)
    if (label === "CASH") return root.alpha(root.textColor, 0.35)
    var spare = [root.accentColor, root.warningColor, root.textColor]
    return spare[index % spare.length]
  }
  function signedPercent(value) {
    var amount = Number(value || 0)
    return (amount > 0 ? "+" : amount < 0 ? "−" : "") + Math.abs(amount).toFixed(2) + "%"
  }
  function money(value, currency, compact) {
    var amount = Number(value || 0)
    var suffix = ""
    if (compact && Math.abs(amount) >= 1000000) { amount /= 1000000; suffix = "M" }
    else if (compact && Math.abs(amount) >= 1000) { amount /= 1000; suffix = "K" }
    // The tiles omit the currency: the header line and net assets already name
    // it, and repeating it four times is what pushed this row over the edge.
    var prefix = currency ? String(currency) + " " : ""
    return prefix + Math.abs(amount).toLocaleString(Qt.locale(), "f", compact ? 1 : 2) + suffix
  }
  function signedMoney(value, currency, compact) {
    var amount = Number(value || 0)
    return (amount > 0 ? "+" : amount < 0 ? "−" : "") + money(amount, currency, compact)
  }

  // Total assets is the headline; the account label and the "updated" line said
  // less than the number itself, and the live indicator already reports whether
  // it is current.
  Row {
    width: parent.width
    spacing: Style.space(8)

    Text {
      width: Math.max(0, root.width - liveIndicator.width - Style.space(8))
      anchors.verticalCenter: parent.verticalCenter
      text: root.money(root.portfolio.netAssets, root.portfolio.currency, false)
      color: root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.title
      font.bold: true
      elide: Text.ElideRight
    }

    LiveIndicator {
      id: liveIndicator
      anchors.verticalCenter: parent.verticalCenter
      textColor: root.textColor
      liveColor: root.gainColor
      panelFontFamily: root.panelFontFamily
      live: root.live
      connecting: root.connecting
    }
  }

  // P/L and today's P/L get a line to themselves, at full precision: they are
  // the two numbers this tab exists for. Cash and market value follow.
  Row {
    width: parent.width
    spacing: Style.space(6)
    Repeater {
      model: [
        { label: "P/L", value: root.signedMoney(root.totalGain, root.portfolio.currency, false), tint: root.gainLossColor(root.totalGain) },
        { label: "TODAY P/L", value: root.signedMoney(root.dayGain, root.portfolio.currency, false), tint: root.gainLossColor(root.dayGain) }
      ]
      Rectangle {
        required property var modelData
        width: (root.width - Style.space(6)) / 2
        implicitHeight: Style.space(46)
        radius: Style.cornerRadius
        color: root.alpha(root.textColor, 0.04)
        border.width: 1
        border.color: root.alpha(root.textColor, 0.12)
        Column {
          anchors.centerIn: parent
          spacing: 0
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.value; color: modelData.tint; font.family: root.panelFontFamily; font.pixelSize: Style.font.body; font.bold: true }
        }
      }
    }
  }

  // Where the account actually sits, by market and cash. The palette is
  // categorical and deliberately avoids red and green, which mean rise and fall
  // everywhere else in this panel.
  Column {
    width: parent.width
    spacing: Style.space(5)
    visible: root.allocation.length > 0

    Rectangle {
      width: parent.width
      height: Style.space(6)
      radius: height / 2
      color: root.alpha(root.textColor, 0.08)
      clip: true
      Row {
        anchors.fill: parent
        Repeater {
          model: root.allocation
          Rectangle {
            required property var modelData
            required property int index
            width: Math.max(1, parent.width * modelData.share)
            height: parent.height
            color: root.allocationColor(modelData.label, index)
          }
        }
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(10)
      Repeater {
        model: root.allocation
        Row {
          required property var modelData
          required property int index
          spacing: Style.space(4)
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(6); height: Style.space(6); radius: width / 2
            color: root.allocationColor(modelData.label, index)
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label + " " + (modelData.share * 100).toFixed(1) + "%"
            color: root.dimColor
            font.family: root.panelFontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(6)
    Repeater {
      model: [
        { label: "CASH", value: root.money(root.portfolio.totalCash, "", true), tint: root.textColor },
        { label: "MARKET", value: root.money(root.portfolio.marketValue, "", true), tint: root.textColor },
        { label: "RISK", value: PortfolioModel.riskLevelName(root.portfolio.riskLevel), tint: root.riskColor(root.portfolio.riskLevel) },
        { label: "CREDIT", value: root.money(root.portfolio.creditLimit, "", true), tint: root.textColor }
      ]
      Rectangle {
        required property var modelData
        width: (root.width - Style.space(18)) / 4
        implicitHeight: Style.space(34)
        radius: Style.cornerRadius
        color: root.alpha(root.textColor, 0.025)
        border.width: 1
        border.color: root.alpha(root.textColor, 0.10)
        Row {
          anchors.centerIn: parent
          spacing: Style.space(5)
          Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: root.dimColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption }
          Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.value; color: modelData.tint || root.textColor; font.family: root.panelFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
        }
      }
    }
  }

  Rectangle {
    id: holdingsFrame
    visible: !root.detailOpen
    width: parent.width
    height: Math.min(Style.space(386), Math.max(Style.space(88), holdingsList.contentHeight))
    radius: 0
    color: "transparent"
    border.width: 0
    clip: true

    ListView {
      id: holdingsList
      anchors.fill: parent
      anchors.margins: 0
      model: root.holdingKeys
      currentIndex: root.selectedIndex
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: HoldingRow {
        required property string modelData
        required property int index
        holding: root.holdingFor(modelData)
        textColor: root.textColor
        gainColor: root.gainColor
        lossColor: root.lossColor
        panelFontFamily: root.panelFontFamily
        selected: index === root.selectedIndex
        striped: index % 2 === 0
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
        Column {
          width: parent.width - backButton.width
          spacing: Style.space(1)
          Text {
            width: parent.width
            text: String(root.selectedHolding && root.selectedHolding.name || "").toUpperCase()
            color: root.dimColor
            font.family: root.panelFontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: String(root.selectedHolding && root.selectedHolding.symbol || "")
            color: root.textColor
            font.family: root.panelFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }
        }
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
            { label: "MARKET VALUE", value: root.money(root.selectedHolding.market_value, root.selectedHolding.currency, false) },
            { label: "INTRADAY", value: root.signedMoney(root.selectedHolding.day_gain, "", false)
              + "  " + root.signedPercent(PortfolioModel.intradayPercent(root.selectedHolding)) },
            { label: "FLOATING", value: root.signedMoney(root.selectedHolding.total_gain, "", false)
              + "  " + root.signedPercent(PortfolioModel.floatingPercent(root.selectedHolding)) },
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
