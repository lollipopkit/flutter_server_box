//! A refusal says why, in fl_lib's words: a few held to the exact message,
//! so a test that refuses for the wrong reason cannot pass.

mod common;

use common::*;
use sbm_theme::install;
use serde_json::json;

fn why(bytes: &[u8]) -> String {
    install(bytes).unwrap_err().0
}

#[test]
fn refusals_name_their_reason() {
    let mut m = package("gradient");
    m["appIcon"] = json!("x");
    assert_eq!(why(&bundle(&m, &[])), "Unsupported theme package");

    let mut m = package("gradient");
    m["splas"] = json!({});
    assert_eq!(why(&bundle(&m, &[])), "Unknown theme section");

    let mut m = package("gradient");
    m["icons"]["images"]["Tab.server"] = json!("x");
    assert_eq!(why(&bundle(&m, &[])), "Invalid icon keys");

    let mut m = package2();
    m["icons"]["images"]["tab.server"] = json!("icons/tab_server.svg");
    assert_eq!(
        why(&bundle(&m, &[("icons/tab_server.svg", b"<svg><script>x</script></svg>")])),
        "Unsupported SVG content"
    );
    assert_eq!(
        why(&bundle(&m, &[("icons/tab_server.svg", b"<html/>")])),
        "An SVG must have svg as its root element"
    );

    let mut m = package("gradient");
    m["schema"] = json!({"min": 1, "max": 1});
    m["layout"] = json!({"density": "compact"});
    assert_eq!(why(&bundle(&m, &[])), "This theme needs schema 3");

    let mut m = package("gradient");
    m["modes"] = json!(["light", "light"]);
    assert_eq!(why(&bundle(&m, &[])), "Declare supported theme modes: light, dark");

    assert_eq!(why(&bundle(&package("gradient"), &[("extra.txt", b"x")])), "Unexpected theme asset");
    assert_eq!(why(&bundle(&package("gradient"), &[("../x", b"x")])), "Invalid theme ZIP entry");
    assert_eq!(why(b"not a zip"), "Invalid theme ZIP");
    assert_eq!(why(&raw_bundle("id = [", &[])), "Invalid TOML manifest");

    let mut m = package("gradient");
    m["components"] = json!({"button": {"color": 1}});
    assert_eq!(why(&bundle(&m, &[])), "Unknown button field: color");
}
