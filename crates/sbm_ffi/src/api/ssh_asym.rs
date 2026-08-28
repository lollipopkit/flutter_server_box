//! SSH asymmetric crypto over FFI: key exchange, signatures, and the key
//! encryption KDF.
//!
//! **Why.** The record cipher next door runs on every packet; these run once
//! per connection. What makes them worth moving anyway is that each is a single
//! synchronous call on the isolate drawing frames, and a call is either inside
//! one frame's budget or it is not — `verify` for an ECDSA host key is 3.7 ms
//! in Dart, and a 120 Hz frame is 8.3. Totals over a launch were the wrong way
//! to look at it.
//!
//! Key exchange is a second reason. dartssh2 keeps x25519 off the UI isolate by
//! running it in `Isolate.run`, twice per handshake — so ten servers connecting
//! at launch spawn twenty isolates to hide 0.3 ms of work each. At native
//! speed there is nothing left to hide and the isolates can go.
//!
//! **What is deliberately not here: RSA.** Not for lack of a crate, but because
//! the pure-Rust `rsa` crate has no stable release and carries RUSTSEC-2023-0071
//! — a timing sidechannel in exactly the private-key operation signing would
//! use, unpatched — while the party able to time our signature is the server we
//! are authenticating to. pointycastle's RSA is not constant-time either, so
//! this is not a claim that Dart is safer; it is that swapping one
//! non-constant-time implementation for another that is also unreleased and
//! has a filed advisory buys nothing. A constant-time RSA means a BoringSSL
//! -backed crate and a C toolchain on five targets, which is a separate
//! decision from making the app draw frames on time. The seam makes it a
//! change to this file when it is taken.
//!
//! **Shapes come from the wire, not from the crates.** SSH names curves
//! `nistp256`, hands Ed25519 private keys over as a 64-byte seed-and-public
//! blob, and carries ECDSA signatures as a separate `r` and `s`. Converting at
//! this boundary keeps the Dart side from having to know what any crate wanted.

use ed25519_dalek::{Signer as _, Verifier as _};

/// One end of a key exchange: the scalar to keep and the point to send.
pub struct X25519KeyPair {
    pub private_key: Vec<u8>,
    pub public_key: Vec<u8>,
}

/// An ECDSA signature as SSH carries it — two fixed-width big-endian integers.
///
/// Fixed width, not minimal: `r` and `s` are the curve's field size, which is
/// what the crates produce and what the Dart side re-encodes as mpints. A
/// minimal encoding here would make that re-encoding guess where the number
/// started.
pub struct EcdsaSignature {
    pub r: Vec<u8>,
    pub s: Vec<u8>,
}

/// A fresh x25519 keypair.
///
/// The scalar comes from the operating system, not from a seed this is given:
/// a key exchange private key that a caller could choose is a key exchange an
/// attacker could replay.
#[flutter_rust_bridge::frb(sync)]
pub fn x25519_keypair() -> X25519KeyPair {
    let secret = x25519_dalek::StaticSecret::random();
    let public = x25519_dalek::PublicKey::from(&secret);
    X25519KeyPair {
        private_key: secret.to_bytes().to_vec(),
        public_key: public.as_bytes().to_vec(),
    }
}

/// The shared secret for `private_key` against the peer's `peer_public_key`.
///
/// An all-zero result means the peer sent a low-order point, which is a peer
/// trying to force a known secret rather than a peer with a bad key. Refused
/// here so that no caller has to remember to check.
#[flutter_rust_bridge::frb(sync)]
pub fn x25519_shared_secret(
    private_key: Vec<u8>,
    peer_public_key: Vec<u8>,
) -> Result<Vec<u8>, String> {
    let secret = x25519_dalek::StaticSecret::from(to_array32(&private_key, "x25519 private key")?);
    let peer = x25519_dalek::PublicKey::from(to_array32(&peer_public_key, "x25519 public key")?);
    let shared = secret.diffie_hellman(&peer);
    if !shared.was_contributory() {
        return Err("x25519 peer sent a low-order point".into());
    }
    Ok(shared.as_bytes().to_vec())
}

/// Signs `message` with an SSH Ed25519 private key.
///
/// `private_key` is the 64-byte blob OpenSSH stores: a 32-byte seed followed by
/// the public key it expands to. Only the seed is a secret and only the seed is
/// used; the rest is re-derived, which also means a blob whose halves disagree
/// signs correctly rather than silently producing a signature nothing accepts.
#[flutter_rust_bridge::frb(sync)]
pub fn ed25519_sign(private_key: Vec<u8>, message: Vec<u8>) -> Result<Vec<u8>, String> {
    if private_key.len() != 64 && private_key.len() != 32 {
        return Err(format!(
            "ed25519 private key is 32 or 64 bytes, got {}",
            private_key.len()
        ));
    }
    let seed = to_array32(&private_key[..32], "ed25519 seed")?;
    let key = ed25519_dalek::SigningKey::from_bytes(&seed);
    Ok(key.sign(&message).to_bytes().to_vec())
}

