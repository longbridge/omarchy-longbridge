const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const source = fs.readFileSync("SetupAdapter.js", "utf8").replace(/^\.pragma library\s*$/m, "")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)

assert.deepStrictEqual(Array.from(context.availabilityCommand()), ["sh", "-lc", "command -v longbridge"])
assert.strictEqual(context.installDocsUrl(), "https://open.longbridge.com/docs/cli/install")
assert.strictEqual(context.installCommand, undefined)
assert.deepStrictEqual(Array.from(context.loginCommand()), ["longbridge", "auth", "login"])
assert.deepStrictEqual(Array.from(context.checkCommand()), ["longbridge", "check", "--format", "json"])

assert.deepStrictEqual(
  JSON.parse(JSON.stringify(context.parseCheck('{"session":{"token":"valid"}}'))),
  { ok: true, authenticated: true, message: "Longbridge is ready." }
)
assert.deepStrictEqual(
  JSON.parse(JSON.stringify(context.parseCheck('{"session":{"token":"missing"}}'))),
  { ok: true, authenticated: false, message: "Log in to continue." }
)
assert.strictEqual(context.parseCheck("not-json").ok, false)

console.log("setup adapter tests passed")
