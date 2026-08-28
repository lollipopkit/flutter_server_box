//! SSH symmetric crypto over FFI: the record-layer cipher and MAC.
//!
//! **Why this exists.** dartssh2 computes AES and HMAC with pointycastle, in
//! Dart, on whichever isolate owns the connection — which in this app is the
//! isolate drawing frames. A terminal streaming output, or a status poll across
//! ten servers, is then AES and SHA-2 competing with layout.
//!
//! **Why it is not simply moved to another isolate instead.** The transport
//! cannot go: the socket underneath it may be a jump connection wrapping a
//! second `SSHClient`, or a `ProxyCommand` wrapping a `Process`, and neither is
//! sendable. Nor can the cipher alone go, because it is stateful per packet and
//! the round trip would cost more than the encryption. So the work stays on the
//! isolate it is on and stops being expensive.
//!
//! **What it covers.** The algorithms dartssh2 proposes first and therefore
//! negotiates in practice: AES in CTR and CBC, and HMAC. AES-GCM and
//! ChaCha20-Poly1305 are implemented inline in the transport rather than behind
//! the factory these fill, so they are left to pointycastle — as is any
//! algorithm named here that a peer does not pick.
//!
//! **State.** CTR carries a counter and CBC a chaining block, both across
//! packets, so one [`SshBlockCipher`] belongs to one direction of one
//! connection for that connection's life. Both types are handed back to Dart
//! opaquely for the same reason: the key never crosses the boundary again.

use aes::cipher::{BlockModeDecrypt, BlockModeEncrypt, KeyIvInit, StreamCipher};
use hmac::{KeyInit as _, Mac as _};

/// AES block size, and so the unit CBC and the packet framing work in.
const AES_BLOCK: usize = 16;

type Ctr<C> = ctr::Ctr128BE<C>;

enum CipherState {
    Ctr128(Ctr<aes::Aes128>),
    Ctr192(Ctr<aes::Aes192>),
    Ctr256(Ctr<aes::Aes256>),
    CbcEnc128(cbc::Encryptor<aes::Aes128>),
    CbcEnc192(cbc::Encryptor<aes::Aes192>),
    CbcEnc256(cbc::Encryptor<aes::Aes256>),
    CbcDec128(cbc::Decryptor<aes::Aes128>),
    CbcDec192(cbc::Decryptor<aes::Aes192>),
    CbcDec256(cbc::Decryptor<aes::Aes256>),
}

/// One direction of one connection's record cipher.
#[flutter_rust_bridge::frb(opaque)]
pub struct SshBlockCipher {
    state: CipherState,
}

impl SshBlockCipher {
    /// A cipher for [`algorithm`], an SSH algorithm name as it appears on the
    /// wire — `aes256-ctr`, `aes128-cbc` and so on.
    ///
    /// `Err` for a name this does not implement, which is the caller's signal
    /// to use its own implementation rather than a failure. Also `Err` for a
    /// key or IV of the wrong length, which is a caller bug: SSH derives both
    /// from the exchange hash at the length the algorithm names.
    ///
    /// `for_encryption` picks the direction. It is meaningless for CTR — the
    /// keystream is the same either way — and is what selects between the two
    /// distinct CBC implementations.
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(
        algorithm: String,
        key: Vec<u8>,
        iv: Vec<u8>,
        for_encryption: bool,
    ) -> Result<SshBlockCipher, String> {
        let (want_key, mode) = match algorithm.as_str() {
            "aes128-ctr" => (16, Mode::Ctr),
            "aes192-ctr" => (24, Mode::Ctr),
            "aes256-ctr" => (32, Mode::Ctr),
            "aes128-cbc" => (16, Mode::Cbc),
            "aes192-cbc" => (24, Mode::Cbc),
            "aes256-cbc" => (32, Mode::Cbc),
            other => return Err(format!("unsupported cipher: {other}")),
        };
        if key.len() != want_key {
            return Err(format!(
                "{algorithm} takes a {want_key}-byte key, got {}",
                key.len()
            ));
        }
        if iv.len() != AES_BLOCK {
            return Err(format!(
                "{algorithm} takes a {AES_BLOCK}-byte IV, got {}",
                iv.len()
            ));
        }

        // Lengths are already checked above, so the only way these fail is a
        // mistake in the table — which `unreachable!` would report as a crash
        // in the middle of a connection, so it is reported as an error instead.
        let bad = |_| format!("{algorithm} rejected a {}-byte key", key.len());
        let state = match (mode, want_key, for_encryption) {
            (Mode::Ctr, 16, _) => {
                CipherState::Ctr128(Ctr::new_from_slices(&key, &iv).map_err(bad)?)
            }
            (Mode::Ctr, 24, _) => {
                CipherState::Ctr192(Ctr::new_from_slices(&key, &iv).map_err(bad)?)
            }
            (Mode::Ctr, 32, _) => {
                CipherState::Ctr256(Ctr::new_from_slices(&key, &iv).map_err(bad)?)
            }
            (Mode::Cbc, 16, true) => {
                CipherState::CbcEnc128(cbc::Encryptor::new_from_slices(&key, &iv).map_err(bad)?)
            }
            (Mode::Cbc, 24, true) => {
                CipherState::CbcEnc192(cbc::Encryptor::new_from_slices(&key, &iv).map_err(bad)?)
            }
            (Mode::Cbc, 32, true) => {
                CipherState::CbcEnc256(cbc::Encryptor::new_from_slices(&key, &iv).map_err(bad)?)
            }
            (Mode::Cbc, 16, false) => {
                CipherState::CbcDec128(cbc::Decryptor::new_from_slices(&key, &iv).map_err(bad)?)
            }
            (Mode::Cbc, 24, false) => {
                CipherState::CbcDec192(cbc::Decryptor::new_from_slices(&key, &iv).map_err(bad)?)
            }
            (Mode::Cbc, 32, false) => {
                CipherState::CbcDec256(cbc::Decryptor::new_from_slices(&key, &iv).map_err(bad)?)
            }
            _ => return Err(format!("no implementation for {algorithm}")),
        };
        Ok(SshBlockCipher { state })
    }