/// Whether `signature` is [`message`] signed by `public_key`.
///
/// `false` for a malformed key or signature as much as for a wrong one: a
/// caller asking whether to trust a host has one question, and answering
/// "the signature was the wrong length" through a different channel is how a
/// malformed signature ends up treated as a passing one.
#[flutter_rust_bridge::frb(sync)]
pub fn ed25519_verify(public_key: Vec<u8>, message: Vec<u8>, signature: Vec<u8>) -> bool {
    let Ok(key_bytes) = to_array32(&public_key, "") else {
        return false;
    };
    let Ok(key) = ed25519_dalek::VerifyingKey::from_bytes(&key_bytes) else {
        return false;
    };
    let Ok(sig_bytes) = <[u8; 64]>::try_from(signature.as_slice()) else {
        return false;
    };
    key.verify(&message, &ed25519_dalek::Signature::from_bytes(&sig_bytes))
        .is_ok()
}

/// Signs `message` with an SSH ECDSA private key on `curve`.
///
/// `curve` is the SSH name — `nistp256`, `nistp384`, `nistp521` — and picks the
/// hash with it, as RFC 5656 ties the two together. `private_key` is the
/// scalar, big-endian, at the curve's field width.
///
/// The signature is deterministic (RFC 6979) where dartssh2's is randomized.
/// Both are ECDSA and either verifies against the same public key, but it does
/// mean the two implementations produce different bytes for one input — a test
/// comparing them has to cross-verify rather than compare.
#[flutter_rust_bridge::frb(sync)]
pub fn ecdsa_sign(
    curve: String,
    private_key: Vec<u8>,
    message: Vec<u8>,
) -> Result<EcdsaSignature, String> {
    match curve.as_str() {
        "nistp256" => {
            use p256::ecdsa::signature::Signer;
            let key = p256::ecdsa::SigningKey::from_slice(&private_key)
                .map_err(|e| format!("nistp256 private key: {e}"))?;
            let sig: p256::ecdsa::Signature = key.sign(&message);
            Ok(split_rs(sig.to_bytes().as_slice()))
        }
        "nistp384" => {
            use p384::ecdsa::signature::Signer;
            let key = p384::ecdsa::SigningKey::from_slice(&private_key)
                .map_err(|e| format!("nistp384 private key: {e}"))?;
            let sig: p384::ecdsa::Signature = key.sign(&message);
            Ok(split_rs(sig.to_bytes().as_slice()))
        }
        "nistp521" => {
            use p521::ecdsa::signature::Signer;
            let key = p521::ecdsa::SigningKey::from_slice(&private_key)
                .map_err(|e| format!("nistp521 private key: {e}"))?;
            let sig: p521::ecdsa::Signature = key.sign(&message);
            Ok(split_rs(sig.to_bytes().as_slice()))
        }
        other => Err(format!("unsupported curve: {other}")),
    }
}

/// Whether `r`/`s` is `message` signed by `public_key` on `curve`.
///
/// `public_key` is the uncompressed SEC1 point SSH puts on the wire, `0x04`
/// prefix included. `false` for anything malformed, for the reason
/// [`ed25519_verify`] gives.
#[flutter_rust_bridge::frb(sync)]
pub fn ecdsa_verify(
    curve: String,
    public_key: Vec<u8>,
    message: Vec<u8>,
    r: Vec<u8>,
    s: Vec<u8>,
) -> bool {
    match curve.as_str() {
        "nistp256" => {
            use p256::ecdsa::signature::Verifier;
            let (Ok(key), Some(sig)) = (
                p256::ecdsa::VerifyingKey::from_sec1_bytes(&public_key),
                join_rs::<32>(&r, &s).and_then(|b| p256::ecdsa::Signature::from_slice(&b).ok()),
            ) else {
                return false;
            };
            key.verify(&message, &sig).is_ok()
        }
        "nistp384" => {
            use p384::ecdsa::signature::Verifier;
            let (Ok(key), Some(sig)) = (
                p384::ecdsa::VerifyingKey::from_sec1_bytes(&public_key),
                join_rs::<48>(&r, &s).and_then(|b| p384::ecdsa::Signature::from_slice(&b).ok()),
            ) else {
                return false;
            };
            key.verify(&message, &sig).is_ok()
        }
        "nistp521" => {
            use p521::ecdsa::signature::Verifier;
            let (Ok(key), Some(sig)) = (
                p521::ecdsa::VerifyingKey::from_sec1_bytes(&public_key),
                join_rs::<66>(&r, &s).and_then(|b| p521::ecdsa::Signature::from_slice(&b).ok()),
            ) else {
                return false;
            };
            key.verify(&message, &sig).is_ok()
        }
        _ => false,
    }
}

