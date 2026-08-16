const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const source = fs.readFileSync("CliAdapter.js", "utf8").replace(/^\.pragma library\s*$/m, "")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)

const portfolioText = fs.readFileSync("tests/fixtures/portfolio.json", "utf8")
const portfolioResult = context.parsePortfolio(portfolioText)
assert.strictEqual(portfolioResult.ok, true)
assert.strictEqual(portfolioResult.event.type, "portfolio")
assert.strictEqual(portfolioResult.event.net_assets, "257638.30")
assert.strictEqual(portfolioResult.event.market_value, "212518.05")
assert.strictEqual(portfolioResult.event.total_gain, "37600.00")
assert.strictEqual(portfolioResult.event.positions[0].day_gain, "21.80")

assert.strictEqual(context.parsePortfolio("[]").ok, false)
assert.deepStrictEqual(Array.from(context.portfolioCommand()), [
  "longbridge", "portfolio", "--format", "json"
])
assert.deepStrictEqual(Array.from(context.watchlistCommand()), [
  "longbridge", "watchlist", "--format", "json"
])
assert.deepStrictEqual(Array.from(context.quoteCommand(["SPY.US", ".SPX.US"])), [
  "longbridge", "quote", "SPY.US", ".SPX.US", "--format", "json"
])

const watchlistText = fs.readFileSync("tests/fixtures/watchlist.json", "utf8")
const watchlistResult = context.parseWatchlist(watchlistText)
assert.strictEqual(watchlistResult.ok, true)
assert.strictEqual(watchlistResult.defaultGroupId, "2630")
assert.deepStrictEqual(Array.from(watchlistResult.groups, group => group.name), ["all", "holdings", "us"])
assert.strictEqual(watchlistResult.groups[0].securities[0].is_pinned, true)
assert.strictEqual(watchlistResult.groups[0].securities[1].symbol, ".SPX.US")
assert.strictEqual(watchlistResult.groups[1].id, "-6")
assert.strictEqual(watchlistResult.groups[1].securities.length, 0)

const quoteText = fs.readFileSync("tests/fixtures/quote.json", "utf8")
const quoteResult = context.parseQuotes(quoteText)
assert.strictEqual(quoteResult.ok, true)
assert.strictEqual(quoteResult.event.type, "snapshot")
assert.strictEqual(quoteResult.event.quotes[0].symbol, "AAPL.US")
assert.strictEqual(quoteResult.event.quotes[0].last, "233.01")
assert.strictEqual(quoteResult.event.quotes[0].trade_session, "Post")

assert.strictEqual(context.parseWatchlist("[]").ok, false)
assert.strictEqual(context.parseWatchlist('[{"id":1,"name":"all","securities":[]},{"id":2,"name":"ALL","securities":[]} ]').ok, false)
assert.strictEqual(context.classifyFailure("Please run longbridge auth login", 1).code, "not_authenticated")
assert.strictEqual(context.classifyFailure("request failed with access_token=secret", 1).message, "Longbridge could not load data.")

console.log("CLI adapter tests passed")
