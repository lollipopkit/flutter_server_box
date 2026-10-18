//! Clients that cannot read `sbm_parser::protocol` over FFI write the number
//! down themselves: the panel, the iOS and Android widgets and the watch app.
//! Each must say what this crate says, or a raised `MIN_CLIENT_PROTOCOL`
//! would refuse a client that was in fact current.

use std::path::Path;

use sbm_parser::protocol::{HEADER, PROTOCOL};

/// Each client's source, and how it writes the number.
const CLIENTS: &[(&str, &str)] = &[
    ("monitor/frontend/src/lib/protocol.ts", "export const PROTOCOL = {}"),
    ("ios/StatusWidget/WidgetMonitorClient.swift", "private let sbmProtocol = \"{}\""),
    ("ios/WatchApp/MonitorClient.swift", "private let sbmProtocol = \"{}\""),
    ("android/app/src/main/kotlin/tech/lolli/toolbox/widget/WidgetApi.kt", "private const val SBM_PROTOCOL = \"{}\""),
];

#[test]
fn every_client_speaks_this_protocol_in_this_header() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    for (file, pattern) in CLIENTS {
        let src = std::fs::read_to_string(root.join(file)).unwrap_or_else(|e| panic!("{file}: {e}"));
        let expected = pattern.replace("{}", &PROTOCOL.to_string());
        assert!(src.contains(&expected), "{file} should say `{expected}`");
        assert!(src.to_ascii_lowercase().contains(HEADER), "{file} should send {HEADER}");
    }
}
