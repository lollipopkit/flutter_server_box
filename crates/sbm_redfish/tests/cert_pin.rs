//! What will and will not be accepted from a BMC's TLS certificate —
//! `cert_pin_test.dart`. The half worth locking down is enforcement, because
//! every way it could be wrong is a way to accept the wrong certificate
//! silently; and the stored format, because existing installs hold pins in it.

use sbm_redfish::cert::{
    CertInfo, PinnedCert, fingerprint, is_fingerprint, normalize_fingerprint, pretty_fingerprint,
};

const CERT_A: &[u8] = &[1, 2, 3, 4];
const CERT_B: &[u8] = &[1, 2, 3, 5];

/// `sha256.convert([1, 2, 3, 4]).toString()` in Dart — the format pins are
/// stored in.
const FP_A: &str = "9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a";

#[test]
fn the_fingerprint_is_sha256_of_the_der_as_dart_printed_it() {
    assert_eq!(fingerprint(CERT_A), FP_A);
    assert_eq!(FP_A.len(), 64);
    assert!(FP_A.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)));
}

#[test]
fn a_one_byte_difference_is_a_different_fingerprint() {
    assert_ne!(fingerprint(CERT_A), fingerprint(CERT_B));
}

#[test]
fn accepts_the_certificate_that_was_pinned() {
    assert!(PinnedCert::new(Some(FP_A)).accepts(Some(CERT_A)));
}

#[test]
fn refuses_a_different_certificate() {
    assert!(!PinnedCert::new(Some(FP_A)).accepts(Some(CERT_B)));
}

#[test]
fn refuses_everything_when_nothing_has_been_reviewed() {
    // Not trust-on-first-*use*: the first use is a request already carrying a
    // password.
    assert!(!PinnedCert::new(None).accepts(Some(CERT_A)));
    assert!(!PinnedCert::new(Some("")).accepts(Some(CERT_A)));
}

#[test]
fn refuses_a_missing_certificate_even_when_something_is_pinned() {
    assert!(!PinnedCert::new(Some(FP_A)).accepts(None));
}

#[test]
fn compares_case_insensitively_since_the_pin_is_stored_as_text() {
    assert!(PinnedCert::new(Some(&FP_A.to_uppercase())).accepts(Some(CERT_A)));
}

#[test]
fn accepts_the_pin_as_a_bmc_web_ui_prints_it() {
    // Not something Dart stored, but a pasted pin; the same certificate.
    assert!(PinnedCert::new(Some(&pretty_fingerprint(FP_A))).accepts(Some(CERT_A)));
}

#[test]
fn a_truncated_pin_does_not_match_by_prefix() {
    assert!(!PinnedCert::new(Some(&FP_A[..32])).accepts(Some(CERT_A)));
}

#[test]
fn has_pin_distinguishes_unreviewed_from_reviewed() {
    assert!(!PinnedCert::new(None).has_pin());
    assert!(!PinnedCert::new(Some("")).has_pin());
    assert!(PinnedCert::new(Some(FP_A)).has_pin());
}

#[test]
fn normalizing_leaves_a_stored_pin_unchanged() {
    assert_eq!(normalize_fingerprint(FP_A), FP_A);
    assert_eq!(normalize_fingerprint(&pretty_fingerprint(FP_A)), FP_A);
    assert_eq!(normalize_fingerprint("AB cd-EF"), "abcdef");
    assert!(is_fingerprint(FP_A));
    assert!(is_fingerprint(&pretty_fingerprint(FP_A)));
    assert!(!is_fingerprint(&FP_A[..63]));
    assert!(!is_fingerprint(&format!("{}g", &FP_A[..63])));
    assert!(!is_fingerprint(""));
}

fn info(fingerprint: &str, not_before: i64, not_after: i64) -> CertInfo {
    CertInfo {
        fingerprint: fingerprint.into(),
        subject: "/CN=bmc".into(),
        issuer: "/CN=bmc".into(),
        not_before,
        not_after,
    }
}

#[test]
fn prints_the_fingerprint_the_way_a_bmc_web_ui_does() {
    assert_eq!(info("abcd1234", 0, 0).pretty_fingerprint(), "AB:CD:12:34");
    assert_eq!(pretty_fingerprint("abc"), "AB", "pairs only, as Dart's loop");
}

#[test]
fn an_expired_certificate_is_reported_not_refused() {
    // 2000-01-01 to 2000-01-02.
    let past = info(FP_A, 946_684_800, 946_771_200);
    assert!(past.is_expired());
    assert!(past.is_expired_at(946_684_799), "not yet valid counts too");
    assert!(!past.is_expired_at(946_700_000));
    // and the pin still accepts it: dates are shown, never enforced
    assert!(PinnedCert::new(Some(FP_A)).accepts(Some(CERT_A)));
}

#[test]
fn reads_the_test_certificate() {
    let pem = std::fs::read_to_string(concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/redfish_test_cert.pem")).unwrap();
    let body: String = pem.lines().filter(|l| !l.starts_with("-----")).collect();
    let der = decode_base64(&body);
    let info = CertInfo::from_der(&der).unwrap();
    assert_eq!(info.fingerprint, fingerprint(&der));
    assert_eq!(info.subject, "/CN=localhost");
    assert_eq!(info.issuer, "/CN=localhost");
    assert!(info.not_before < info.not_after);
    assert!(CertInfo::from_der(b"not a certificate").is_none());
}

fn decode_base64(s: &str) -> Vec<u8> {
    use base64::Engine as _;
    base64::engine::general_purpose::STANDARD.decode(s).unwrap()
}
