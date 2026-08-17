// Manual smoke harness for the `longbridge serve` data path. Quickshell.Io
// types only exist inside the quickshell runtime, so this runs the real
// Process wiring the way qmltestrunner cannot.
//
//   make smoke        against tests/bin/longbridge, offline
//   make smoke-live   against the installed CLI and your own account
//
// It opens the panel, closes it and reopens it, reporting how long each open
// waits for data — a cold open pays for process start, auth and the market
// WebSocket, a reopen inside the linger window should pay almost nothing — and
// then reports the pushes both tabs receive from the one shared subscription.
//
import QtQuick
import Quickshell
import "."

ShellRoot {
  id: harness

  property double openedAt: 0
  property int opens: 0
  property bool open: false

  function markOpen() {
    harness.opens++
    harness.openedAt = Date.now()
    console.log("open #" + harness.opens)
    harness.open = true
  }

  LongbridgeRpc {
    id: session
    serving: harness.open
  }

  QuoteFeed {
    id: feed
    session: session
    active: harness.open
  }

  WatchlistService {
    id: watchlist
    session: session
    feed: feed
    panelOpen: harness.open
    active: true
    onGroupsEvent: function(groups, defaultGroupId) {
      console.log("groups:", groups.length, "default:", defaultGroupId)
    }
    onQuoteEvent: function(event) {
      if (event.type === "chart") {
        console.log("  chart:", event.symbol, event.series.points.length, "points",
          "min", event.series.min, "max", event.series.max)
        return
      }
      if (event.type !== "snapshot") {
        console.log("  event:", JSON.stringify(event).substring(0, 120))
        return
      }
      if (harness.openedAt > 0) {
        console.log("  data on screen after", Math.round(Date.now() - harness.openedAt), "ms")
        harness.openedAt = 0
      }
      console.log("  watchlist batch:", event.quotes.length, "quotes")
    }
  }

  PortfolioService {
    id: portfolio
    feed: feed
    panelOpen: harness.open
    active: true
    onPortfolioEvent: function(event) {
      if (event.type === "portfolio") console.log("  portfolio:", event.positions.length, "positions", event.net_assets, event.currency)
      else if (event.type === "quotes") console.log("  portfolio repriced:", event.quotes.length, "holdings")
      else console.log("  portfolio event:", JSON.stringify(event).substring(0, 120))
    }
  }

  Component.onCompleted: harness.markOpen()

  // Rows ask for their own line; the harness has no list, so it asks for the
  // first few directly to exercise the same path.
  Timer {
    interval: 4000
    running: true
    onTriggered: {
      var symbols = watchlist.activeSymbols().slice(0, 3)
      for (var i = 0; i < symbols.length; i++) watchlist.requestChart(symbols[i])
    }
  }

  Timer {
    interval: 8000
    running: true
    onTriggered: {
      console.log("panel closed — session lingers")
      harness.open = false
    }
  }

  Timer {
    interval: 12000
    running: true
    onTriggered: harness.markOpen()
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: console.log("state:", watchlist.watchlistState,
      "session:", session.status, "live:", feed.live, "subscribed:", feed.symbolCount)
  }
}
