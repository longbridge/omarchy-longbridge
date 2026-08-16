.pragma library

function availabilityCommand() {
  return ["sh", "-lc", "command -v longbridge"]
}

function installCommand() {
  return ["sh", "-lc", "curl -sSL https://github.com/longbridge/longbridge-terminal/raw/main/install | sh"]
}

function loginCommand() {
  return ["longbridge", "auth", "login"]
}

function checkCommand() {
  return ["longbridge", "check", "--format", "json"]
}

function parseCheck(text) {
  var payload
  try { payload = JSON.parse(String(text || "")) }
  catch (error) { return { ok: false, authenticated: false, message: "Could not verify Longbridge login." } }
  if (!payload || typeof payload !== "object" || !payload.session || typeof payload.session !== "object")
    return { ok: false, authenticated: false, message: "Could not verify Longbridge login." }
  var authenticated = String(payload.session.token || "").toLowerCase() === "valid"
  return {
    ok: true,
    authenticated: authenticated,
    message: authenticated ? "Longbridge is ready." : "Log in to continue."
  }
}
