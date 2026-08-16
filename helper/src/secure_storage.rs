//! Encrypted file token storage for Longbridge OAuth tokens.
//!
//! Extracted from `longbridge-terminal/src/secure_storage.rs` under Apache-2.0.
//! Keep the on-disk format compatible with Longbridge Terminal.

use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};

use aes_gcm::{
    aead::{Aead, AeadCore, KeyInit, OsRng},
    Aes256Gcm, Key, Nonce,
};
use hkdf::Hkdf;
use longbridge::oauth::{OAuthError, OAuthResult, StoredToken, TokenStorage};
use serde::{Deserialize, Serialize};

const MAGIC: &[u8; 3] = b"LB\x01";
const HKDF_INFO: &[u8] = b"longbridge-token-v1";

static MACHINE_ID: OnceLock<String> = OnceLock::new();

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
struct EncryptedPayload {
    client_id: String,
    access_token: String,
    refresh_token: Option<String>,
    expires_at: u64,
    #[serde(default)]
    logged_in_at: Option<u64>,
}

impl From<EncryptedPayload> for StoredToken {
    fn from(payload: EncryptedPayload) -> Self {
        Self {
            client_id: payload.client_id,
            access_token: payload.access_token,
            refresh_token: payload.refresh_token,
            expires_at: payload.expires_at,
        }
    }
}

pub struct EncryptedFileTokenStorage;

fn load_payload_with_migration(_client_id: &str) -> Option<EncryptedPayload> {
    let path = token_file_path().ok()?;
    let (payload, needs_migration) = read_payload(&path)?;
    if needs_migration {
        let _ = EncryptedFileTokenStorage.save(&StoredToken::from(payload.clone()));
    }
    Some(payload)
}

impl EncryptedFileTokenStorage {
    pub fn load_full(client_id: &str) -> Option<serde_json::Value> {
        serde_json::to_value(load_payload_with_migration(client_id)?).ok()
    }
}

impl TokenStorage for EncryptedFileTokenStorage {
    fn load(&self, client_id: &str) -> Option<StoredToken> {
        Some(load_payload_with_migration(client_id)?.into())
    }

    fn save(&self, token: &StoredToken) -> OAuthResult<()> {
        let path = token_file_path().map_err(|error| OAuthError::Other(error.to_string()))?;
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        let logged_in_at = read_payload(&path)
            .and_then(|(payload, _)| payload.logged_in_at)
            .unwrap_or(now);
        let payload = EncryptedPayload {
            client_id: token.client_id.clone(),
            access_token: token.access_token.clone(),
            refresh_token: token.refresh_token.clone(),
            expires_at: token.expires_at,
            logged_in_at: Some(logged_in_at),
        };
        write_payload_to(&path, &payload, machine_id())
            .map_err(|error| OAuthError::Other(format!("Token encryption failed: {error}")))
    }
}

pub fn try_delete(_client_id: &str) {
    if let Ok(path) = token_file_path() {
        if path.exists() {
            let _ = std::fs::remove_file(path);
        }
    }
}

pub fn harden_file_permissions(path: &Path) {
    #[cfg(target_family = "unix")]
    {
        use std::os::unix::fs::PermissionsExt as _;
        if let Ok(metadata) = std::fs::metadata(path) {
            let mut permissions = metadata.permissions();
            if permissions.mode() & 0o077 != 0 {
                permissions.set_mode(0o600);
                if let Err(error) = std::fs::set_permissions(path, permissions) {
                    tracing::debug!("Could not harden file permissions: {error}");
                }
            }
        }
    }
}

pub fn token_file_path() -> anyhow::Result<PathBuf> {
    Ok(dirs::home_dir()
        .ok_or_else(|| anyhow::anyhow!("Failed to get home directory"))?
        .join(".longbridge")
        .join("openapi")
        .join("cli-auth"))
}

fn read_payload(path: &Path) -> Option<(EncryptedPayload, bool)> {
    read_payload_from(path, machine_id())
}

fn read_payload_from(path: &Path, machine_id: &str) -> Option<(EncryptedPayload, bool)> {
    let bytes = std::fs::read(path).ok()?;
    if bytes.starts_with(MAGIC) {
        let plaintext = decrypt_with_machine_id(&bytes, machine_id).ok()?;
        let payload = serde_json::from_slice(&plaintext).ok()?;
        Some((payload, false))
    } else {
        let json: serde_json::Value = serde_json::from_slice(&bytes).ok()?;
        let payload = EncryptedPayload {
            client_id: json["client_id"].as_str()?.to_owned(),
            access_token: json["access_token"].as_str()?.to_owned(),
            refresh_token: json["refresh_token"].as_str().map(str::to_owned),
            expires_at: json["expires_at"].as_u64().unwrap_or(0),
            logged_in_at: json["logged_in_at"].as_u64(),
        };
        Some((payload, true))
    }
}

pub(crate) fn client_id_from_path(path: &Path, machine_id: &str) -> Result<String, String> {
    read_payload_from(path, machine_id)
        .map(|(payload, _)| payload.client_id)
        .ok_or_else(|| "token could not be decrypted or parsed".to_string())
}

#[cfg(test)]
pub(crate) fn write_test_token(
    path: &Path,
    machine_id: &str,
    client_id: &str,
    access_token: &str,
    refresh_token: &str,
) -> Result<(), String> {
    write_payload_to(
        path,
        &EncryptedPayload {
            client_id: client_id.to_string(),
            access_token: access_token.to_string(),
            refresh_token: Some(refresh_token.to_string()),
            expires_at: 1_900_000_000,
            logged_in_at: Some(1_700_000_000),
        },
        machine_id,
    )
}

