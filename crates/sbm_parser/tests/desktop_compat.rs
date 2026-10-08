//! The app's remote desktop profile tests
//! (`test/unit/remote_desktop/remote_desktop_navigation_test.dart`), ported
//! before its Dart validator was replaced ("test as spec").

use sbm_parser::desktop::{
    ProfileError, ProfileInput, VncPasswordError, validate_profile, validate_vnc_password, vnc_auth_password,
};

#[test]
fn profile_form_requires_the_rdp_username() {
    let input = ProfileInput {
        name: "Desktop".into(),
        protocol: "rdp".into(),
        host: "127.0.0.1".into(),
        port: Some(3389),
        username: Some(String::new()),
        domain: None,
    };
    assert_eq!(validate_profile(&input), Err(ProfileError::UsernameRequired));
}

#[test]
fn classic_vnc_passwords_are_ascii_of_any_length() {
    assert_eq!(validate_vnc_password("12345678"), Ok(()));
    // Longer than the key: accepted, as TigerVNC accepts it (#1637).
    assert_eq!(validate_vnc_password("123456789abc"), Ok(()));
    assert_eq!(validate_vnc_password("密码"), Err(VncPasswordError::NotAscii));
    assert_eq!(validate_vnc_password("密码密码密码密码密"), Err(VncPasswordError::NotAscii));
}

#[test]
fn classic_vnc_authentication_uses_the_first_eight_bytes() {
    assert_eq!(vnc_auth_password("123456789abc"), "12345678");
    assert_eq!(vnc_auth_password("12345678"), "12345678");
    assert_eq!(vnc_auth_password("short"), "short");
    assert_eq!(vnc_auth_password(""), "");
}
