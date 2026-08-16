//! OAuth state and login utilities extracted from Longbridge Terminal.

use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::secure_storage;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AuthState {
    Authenticated,
    NotAuthenticated,
    TokenUnreadable,
}

#[derive(Deserialize)]
struct ClientRegistration {
    client_id: String,
}

pub fn status() -> AuthState {
    let Ok(registration) = registration_file_path() else {
        return AuthState::NotAuthenticated;
    };
    let Ok(token) = secure_storage::token_file_path() else {
        return AuthState::NotAuthenticated;
    };
    status_from_paths(&registration, &token, secure_storage::machine_id())
}

pub fn effective_client_id() -> String {
    let Ok(path) = registration_file_path() else {
        return String::new();
    };
    let Ok(bytes) = std::fs::read(path) else {
        return String::new();
    };
    serde_json::from_slice::<ClientRegistration>(&bytes)
        .map(|registration| registration.client_id)
        .unwrap_or_default()
}

fn status_from_paths(registration_path: &Path, token_path: &Path, machine_id: &str) -> AuthState {
    let Ok(registration_json) = std::fs::read(registration_path) else {
        return AuthState::NotAuthenticated;
    };
    let Ok(registration) = serde_json::from_slice::<ClientRegistration>(&registration_json) else {
        return AuthState::NotAuthenticated;
    };
    if !token_path.exists() {
        return AuthState::NotAuthenticated;
    }
    match secure_storage::client_id_from_path(token_path, machine_id) {
        Ok(client_id) if client_id == registration.client_id => AuthState::Authenticated,
        Ok(_) | Err(_) => AuthState::TokenUnreadable,
    }
}

pub fn registration_file_path() -> anyhow::Result<PathBuf> {
    Ok(dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Failed to get home directory"))?
        .join(".longbridge")
        .join("openapi")
        .join("cli-registration"))
}

#[cfg(test)]
mod tests {
    use std::fs;

    use super::{status_from_paths, AuthState};
    use crate::secure_storage::write_test_token;

    #[test]
    fn missing_shared_files_are_not_authenticated() {
        let directory = tempfile::tempdir().unwrap();
        let state = status_from_paths(
            &directory.path().join("cli-registration"),
            &directory.path().join("cli-auth"),
            "machine-fixture",
        );

        assert_eq!(state, AuthState::NotAuthenticated);
    }

    #[test]
    fn valid_cli_registration_and_token_are_authenticated() {
        let directory = tempfile::tempdir().unwrap();
        let registration = directory.path().join("cli-registration");
        let token = directory.path().join("cli-auth");
        fs::write(&registration, br#"{"client_id":"client_fixture"}"#).unwrap();
        write_test_token(
            &token,
            "machine-fixture",
            "client_fixture",
            "access_fixture",
            "refresh_fixture",
        )
        .unwrap();

        assert_eq!(
            status_from_paths(&registration, &token, "machine-fixture"),
            AuthState::Authenticated
        );
    }

    #[test]
    fn corrupt_cli_token_is_reported_without_secret_material() {
        let directory = tempfile::tempdir().unwrap();
        let registration = directory.path().join("cli-registration");
        let token = directory.path().join("cli-auth");
        fs::write(&registration, br#"{"client_id":"client_fixture"}"#).unwrap();
        fs::write(&token, b"LB\x01corrupt access_fixture refresh_fixture").unwrap();

        let state = status_from_paths(&registration, &token, "machine-fixture");
        assert_eq!(state, AuthState::TokenUnreadable);
        let json = serde_json::to_string(&state).unwrap();
        assert!(!json.contains("access_fixture"));
        assert!(!json.contains("refresh_fixture"));
    }
}