/// The `bcrypt_pbkdf` OpenSSH keys an encrypted private key with.
///
/// Deliberately slow, and staying so: `rounds` comes out of the key file and is
/// not this function's to choose. What changes is only how fast *this* app
/// walks the same rounds — an attacker was never running the Dart one.
#[flutter_rust_bridge::frb(sync)]
pub fn bcrypt_pbkdf(
    passphrase: Vec<u8>,
    salt: Vec<u8>,
    rounds: u32,
    output_len: u32,
) -> Result<Vec<u8>, String> {
    let mut out = vec![0u8; output_len as usize];
    bcrypt_pbkdf::bcrypt_pbkdf(&passphrase, &salt, rounds, &mut out)
        .map_err(|e| format!("bcrypt_pbkdf: {e}"))?;
    Ok(out)
}

fn to_array32(bytes: &[u8], what: &str) -> Result<[u8; 32], String> {
    <[u8; 32]>::try_from(bytes).map_err(|_| format!("{what} is 32 bytes, got {}", bytes.len()))
}

/// Halves a fixed-width `r || s` into the two integers SSH sends separately.
fn split_rs(bytes: &[u8]) -> EcdsaSignature {
    let half = bytes.len() / 2;
    EcdsaSignature {
        r: bytes[..half].to_vec(),
        s: bytes[half..].to_vec(),
    }
}

