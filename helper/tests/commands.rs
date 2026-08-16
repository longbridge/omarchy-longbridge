use std::process::Command;

#[test]
fn auth_status_emits_safe_not_authenticated_event() {
    let home = tempfile::tempdir().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_longbridge-helper"))
        .args(["auth", "status"])
        .env("HOME", home.path())
        .output()
        .unwrap();

    assert!(output.status.success());
    assert!(output.stderr.is_empty());
    let event: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(
        event,
        serde_json::json!({
            "type": "auth",
            "state": "not_authenticated",
            "message": "Connect your Longbridge account."
        })
    );
}

#[test]
fn invalid_stream_symbol_emits_safe_error_without_connecting() {
    let home = tempfile::tempdir().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_longbridge-helper"))
        .args(["stream", "AAPL"])
        .env("HOME", home.path())
        .output()
        .unwrap();

    assert!(!output.status.success());
    assert!(output.stderr.is_empty());
    let event: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(event["type"], "error");
    assert_eq!(event["code"], "invalid_symbol");
    assert_eq!(event["message"], "Use symbols such as AAPL.US or 700.HK.");
}