fn write_payload_to(
    path: &Path,
    payload: &EncryptedPayload,
    machine_id: &str,
) -> Result<(), String> {
    let json = serde_json::to_vec(payload).map_err(|error| error.to_string())?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let encrypted = encrypt_with_machine_id(&json, machine_id)?;
    let temporary = path.with_extension("tmp");
    std::fs::write(&temporary, encrypted).map_err(|error| error.to_string())?;
    std::fs::rename(&temporary, path).map_err(|error| error.to_string())?;
    harden_file_permissions(path);
    Ok(())
}

fn encrypt_with_machine_id(plaintext: &[u8], machine_id: &str) -> Result<Vec<u8>, String> {
    let key = machine_derived_key(machine_id);
    let cipher = Aes256Gcm::new(&key);
    let nonce = Aes256Gcm::generate_nonce(&mut OsRng);
    let ciphertext = cipher
        .encrypt(&nonce, plaintext)
        .map_err(|error| format!("AES-GCM encrypt: {error}"))?;
    let mut output = Vec::with_capacity(MAGIC.len() + nonce.len() + ciphertext.len());
    output.extend_from_slice(MAGIC);
    output.extend_from_slice(&nonce);
    output.extend_from_slice(&ciphertext);
    Ok(output)
}

fn decrypt_with_machine_id(data: &[u8], machine_id: &str) -> Result<Vec<u8>, String> {
    if data.len() < MAGIC.len() + 12 {
        return Err("data too short".to_string());
    }
    let nonce = Nonce::from_slice(&data[MAGIC.len()..MAGIC.len() + 12]);
    let key = machine_derived_key(machine_id);
    let cipher = Aes256Gcm::new(&key);
    cipher
        .decrypt(nonce, &data[MAGIC.len() + 12..])
        .map_err(|error| format!("AES-GCM decrypt: {error}"))
}

fn machine_derived_key(machine_id: &str) -> Key<Aes256Gcm> {
    let hkdf = Hkdf::<sha2::Sha256>::new(None, machine_id.as_bytes());
    let mut key_bytes = [0_u8; 32];
    let _ = hkdf.expand(HKDF_INFO, &mut key_bytes);
    *Key::<Aes256Gcm>::from_slice(&key_bytes)
}

pub(crate) fn machine_id() -> &'static str {
    MACHINE_ID
        .get_or_init(|| match machine_uid::get() {
            Ok(id) => id,
            Err(error) => {
                tracing::warn!(
                    "Could not obtain machine ID (token will not be machine-bound): {error}"
                );
                String::new()
            }
        })
        .as_str()
}

#[cfg(test)]
mod tests {
    use std::fs;

    use super::{
        decrypt_with_machine_id, encrypt_with_machine_id, read_payload_from, write_payload_to,
        EncryptedPayload, MAGIC,
    };

    fn payload() -> EncryptedPayload {
        EncryptedPayload {
            client_id: "client_fixture".to_string(),
            access_token: "access_fixture".to_string(),
            refresh_token: Some("refresh_fixture".to_string()),
            expires_at: 1_900_000_000,
            logged_in_at: Some(1_700_000_000),
        }
    }

    #[test]
    fn cli_envelope_round_trips_for_same_machine() {
        let json = serde_json::to_vec(&payload()).unwrap();
        let encrypted = encrypt_with_machine_id(&json, "machine-fixture").unwrap();

        assert!(encrypted.starts_with(MAGIC));
        let decrypted = decrypt_with_machine_id(&encrypted, "machine-fixture").unwrap();
        let actual: EncryptedPayload = serde_json::from_slice(&decrypted).unwrap();
        assert_eq!(actual, payload());
    }

    #[test]
    fn cli_envelope_rejects_other_machine_and_tampering() {
        let mut encrypted =
            encrypt_with_machine_id(b"fixture plaintext", "machine-fixture").unwrap();
        assert!(decrypt_with_machine_id(&encrypted, "different-machine").is_err());

        let last = encrypted.len() - 1;
        encrypted[last] ^= 0xff;
        assert!(decrypt_with_machine_id(&encrypted, "machine-fixture").is_err());
    }

    #[test]
    fn legacy_json_is_migrated_to_encrypted_cli_envelope() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("cli-auth");
        fs::write(
            &path,
            br#"{"client_id":"client_fixture","access_token":"access_fixture","refresh_token":"refresh_fixture","expires_at":1900000000,"logged_in_at":1700000000}"#,
        )
        .unwrap();

        let (actual, needs_migration) = read_payload_from(&path, "machine-fixture").unwrap();
        assert_eq!(actual, payload());
        assert!(needs_migration);

        write_payload_to(&path, &actual, "machine-fixture").unwrap();
        assert!(fs::read(&path).unwrap().starts_with(MAGIC));
    }

    #[cfg(unix)]
    #[test]
    fn token_write_uses_owner_only_permissions() {
        use std::os::unix::fs::PermissionsExt as _;

        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("cli-auth");
        write_payload_to(&path, &payload(), "machine-fixture").unwrap();

        assert_eq!(
            fs::metadata(path).unwrap().permissions().mode() & 0o777,
            0o600
        );
    }
}