/// Rejoins `r` and `s` into the fixed-width form the crates parse.
///
/// Left-pads each: SSH carries them as mpints, so a value with leading zero
/// bytes arrives short, and a caller that stripped a sign byte can arrive one
/// long. Anything that still will not fit is not a signature.
fn join_rs<const HALF: usize>(r: &[u8], s: &[u8]) -> Option<Vec<u8>> {
    let mut out = vec![0u8; HALF * 2];
    for (src, dst) in [(r, 0), (s, HALF)] {
        let src = match src.len() {
            n if n > HALF => {
                if src[..n - HALF].iter().any(|&b| b != 0) {
                    return None;
                }
                &src[n - HALF..]
            }
            _ => src,
        };
        out[dst + HALF - src.len()..dst + HALF].copy_from_slice(src);
    }
    Some(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hex(s: &str) -> Vec<u8> {
        (0..s.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
            .collect()
    }

    /// RFC 7748 section 6.1.
    #[test]
    fn x25519_matches_the_rfc_vector() {
        let alice_priv = hex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a");
        let bob_pub = hex("de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f");
        assert_eq!(
            x25519_shared_secret(alice_priv, bob_pub).unwrap(),
            hex("4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742")
        );
    }

    #[test]
    fn x25519_both_sides_reach_the_same_secret() {
        let a = x25519_keypair();
        let b = x25519_keypair();
        assert_eq!(
            x25519_shared_secret(a.private_key.clone(), b.public_key.clone()).unwrap(),
            x25519_shared_secret(b.private_key, a.public_key).unwrap()
        );
        assert_ne!(a.private_key, vec![0u8; 32]);
    }

    /// A peer that sends a low-order point is choosing the secret for both
    /// sides. Refusing is the whole reason `was_contributory` is checked.
    #[test]
    fn x25519_refuses_a_low_order_point() {
        let a = x25519_keypair();
        assert!(x25519_shared_secret(a.private_key, vec![0u8; 32]).is_err());
    }

    /// RFC 8032 section 7.1, TEST 1.
    #[test]
    fn ed25519_matches_the_rfc_vector() {
        let seed = hex("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60");
        let public = hex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
        let sig = ed25519_sign(seed.clone(), vec![]).unwrap();
        assert_eq!(
            sig,
            hex(
                "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555f\
                 b8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
            )
        );
        assert!(ed25519_verify(public, vec![], sig));
    }

    /// OpenSSH stores seed and public key together; only the seed is used.
    #[test]
    fn ed25519_accepts_the_64_byte_openssh_blob() {
        let seed = hex("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60");
        let public = hex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
        let mut blob = seed.clone();
        blob.extend_from_slice(&public);
        assert_eq!(
            ed25519_sign(blob, b"hello".to_vec()).unwrap(),
            ed25519_sign(seed, b"hello".to_vec()).unwrap()
        );
    }

    #[test]
    fn ed25519_rejects_a_tampered_signature() {
        let seed = vec![3u8; 32];
        let msg = b"authenticate me".to_vec();
        let mut sig = ed25519_sign(seed.clone(), msg.clone()).unwrap();
        let public = {
            let key = ed25519_dalek::SigningKey::from_bytes(&to_array32(&seed, "").unwrap());
            key.verifying_key().to_bytes().to_vec()
        };
        assert!(ed25519_verify(public.clone(), msg.clone(), sig.clone()));

        sig[0] ^= 1;
        assert!(!ed25519_verify(public.clone(), msg.clone(), sig.clone()));

        let mut other = msg.clone();
        other[0] ^= 1;
        sig[0] ^= 1;
        assert!(!ed25519_verify(public, other, sig));
    }

    /// Malformed input answers `false`, not an error on another channel.
    #[test]
    fn ed25519_rejects_malformed_input() {
        assert!(!ed25519_verify(vec![0; 31], vec![], vec![0; 64]));
        assert!(!ed25519_verify(vec![0; 32], vec![], vec![0; 63]));
        assert!(!ed25519_verify(vec![], vec![], vec![]));
    }

    fn ecdsa_public(curve: &str, private_key: &[u8]) -> Vec<u8> {
        // `false` asks for the uncompressed point, which is what SSH sends.
        match curve {
            "nistp256" => p256::ecdsa::SigningKey::from_slice(private_key)
                .unwrap()
                .verifying_key()
                .to_sec1_point(false)
                .as_bytes()
                .to_vec(),
            "nistp384" => p384::ecdsa::SigningKey::from_slice(private_key)
                .unwrap()
                .verifying_key()
                .to_sec1_point(false)
                .as_bytes()
                .to_vec(),
            "nistp521" => p521::ecdsa::SigningKey::from_slice(private_key)
                .unwrap()
                .verifying_key()
                .to_sec1_point(false)
                .as_bytes()
                .to_vec(),
            _ => unreachable!(),
        }
    }

    #[test]
    fn ecdsa_round_trips_on_every_curve() {
        for (curve, width) in [("nistp256", 32), ("nistp384", 48), ("nistp521", 66)] {
            let mut priv_key = vec![0u8; width];
            priv_key[width - 1] = 9; // a small, valid scalar
            let public = ecdsa_public(curve, &priv_key);
            let msg = b"authenticate me".to_vec();

            let sig = ecdsa_sign(curve.into(), priv_key.clone(), msg.clone()).unwrap();
            assert_eq!(sig.r.len(), width, "{curve} r width");
            assert_eq!(sig.s.len(), width, "{curve} s width");
            assert!(
                ecdsa_verify(curve.into(), public.clone(), msg.clone(), sig.r.clone(), sig.s.clone()),
                "{curve}"
            );

            let mut tampered = sig.r.clone();
            tampered[width - 1] ^= 1;
            assert!(
                !ecdsa_verify(curve.into(), public.clone(), msg.clone(), tampered, sig.s.clone()),
                "{curve} tampered r"
            );

            let mut other = msg.clone();
            other[0] ^= 1;
            assert!(
                !ecdsa_verify(curve.into(), public, other, sig.r, sig.s),
                "{curve} wrong message"
            );
        }
    }

    #[test]
    fn ecdsa_refuses_an_unknown_curve() {
        assert!(ecdsa_sign("nistp192".into(), vec![0; 24], vec![]).is_err());
        assert!(!ecdsa_verify("nistp192".into(), vec![], vec![], vec![], vec![]));
    }

    /// SSH carries r and s as mpints, so a value with leading zeroes arrives
    /// short and one that kept a sign byte arrives long. Both have to land in
    /// the same place, and anything that genuinely does not fit must not.
    #[test]
    fn joining_r_and_s_handles_mpint_widths() {
        assert_eq!(join_rs::<4>(&[1, 2], &[3]).unwrap(), vec![0, 0, 1, 2, 0, 0, 0, 3]);
        assert_eq!(join_rs::<2>(&[0, 1, 2], &[3, 4]).unwrap(), vec![1, 2, 3, 4]);
        assert!(join_rs::<2>(&[9, 1, 2], &[3, 4]).is_none());
    }

    /// OpenBSD's own vector, as carried by the bcrypt-pbkdf crate's tests.
    #[test]
    fn bcrypt_pbkdf_matches_the_openbsd_vector() {
        assert_eq!(
            bcrypt_pbkdf(b"password".to_vec(), b"salt".to_vec(), 4, 32).unwrap(),
            hex("5bbf0cc293587f1c3635555c27796598d47e579071bf427e9d8fbe842aba34d9")
        );
    }
}