    /// The unit [`process`](Self::process) works in, which is also the packet
    /// alignment the caller pads to.
    #[flutter_rust_bridge::frb(sync)]
    pub fn block_size(&self) -> u32 {
        AES_BLOCK as u32
    }

    /// Transforms [`data`] and advances the cipher past it.
    ///
    /// Call order is the packet order on the wire and cannot be replayed or
    /// skipped — a CTR counter and a CBC chaining block are both positions in
    /// one stream.
    ///
    /// CBC requires whole blocks and says so rather than padding: an SSH packet
    /// is aligned to the block size before it is encrypted, so a length that is
    /// not a multiple of one is a framing bug and silently absorbing it would
    /// hide the bug and corrupt the stream. CTR is a stream cipher and takes
    /// any length.
    #[flutter_rust_bridge::frb(sync)]
    pub fn process(&mut self, data: Vec<u8>) -> Result<Vec<u8>, String> {
        let mut buf = data;
        match &mut self.state {
            CipherState::Ctr128(c) => c.apply_keystream(&mut buf),
            CipherState::Ctr192(c) => c.apply_keystream(&mut buf),
            CipherState::Ctr256(c) => c.apply_keystream(&mut buf),
            state => {
                if buf.len() % AES_BLOCK != 0 {
                    return Err(format!(
                        "CBC takes whole blocks, got {} bytes",
                        buf.len()
                    ));
                }
                for chunk in buf.chunks_exact_mut(AES_BLOCK) {
                    let block = chunk.try_into().expect("chunks_exact_mut gives whole blocks");
                    match state {
                        CipherState::CbcEnc128(c) => c.encrypt_block(block),
                        CipherState::CbcEnc192(c) => c.encrypt_block(block),
                        CipherState::CbcEnc256(c) => c.encrypt_block(block),
                        CipherState::CbcDec128(c) => c.decrypt_block(block),
                        CipherState::CbcDec192(c) => c.decrypt_block(block),
                        CipherState::CbcDec256(c) => c.decrypt_block(block),
                        _ => unreachable!("CTR is handled above"),
                    }
                }
            }
        }
        Ok(buf)
    }
}

#[derive(Clone, Copy)]
enum Mode {
    Ctr,
    Cbc,
}

enum MacState {
    Md5(hmac::Hmac<md5::Md5>),
    Sha1(hmac::Hmac<sha1::Sha1>),
    Sha256(hmac::Hmac<sha2::Sha256>),
    Sha512(hmac::Hmac<sha2::Sha512>),
}

/// One direction of one connection's packet MAC.
#[flutter_rust_bridge::frb(opaque)]
pub struct SshMac {
    state: MacState,
    mac_size: usize,
}

