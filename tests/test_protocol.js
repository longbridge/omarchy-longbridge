const test = require("node:test")
const assert = require("node:assert/strict")

const Protocol = require("../Protocol.js")

test("split NDJSON line is retained until complete", () => {
  const first = Protocol.consume("", '{"type":"connection","state":"con')
  assert.deepEqual(first.events, [])
  assert.equal(first.remainder, '{"type":"connection","state":"con')

  const second = Protocol.consume(first.remainder, 'necting"}\n')
  assert.deepEqual(second.events, [{ type: "connection", state: "connecting" }])
  assert.equal(second.remainder, "")
  assert.deepEqual(second.errors, [])
})

test("multiple complete events are emitted in order", () => {
  const result = Protocol.consume(
    "",
    '{"type":"connection","state":"connecting"}\n' +
      '{"type":"subscription","symbols":["AAPL.US"]}\n'
  )
  assert.deepEqual(result.events.map(event => event.type), ["connection", "subscription"])
  assert.equal(result.remainder, "")
})

test("malformed and unknown lines are isolated without losing later events", () => {
  const result = Protocol.consume(
    "",
    'not-json\n{"type":"secret","access_token":"do-not-accept"}\n' +
      '{"type":"connection","state":"live"}\n'
  )
  assert.deepEqual(result.events, [{ type: "connection", state: "live" }])
  assert.deepEqual(result.errors, ["malformed_json", "unknown_event"])
})

