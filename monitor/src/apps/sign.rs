//! A desk app package's signature: `SIGNATURE` in the package,
//! `{ "key": "<id>", "signature": "<base64>" }`, an ed25519 signature over
//! the SHA-256 of the package's listing: one line per other file,
//! `<sha256 hex>  <path>\n`, sorted by path (as `sha256sum` writes it), so
//! every byte of the package is covered.
//!
//! A package signed with a first-party key may use the panel's own
//! publisher (`serverbox.*`); one signed with an unknown key, or not signed,
//! installs as from an unknown publisher. A signature that does not verify
//! refuses the package.

use std::collections::BTreeMap;

use base64::Engine as _;
use serde::Deserialize;
use sha2::{Digest, Sha256};

pub const SIGNATURE_FILE: &str = "SIGNATURE";

/// The keys ServerBox signs its own desk apps with (raw ed25519 public
/// keys); the private one is in the maintainer's keychain
/// (`scripts/build-desk-app.sh`).
pub const FIRST_PARTY_KEYS: &[(&str, &str)] = &[("serverbox-2026", "puv8ZLaLDtAiu0pjfc7RWRDqlQ+rJSDTkVUyY8Ih9e0=")];

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Signature {
    key: String,
    signature: String,
}

/// The listing a signature covers: every file but the signature.
pub fn listing(files: &BTreeMap<String, Vec<u8>>) -> String {
    files
        .iter()
        .filter(|(p, _)| p.as_str() != SIGNATURE_FILE)
        .map(|(path, bytes)| format!("{}  {path}\n", hex::encode(Sha256::digest(bytes))))
        .collect()
}

/// Who signed [files]: a first-party key's id, or none (unsigned, or a key
/// this agent does not know). `Err` when a first-party signature is there
/// and does not verify, or `SIGNATURE` is malformed.
pub fn signer(files: &BTreeMap<String, Vec<u8>>) -> Result<Option<&'static str>, &'static str> {
    let Some(raw) = files.get(SIGNATURE_FILE) else { return Ok(None) };
    let sig: Signature = serde_json::from_slice(raw).map_err(|_| "badSignature")?;
    let Some((id, key)) = FIRST_PARTY_KEYS.iter().find(|(id, _)| *id == sig.key) else { return Ok(None) };
    let engine = base64::engine::general_purpose::STANDARD;
    let key = engine.decode(key).map_err(|_| "badSignature")?;
    let signature = engine.decode(sig.signature.trim()).map_err(|_| "badSignature")?;
    let digest = Sha256::digest(listing(files).as_bytes());
    ring::signature::UnparsedPublicKey::new(&ring::signature::ED25519, key).verify(&digest, &signature).map_err(|_| "badSignature")?;
    Ok(Some(id))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_listing_covers_every_file_but_the_signature() {
        let mut files = BTreeMap::new();
        files.insert("ui/index.html".to_string(), b"x".to_vec());
        files.insert("manifest.json".to_string(), b"{}".to_vec());
        files.insert(SIGNATURE_FILE.to_string(), b"{}".to_vec());
        assert_eq!(
            listing(&files),
            "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a  manifest.json\n\
             2d711642b726b04401627ca9fbac32f5c8530fb1903cc4db02258717921a4881  ui/index.html\n"
        );
    }

    #[test]
    fn a_signature_is_checked_against_the_files() {
        let mut files = BTreeMap::new();
        files.insert("manifest.json".to_string(), b"{}".to_vec());
        assert_eq!(signer(&files), Ok(None));
        // A key this agent does not know: an unknown publisher.
        files.insert(SIGNATURE_FILE.to_string(), br#"{"key":"someone","signature":"AAAA"}"#.to_vec());
        assert_eq!(signer(&files), Ok(None));
        // Signed by `scripts/build-desk-app.sh`'s way (openssl, the
        // first-party key) over these two files.
        files.insert("ui/index.html".to_string(), b"x".to_vec());
        files.insert(
            SIGNATURE_FILE.to_string(),
            br#"{"key": "serverbox-2026", "signature": "R0CDyj0If2e/xpeSuIpsuVp+UI5mvZ2oGY2vMYKr+EUkl0Qiwb8fiOPJebBoz5fSkdapQioUT6kYFLCIAahCDg=="}"#.to_vec(),
        );
        assert_eq!(signer(&files), Ok(Some("serverbox-2026")));
        // One byte changed.
        files.insert("ui/index.html".to_string(), b"y".to_vec());
        assert_eq!(signer(&files), Err("badSignature"));
        files.remove("ui/index.html");
        // The first-party key's id with a signature that is not its own.
        files.insert(SIGNATURE_FILE.to_string(), format!(r#"{{"key":"serverbox-2026","signature":"{}"}}"#, "A".repeat(86) + "==").into_bytes());
        assert_eq!(signer(&files), Err("badSignature"));
        files.insert(SIGNATURE_FILE.to_string(), b"not json".to_vec());
        assert_eq!(signer(&files), Err("badSignature"));
    }
}
