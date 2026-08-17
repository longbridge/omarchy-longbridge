import QtQuick
import "RpcAdapter.js" as RpcAdapter

// The panel's one live quote feed. Both tabs register the symbols they show;
// the feed keeps the union subscribed on the shared `longbridge serve` session
// and hands back `quote.updated` pushes, folded per symbol and released on a
// fixed tick. Nothing here polls — a symbol is subscribed once and then only
// speaks when the market moves.
Item {
  id: root

  property var session: null
  // While the panel is closed there is nobody to paint for, so pushes are
  // buffered instead of applied and the newest one per symbol wins.
  property bool active: false
  property int flushMs: 500

  readonly property bool live: session && session.ready && subscribed.length > 0
  readonly property int symbolCount: subscribed.length

  signal quotesUpdated(var quotes)

  property var owners: ({})
  property var subscribed: []
  property var pending: ({})
  property int pendingCount: 0

  // Each caller owns a named set of symbols; the subscription is their union,
  // so the watchlist releasing a symbol the portfolio still holds keeps it live.
  function setSymbols(owner, symbols) {
    var next = {}
    for (var key in owners) next[key] = owners[key]
    next[String(owner)] = RpcAdapter.symbolList(symbols)
    owners = next
    sync()
  }

  function release(owner) {
    var next = {}
    for (var key in owners) if (key !== String(owner)) next[key] = owners[key]
    owners = next
    sync()
  }

  // A restarted server has no subscriptions, so forget what was asked for
  // before the drop and let sync() request all of it again.
  function reset() {
    subscribed = []
    sync()
  }

  function wanted() {
    var seen = {}
    var result = []
    for (var owner in owners) {
      var symbols = owners[owner]
      for (var i = 0; i < symbols.length; i++) {
        if (seen[symbols[i]]) continue
        seen[symbols[i]] = true
        result.push(symbols[i])
      }
    }
    return RpcAdapter.subscribableSymbols(result)
  }

  function sync() {
    if (!session || !session.ready) return
    var next = wanted()
    var stale = difference(subscribed, next)
    var fresh = difference(next, subscribed)
    subscribed = next
    if (stale.length > 0) session.call("quote.unsubscribe", RpcAdapter.unsubscribeParams(stale), null)
    if (fresh.length === 0) return
    session.call("quote.subscribe", RpcAdapter.subscribeParams(fresh), function(error) {
      if (error) root.subscribed = difference(root.subscribed, fresh)
    })
  }

  function handlePush(params) {
    var event = RpcAdapter.quoteUpdateEvent(params)
    if (!event) return
    var next = {}
    for (var symbol in pending) next[symbol] = pending[symbol]
    next[event.symbol] = RpcAdapter.mergeQuote(next[event.symbol] || {}, event)
    pending = next
    pendingCount++
  }

  function flush() {
    if (pendingCount === 0) return
    var quotes = []
    for (var symbol in pending) quotes.push(pending[symbol])
    pending = ({})
    pendingCount = 0
    quotesUpdated(quotes)
  }

  function difference(values, other) {
    var excluded = {}
    for (var i = 0; i < other.length; i++) excluded[other[i]] = true
    var result = []
    for (var j = 0; j < values.length; j++) if (!excluded[values[j]]) result.push(values[j])
    return result
  }

  onActiveChanged: if (active) flush()

  Connections {
    target: root.session
    function onNotified(method, params) {
      if (method === "quote.updated") root.handlePush(params)
    }
    function onConnected() { root.reset() }
  }

  Timer {
    interval: root.flushMs
    repeat: true
    running: root.active
    onTriggered: root.flush()
  }
}
