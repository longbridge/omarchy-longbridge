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
assert.strictEqual(context.quoteCommand, undefined)
assert.strictEqual(context.parseQuotes, undefined)
assert.strictEqual(context.classifyFailure("Please run longbridge auth login", 1).code, "not_authenticated")
assert.strictEqual(context.classifyFailure("request failed with access_token=secret", 1).message, "Longbridge could not load data.")

console.log("CLI adapter tests passed")