impl SshMac {
    /// A MAC for [`algorithm`], an SSH algorithm name with any `-etm@...` or
    /// `-96` suffix already stripped: neither changes how the tag is computed.
    /// Encrypt-then-MAC changes only *what* the caller feeds in, and the `-96`
    /// variants are a plain truncation, which is what [`mac_size`] expresses.
    ///
    /// `Err` for a name this does not implement, which is the caller's signal
    /// to use its own implementation rather than a failure.
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(algorithm: String, key: Vec<u8>, mac_size: u32) -> Result<SshMac, String> {
        // HMAC takes a key of any length, so nothing is validated here the way
        // it is for a cipher — RFC 2104 hashes one longer than the block and
        // zero-pads one shorter. `new_from_slice` should therefore never fail,
        // but the signature already carries a `Result` and a wrong guess about
        // a third-party crate would otherwise be a panic unwinding into Dart
        // mid-handshake, where an `Err` is a fall back to pointycastle.
        let keyed = |e| format!("{algorithm} rejected a {}-byte key: {e}", key.len());
        let state = match algorithm.as_str() {
            "hmac-md5" => MacState::Md5(
                hmac::Hmac::new_from_slice(&key).map_err(keyed)?,
            ),
            "hmac-sha1" => MacState::Sha1(
                hmac::Hmac::new_from_slice(&key).map_err(keyed)?,
            ),
            "hmac-sha2-256" => MacState::Sha256(
                hmac::Hmac::new_from_slice(&key).map_err(keyed)?,
            ),
            "hmac-sha2-512" => MacState::Sha512(
                hmac::Hmac::new_from_slice(&key).map_err(keyed)?,
            ),
            other => return Err(format!("unsupported mac: {other}")),
        };
        let full = match &state {
            MacState::Md5(_) => 16,
            MacState::Sha1(_) => 20,
            MacState::Sha256(_) => 32,
            MacState::Sha512(_) => 64,
        };
        let mac_size = mac_size as usize;
        if mac_size == 0 || mac_size > full {
            return Err(format!(
                "{algorithm} produces {full} bytes, cannot be truncated to {mac_size}"
            ));
        }
        Ok(SshMac { state, mac_size })
    }

    /// The tag length in bytes, after any truncation.
    #[flutter_rust_bridge::frb(sync)]
    pub fn mac_size(&self) -> u32 {
        self.mac_size as u32
    }

    /// The tag over [`data`], which is one whole packet's MAC input.
    ///
    /// Takes the input in one piece rather than incrementally: a caller that
    /// feeds a sequence number and then a packet would otherwise pay a crossing
    /// per piece, and joining them costs one copy of bytes it is already
    /// holding. The keyed state is cloned per call, so this leaves nothing
    /// behind and cannot be desynchronised by a packet that is dropped.
    #[flutter_rust_bridge::frb(sync)]
    pub fn compute(&self, data: Vec<u8>) -> Vec<u8> {
        let mut tag = match &self.state {
            MacState::Md5(m) => m.clone().chain_update(&data).finalize().into_bytes().to_vec(),
            MacState::Sha1(m) => m.clone().chain_update(&data).finalize().into_bytes().to_vec(),
            MacState::Sha256(m) => m.clone().chain_update(&data).finalize().into_bytes().to_vec(),
            MacState::Sha512(m) => m.clone().chain_update(&data).finalize().into_bytes().to_vec(),
        };
        tag.truncate(self.mac_size);
        tag
    }
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

    /// SP 800-38A F.5.5, AES-256-CTR, first two blocks.
    #[test]
    fn aes256_ctr_matches_nist_vector() {
        let key = hex("603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4");
        let iv = hex("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff");
        let plain = hex("6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51");
        let expected = hex("601ec313775789a5b7a7f504bbf3d228f443e3ca4d62b59aca84e990cacaf5c5");

        let mut c = SshBlockCipher::new("aes256-ctr".into(), key, iv, true).unwrap();
        assert_eq!(c.process(plain).unwrap(), expected);
    }

    /// The counter has to carry across calls, or every packet after the first
    /// decrypts to noise. One call of 32 bytes and two of 16 must agree.
    #[test]
    fn ctr_counter_carries_across_calls() {
        let key = hex("603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4");
        let iv = hex("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff");
        let plain = hex("6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51");

        let mut whole = SshBlockCipher::new("aes256-ctr".into(), key.clone(), iv.clone(), true)
            .unwrap();
        let once = whole.process(plain.clone()).unwrap();

        let mut split = SshBlockCipher::new("aes256-ctr".into(), key, iv, true).unwrap();
        let mut twice = split.process(plain[..16].to_vec()).unwrap();
        twice.extend(split.process(plain[16..].to_vec()).unwrap());

        assert_eq!(once, twice);
    }

    /// CTR is a stream cipher, so a packet that is not block-aligned is legal
    /// and the position must still advance by exactly its length.
    #[test]
    fn ctr_accepts_unaligned_lengths() {
        let key = hex("603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4");
        let iv = hex("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff");
        let plain: Vec<u8> = (0..37).collect();

        let mut whole =
            SshBlockCipher::new("aes256-ctr".into(), key.clone(), iv.clone(), true).unwrap();
        let once = whole.process(plain.clone()).unwrap();

        let mut split = SshBlockCipher::new("aes256-ctr".into(), key, iv, true).unwrap();
        let mut twice = split.process(plain[..5].to_vec()).unwrap();
        twice.extend(split.process(plain[5..].to_vec()).unwrap());

        assert_eq!(once, twice);
    }

