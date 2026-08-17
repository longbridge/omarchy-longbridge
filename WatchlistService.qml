import QtQuick
import Quickshell
import Quickshell.Io
import "CacheAdapter.js" as CacheAdapter
import "ChartAdapter.js" as ChartAdapter
import "RpcAdapter.js" as RpcAdapter

// Watchlist membership and the first snapshot come from the shared
// `longbridge serve` session; everything after that arrives on the push feed.
// Nothing polls: a request happens when something happens — the panel opens,
// the session reconnects, a group is selected, or a symbol crosses into
// another trading session.
Item {
  id: root

  property var session: null
  property var feed: null
  property bool panelOpen: false
  property bool active: false
  property var groups: []
  property string defaultGroupId: ""
  property string activeGroupId: ""
  property string watchlistState: "idle"
  property string message: ""
  property bool refreshQueued: false
  property int inflight: 0
  // symbol -> { currency, lot_size }, cached for the life of the panel session
  property var staticInfo: ({})
  // Last row handed to the panel per symbol, kept for the disk cache and to
  // notice trading-session changes.
  property var quoteCache: ({})
  property bool cacheReady: false
  property bool cacheDirty: false
  // symbol -> intraday series for the row sparkline, fetched only for rows the
  // list actually shows.
  property var charts: ({})
  property var chartWanted: []
  // market -> minutes in its regular session, so a chart of a day in progress
  // knows how much of the axis it should occupy.
  property var sessionMinutes: ({})
  property int chartsInflight: 0
  readonly property int maxChartRequests: 3
  readonly property bool loading: inflight > 0
  readonly property bool live: feed ? feed.live : false

  signal groupsEvent(var groups, string defaultGroupId)
  signal groupSelected(string groupId)
  signal quoteEvent(var event)

  function activeGroup() {
    for (var i = 0; i < groups.length; i++) if (String(groups[i].id) === activeGroupId) return groups[i]
    return null
  }

  function activeSymbols() {
    var group = activeGroup()
    var securities = group && group.securities ? group.securities : []
    var result = []
    for (var i = 0; i < securities.length; i++) result.push(String(securities[i].symbol))
    return result
  }

  function refresh() {
    if (!panelOpen || !active) return
    if (loading) {
      refreshQueued = true
      return
    }
    beginLoad()
    if (session) session.retry()
    request("quote.watchlist", null, function(error, result) {
      if (error) {
        root.fail(error)
        return
      }
      var parsed = RpcAdapter.parseWatchlistGroups(result)
      if (!parsed.ok) {
        root.fail(parsed.error)
        return
      }
      var holdings = RpcAdapter.holdingsGroupIndex(parsed.groups)
      if (holdings < 0) {
        root.publishGroups(parsed)
        return
      }
      // The holdings group comes back empty from the watchlist API; its members
      // are the account's positions. A failure here leaves the group empty
      // rather than failing the whole watchlist.
      root.request("trade.stock_positions", null, function(positionsError, positionsResult) {
        if (!positionsError) {
          var held = RpcAdapter.parseStockPositions(positionsResult)
          if (held.length > 0) parsed.groups[holdings] = {
            id: parsed.groups[holdings].id,
            name: parsed.groups[holdings].name,
            securities: held
          }
        }
        root.publishGroups(parsed)
      })
    })
  }

  function publishGroups(parsed) {
    var previous = activeGroupId
    groups = parsed.groups
    defaultGroupId = parsed.defaultGroupId
    var found = false
    for (var i = 0; i < groups.length; i++) if (String(groups[i].id) === previous) found = true
    activeGroupId = found ? previous : defaultGroupId
    cacheDirty = true
    groupsEvent(groups, defaultGroupId)
    groupSelected(activeGroupId)
    fetchQuotes()
  }

  // A reopen already has groups, prices and a live subscription behind it, so
  // it refreshes in the background rather than blanking the list to a spinner.
  // Only a first load has nothing to show.
  function beginLoad() {
    if (groups.length === 0) watchlistState = "loading"
    message = ""
  }

  function selectGroup(groupId) {
    var wanted = String(groupId || "")
    if (wanted === activeGroupId) return
    for (var i = 0; i < groups.length; i++) {
      if (String(groups[i].id) === wanted) {
        activeGroupId = wanted
        groupSelected(wanted)
        cacheDirty = true
        if (loading) {
          refreshQueued = true
          return
        }
        fetchQuotes()
        return
      }
    }
  }

  function fetchQuotes() {
    var symbols = activeSymbols()
    if (symbols.length === 0) {
      watchlistState = "ready"
      message = ""
      quoteEvent({ type: "snapshot", quotes: [], errors: [] })
      subscribe([])
      finishQueuedRefresh()
      return
    }
    beginLoad()
    var missing = RpcAdapter.missingSymbols(symbols, staticInfo)
    if (missing.length === 0) {
      loadQuotes(symbols)
      return
    }
    // Currency lives only in static info; a failure here costs the currency
    // label, not the quotes, so the snapshot proceeds either way.
    collect("quote.static_info", RpcAdapter.chunkSymbols(missing), RpcAdapter.staticInfoParams, function(error, results) {
      for (var i = 0; i < results.length; i++) root.mergeStaticInfo(results[i])
      root.loadQuotes(symbols)
    })
  }

  // The snapshot exists to establish what a push cannot carry — name, currency
  // and the session's prev_close. After it lands, the feed takes over.
  function loadQuotes(symbols) {
    collect("quote.quote", RpcAdapter.chunkSymbols(symbols), RpcAdapter.quoteParams, function(error, results) {
      var quotes = []
      var failure = error
      for (var i = 0; i < results.length; i++) {
        var parsed = RpcAdapter.parseQuotes(results[i], root.staticInfo)
        if (!parsed.ok) failure = parsed.error
        else quotes = quotes.concat(parsed.event.quotes)
      }
      if (quotes.length === 0 && failure) {
        root.fail(failure)
        return
      }
      root.watchlistState = "ready"
      root.message = ""
      root.rememberQuotes(quotes)
      root.quoteEvent({ type: "snapshot", quotes: quotes, errors: [] })
      root.subscribe(symbols)
      root.finishQueuedRefresh()
    })
  }

  function subscribe(symbols) {
    if (feed) feed.setSymbols("watchlist", symbols)
  }

  // Pushes carry no prev_close, so when a symbol crosses into another trading
  // session its percentage change would be measured against the wrong close.
  // That crossing is itself an event, so it asks for one fresh snapshot rather
  // than a clock re-checking forever.
  function applyPushes(quotes) {
    var wanted = {}
    var symbols = activeSymbols()
    for (var i = 0; i < symbols.length; i++) wanted[symbols[i]] = true
    var mine = []
    var sessionChanged = false
    for (var j = 0; j < quotes.length; j++) {
      var quote = quotes[j]
      if (!wanted[quote.symbol]) continue
      var previous = quoteCache[quote.symbol]
      if (previous && quote.trade_session && previous.trade_session
        && quote.trade_session !== previous.trade_session) sessionChanged = true
      mine.push(quote)
    }
    if (mine.length === 0) return
    rememberQuotes(mine)
    quoteEvent({ type: "snapshot", quotes: mine, errors: [] })
    advanceCharts(mine)
    if (sessionChanged) sessionRefresh.restart()
  }

  // A group can hold hundreds of symbols while the list shows eight, so a row
  // asks for its own chart when it is first drawn and the queue paces the
  // requests behind the quotes that matter more.
  function requestChart(symbol) {
    var wanted = String(symbol || "")
    if (!wanted || charts[wanted]) return
    for (var i = 0; i < chartWanted.length; i++) if (chartWanted[i] === wanted) return
    chartWanted = chartWanted.concat([wanted])
    drainCharts()
  }

  // Rows painted from the cache ask for their chart before the panel has even
  // opened, so the queue waits for the session instead of being spent against
  // a server that has not started — those rows only ask once.
  function drainCharts() {
    if (!session || !session.ready) return
    while (chartsInflight < maxChartRequests && chartWanted.length > 0) {
      var symbol = chartWanted[0]
      chartWanted = chartWanted.slice(1)
      loadChart(symbol)
    }
  }

  function loadChart(symbol) {
    if (charts[symbol]) return
    chartsInflight++
    // Charts are decoration: a failure leaves the row without a line and is
    // never surfaced as a panel error.
    session.call("quote.intraday", ChartAdapter.seriesParams(symbol), function(error, result) {
      root.chartsInflight = Math.max(0, root.chartsInflight - 1)
      if (error) {
        // The session can go away mid-flight; keep the symbol so it is drawn
        // once the session is back rather than leaving that row bare forever.
        if (error.code === "disconnected") root.chartWanted = root.chartWanted.concat([symbol])
      } else {
        var series = ChartAdapter.parseSeries(symbol, result, root.sessionMinutesFor(symbol))
        if (series) root.publishChart(symbol, series)
      }
      root.drainCharts()
    })
  }

  function sessionMinutesFor(symbol) {
    return sessionMinutes[ChartAdapter.marketOf(symbol)] || 0
  }

  function loadTradingSessions() {
    if (!session || !session.ready) return
    session.call("quote.trading_session", null, function(error, result) {
      if (error) return
      root.sessionMinutes = ChartAdapter.parseSessionMinutes(result)
    })
  }

  function publishChart(symbol, series) {
    var next = {}
    for (var known in charts) next[known] = charts[known]
    next[symbol] = series
    charts = next
    quoteEvent({ type: "chart", symbol: symbol, series: series })
  }

  // The forming bar tracks the live price, so a row's line moves with its
  // number instead of freezing until the next five-minute close.
  function advanceCharts(quotes) {
    for (var i = 0; i < quotes.length; i++) {
      var series = charts[quotes[i].symbol]
      if (!series) continue
      var advanced = ChartAdapter.withLive(series, quotes[i].last)
      if (advanced !== series) publishChart(quotes[i].symbol, advanced)
    }
  }

  function rememberQuotes(quotes) {
    var next = {}
    for (var known in quoteCache) next[known] = quoteCache[known]
    for (var i = 0; i < quotes.length; i++) {
      var quote = quotes[i]
      next[quote.symbol] = RpcAdapter.mergeQuote(next[quote.symbol] || {}, quote)
    }
    quoteCache = next
    cacheDirty = true
  }

  // The cache is the fastest data there is: it needs no process, no login and
  // no network, so it paints before the session has even started. Anything it
  // shows is replaced by the live data moments later.
  function applyCache(text) {
    cacheReady = true
    if (groups.length > 0) return
    var restored = CacheAdapter.deserialize(text)
    if (!restored.ok) return
    var cache = restored.cache
    groups = cache.groups
    defaultGroupId = cache.defaultGroupId
    activeGroupId = cache.activeGroupId || cache.defaultGroupId
    staticInfo = cache.staticInfo
    rememberQuotes(cache.quotes)
    cacheDirty = false
    groupsEvent(groups, defaultGroupId)
    groupSelected(activeGroupId)
    quoteEvent({ type: "snapshot", quotes: cache.quotes, errors: [] })
    if (watchlistState === "idle") watchlistState = "ready"
  }

  // `longbridge auth login` may have switched accounts. Everything held here —
  // groups, prices, charts, and the file they are cached in — belongs to the
  // previous one, so it goes rather than lingering behind the new session.
  function resetForAccount() {
    groups = []
    defaultGroupId = ""
    activeGroupId = ""
    staticInfo = ({})
    quoteCache = ({})
    charts = ({})
    chartWanted = []
    cacheDirty = false
    watchlistState = "idle"
    message = ""
    if (cacheReady) cacheFile.setText("")
    quoteEvent({ type: "reset" })
    if (panelOpen && active) Qt.callLater(refresh)
  }

  function saveCache() {
    // Writing before the first read completes would clobber the cache with an
    // empty panel.
    if (!cacheReady || !cacheDirty || groups.length === 0) return
    cacheDirty = false
    cacheFile.setText(CacheAdapter.serialize({
      savedAt: Math.floor(Date.now() / 1000),
      groups: groups,
      defaultGroupId: defaultGroupId,
      activeGroupId: activeGroupId,
      staticInfo: staticInfo,
      quotes: quoteCache
    }))
  }

  function mergeStaticInfo(result) {
    var parsed = RpcAdapter.parseStaticInfo(result)
    var merged = {}
    for (var known in staticInfo) merged[known] = staticInfo[known]
    for (var symbol in parsed) merged[symbol] = parsed[symbol]
    staticInfo = merged
  }

  // Fans one method out over symbol chunks and reports once every chunk has
  // answered, so a group larger than a single request still yields one snapshot.
  function collect(method, chunks, paramsFor, callback) {
    if (chunks.length === 0) {
      callback(null, [])
      return
    }
    var results = []
    var remaining = chunks.length
    var failure = null
    for (var i = 0; i < chunks.length; i++) {
      request(method, paramsFor(chunks[i]), function(error, result) {
        if (error) failure = error
        else results.push(result)
        remaining--
        if (remaining === 0) callback(failure, results)
      })
    }
  }

  function request(method, params, callback) {
    if (!session) {
      if (callback) callback({ code: "disconnected", message: "Longbridge data connection closed." }, null)
      return
    }
    inflight++
    session.call(method, params, function(error, result) {
      root.inflight = Math.max(0, root.inflight - 1)
      if (callback) callback(error, result)
    })
  }

  function fail(error) {
    // Closing the panel parks the session and cancels whatever was in flight;
    // that is not a failure the next open should still be showing.
    if (error.code === "disconnected" && !panelOpen) {
      watchlistState = "idle"
      message = ""
      refreshQueued = false
      return
    }
    watchlistState = "error"
    message = error.message
    quoteEvent({ type: "error", code: error.code, message: error.message })
    finishQueuedRefresh()
  }

  function finishQueuedRefresh() {
    if (!refreshQueued) return
    refreshQueued = false
    Qt.callLater(refresh)
  }

  onPanelOpenChanged: {
    if (!panelOpen) {
      saveCache()
      return
    }
    if (active) Qt.callLater(refresh)
  }
  onActiveChanged: if (panelOpen && active) Qt.callLater(refresh)

  Connections {
    target: root.feed
    function onQuotesUpdated(quotes) { root.applyPushes(quotes) }
  }

  Connections {
    target: root.session
    // A reconnected session dropped its subscriptions and may have missed
    // watchlist edits, so it reloads once — on the event, not on a schedule.
    function onConnected() {
      root.quoteEvent({ type: "connection", state: "connected" })
      root.loadTradingSessions()
      root.drainCharts()
      if (root.panelOpen && root.active && root.inflight === 0) Qt.callLater(root.refresh)
    }
    function onAuthChanged() { root.resetForAccount() }
    function onFailed(code, text) {
      root.watchlistState = "error"
      root.message = text
      root.quoteEvent({ type: "error", code: code, message: text })
    }
  }

  Timer {
    id: sessionRefresh
    interval: 2000
    repeat: false
    onTriggered: {
      if (!root.panelOpen || !root.active) return
      // New session, new bars: drop the intraday series so visible rows refetch.
      root.charts = ({})
      root.fetchQuotes()
    }
  }

  FileView {
    id: cacheFile
    path: Quickshell.cachePath("longbridge/watchlist.json")
    preload: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyCache(cacheFile.text())
    onLoadFailed: root.cacheReady = true
  }

  // Not an update loop: the cache is written from what the feed already
  // delivered, so a shell restart has recent rows to paint.
  Timer {
    interval: 60000
    repeat: true
    running: root.panelOpen
    onTriggered: root.saveCache()
  }
}
