//! The vendored yabs script, as this agent ships it.
//!
//! One asset and two callers: the app loads `assets/yabs.b64` through
//! `rootBundle` and sends it over SSH, the agent embeds the same file with
//! `include_str!` and writes it to disk before starting a run. Both go through
//! `sbm_parser::bench::decode_asset`. This asserts the copy that reaches an
//! agent's disk is the program `bench::SHA256_HEX` describes — which is what
//! makes the digest a contract between the two rather than a note about one of
//! them.
//!
//! The mirror of this test is `test/unit/benchmark/yabs_script_test.dart`
//! ("the vendored asset"), and the two run against the same file. Refresh the
//! asset with `scripts/update-yabs.sh`, which prints the three constants; both
//! suites fail until they match.

use server_box_monitor::api::benchmark::SCRIPT_ASSET_B64;
use sbm_parser::bench;
use sha2::{Digest, Sha256};

/// The asset as it is checked in — the same bytes `include_str!` reads, read
/// back off disk so the test fails if the file at that path moves or is
/// deleted rather than only if its contents change.
const ASSET_PATH: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../assets/yabs.b64");

#[test]
fn the_embedded_asset_is_the_script_the_digest_describes() {
    let encoded = std::fs::read_to_string(ASSET_PATH)
        .unwrap_or_else(|e| panic!("{ASSET_PATH} could not be read: {e}"));

    // `include_str!` resolved to this file, byte for byte. Two loaders read one
    // asset: the app through `rootBundle`, the agent through this constant, and
    // a build that embedded a stale copy would send a machine a program neither
    // the digest nor the version below accounts for — which the digest check
    // alone cannot see, since it reads the file rather than the constant.
    assert_eq!(
        SCRIPT_ASSET_B64, encoded,
        "the embedded asset is not the checked-in {ASSET_PATH}"
    );

    // Through the shared decoder, so the digest covers the program a machine
    // would be sent rather than the encoding it travels in.
    let text = bench::decode_asset(&encoded).expect("the asset is not valid base64");
    let digest = hex::encode(Sha256::digest(text.as_bytes()));
    assert_eq!(
        digest,
        bench::SHA256_HEX,
        "{ASSET_PATH} changed. If that was deliberate, run \
         scripts/update-yabs.sh and take the constants it prints."
    );

    // It is written to disk and executed, so what a shell reads must be a
    // shell program; the digest above is only evidence that it is the *right*
    // one.
    assert!(
        text.starts_with("#!/bin/bash"),
        "the asset does not begin with a shebang: {:?}",
        &text[..40.min(text.len())]
    );
}

#[test]
fn the_embedded_asset_carries_the_version_it_is_recorded_as() {
    let encoded = std::fs::read_to_string(ASSET_PATH).expect("the asset could not be read");
    let text = bench::decode_asset(&encoded).expect("the asset is not valid base64");

    // `YABS_VERSION="..."` on its own line, which is how upstream spells it.
    let declared = text
        .lines()
        .find_map(|line| {
            line.strip_prefix("YABS_VERSION=\"")
                .and_then(|rest| rest.strip_suffix('"'))
        })
        .expect("the asset declares no YABS_VERSION");

    assert_eq!(declared, bench::UPSTREAM_VERSION);

    // The remote filename carries the version (`script_file_name`), so a
    // version with a space or a path separator in it would put the script
    // somewhere else than a later build looks for it.
    assert!(
        bench::UPSTREAM_VERSION
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '-')),
        "UPSTREAM_VERSION is not a bare filename component: {}",
        bench::UPSTREAM_VERSION
    );
}

#[test]
fn the_asset_is_not_an_executable_asset() {
    // The reason it is base64 at all, stated where the asset lives: App Store
    // validation walks everything inside `Runner.app` and treats a file it
    // reads as code — a script suffix, or a leading `#!` — as a nested code
    // object needing its own signature, which fails the upload (v1574).
    //
    // A base64 document has no `#` on its first byte unless the encoded text
    // happens to start with it, which it cannot: the first byte of a script is
    // `#`, and `Iy` is what base64 makes of it.
    let encoded = std::fs::read_to_string(ASSET_PATH).expect("the asset could not be read");
    assert!(
        !encoded.starts_with("#!"),
        "the asset reads as executable code"
    );
    assert!(
        encoded
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '+' | '/' | '=' | '\n' | '\r')),
        "the asset is not a base64 document"
    );
}