    /// SP 800-38A F.2.5/F.2.6, AES-256-CBC.
    #[test]
    fn aes256_cbc_round_trips_against_nist_vector() {
        let key = hex("603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4");
        let iv = hex("000102030405060708090a0b0c0d0e0f");
        let plain = hex("6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51");
        let expected = hex("f58c4c04d6e5f1ba779eabfb5f7bfbd69cfc4e967edb808d679f777bc6702c7d");

        let mut enc =
            SshBlockCipher::new("aes256-cbc".into(), key.clone(), iv.clone(), true).unwrap();
        assert_eq!(enc.process(plain.clone()).unwrap(), expected);

        let mut dec = SshBlockCipher::new("aes256-cbc".into(), key, iv, false).unwrap();
        assert_eq!(dec.process(expected).unwrap(), plain);
    }

    /// The chaining block carries across calls the same way the CTR counter
    /// does, and SSH sends more than one packet per connection.
    #[test]
    fn cbc_chains_across_calls() {
        let key = hex("603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4");
        let iv = hex("000102030405060708090a0b0c0d0e0f");
        let plain = hex("6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51");

        let mut whole =
            SshBlockCipher::new("aes256-cbc".into(), key.clone(), iv.clone(), true).unwrap();
        let once = whole.process(plain.clone()).unwrap();

        let mut split =
            SshBlockCipher::new("aes256-cbc".into(), key, iv, true).unwrap();
        let mut twice = split.process(plain[..16].to_vec()).unwrap();
        twice.extend(split.process(plain[16..].to_vec()).unwrap());

        assert_eq!(once, twice);
    }

    #[test]
    fn cbc_refuses_a_partial_block() {
        let key = vec![0u8; 32];
        let iv = vec![0u8; 16];
        let mut c = SshBlockCipher::new("aes256-cbc".into(), key, iv, true).unwrap();
        assert!(c.process(vec![0u8; 17]).is_err());
    }

    #[test]
    fn unknown_algorithms_are_reported_not_guessed() {
        assert!(SshBlockCipher::new("aes256-gcm@openssh.com".into(), vec![0; 32], vec![0; 16], true)
            .is_err());
        assert!(SshMac::new("hmac-ripemd160".into(), vec![0; 20], 20).is_err());
    }

    #[test]
    fn wrong_key_and_iv_lengths_are_refused() {
        assert!(SshBlockCipher::new("aes256-ctr".into(), vec![0; 16], vec![0; 16], true).is_err());
        assert!(SshBlockCipher::new("aes256-ctr".into(), vec![0; 32], vec![0; 12], true).is_err());
    }

    /// RFC 4231 test case 2.
    #[test]
    fn hmac_sha256_matches_rfc_vector() {
        let mac = SshMac::new("hmac-sha2-256".into(), b"Jefe".to_vec(), 32).unwrap();
        assert_eq!(
            mac.compute(b"what do ya want for nothing?".to_vec()),
            hex("5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843")
        );
    }

    /// RFC 4231 test case 2, SHA-512.
    #[test]
    fn hmac_sha512_matches_rfc_vector() {
        let mac = SshMac::new("hmac-sha2-512".into(), b"Jefe".to_vec(), 64).unwrap();
        assert_eq!(
            mac.compute(b"what do ya want for nothing?".to_vec()),
            hex(
                "164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea250554\
                 9758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737"
            )
        );
    }

    /// A MAC computed twice must be the same: the keyed state is cloned per
    /// call, and a leaked update would show up here as a second, different tag.
    #[test]
    fn mac_state_does_not_leak_between_calls() {
        let mac = SshMac::new("hmac-sha2-256".into(), vec![7; 32], 32).unwrap();
        assert_eq!(mac.compute(b"packet".to_vec()), mac.compute(b"packet".to_vec()));
    }

    /// The `-96` variants are the full tag cut to 12 bytes.
    #[test]
    fn truncated_mac_is_a_prefix_of_the_full_one() {
        let full = SshMac::new("hmac-sha2-256".into(), vec![7; 32], 32).unwrap();
        let cut = SshMac::new("hmac-sha2-256".into(), vec![7; 32], 12).unwrap();
        assert_eq!(cut.mac_size(), 12);
        assert_eq!(cut.compute(b"packet".to_vec()), full.compute(b"packet".to_vec())[..12]);
    }

    #[test]
    fn a_truncation_longer_than_the_digest_is_refused() {
        assert!(SshMac::new("hmac-sha2-256".into(), vec![7; 32], 33).is_err());
        assert!(SshMac::new("hmac-sha2-256".into(), vec![7; 32], 0).is_err());
    }
}
