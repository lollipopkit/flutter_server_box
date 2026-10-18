//! Clients that cannot read `sbm_parser::protocol` over FFI write the number
//! down themselves: the panel, the iOS and Android widgets and the watch app.
//! Each must say what this crate says, or a raised `MIN_CLIENT_PROTOCOL`
//! would refuse a client that was in fact current.

use std::path::Path;

use sbm_parser::protocol::{HEADER, PROTOCOL};

/// Each client's source, how it writes the number (`{p}`), and the statement
/// that puts it in the header (`{h}`, compared without case). The panel's
/// requests are `protocol.test.ts`'s to check.
const CLIENTS: &[(&str, &str, &str)] = &[
    (
        "monitor/frontend/src/lib/protocol.ts",
        "export const PROTOCOL = {p}",
        "export const PROTOCOL_HEADER = '{h}'",
    ),
    (
        "ios/StatusWidget/WidgetMonitorClient.swift",
        "private let sbmProtocol = \"{p}\"",
        "req.setValue(sbmProtocol, forHTTPHeaderField: \"{h}\")",
    ),
    (
        "ios/WatchApp/MonitorClient.swift",
        "private let sbmProtocol = \"{p}\"",
        "req.setValue(sbmProtocol, forHTTPHeaderField: \"{h}\")",
    ),
    (
        "android/app/src/main/kotlin/tech/lolli/toolbox/widget/WidgetApi.kt",
        "private const val SBM_PROTOCOL = \"{p}\"",
        "setRequestProperty(\"{h}\", SBM_PROTOCOL)",
    ),
];

#[test]
fn every_client_speaks_this_protocol_in_this_header() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    for (file, number, sends) in CLIENTS {
        let src = std::fs::read_to_string(root.join(file)).unwrap_or_else(|e| panic!("{file}: {e}"));
        let number = number.replace("{p}", &PROTOCOL.to_string());
        assert!(src.contains(&number), "{file} should say `{number}`");
        let sends = sends.replace("{h}", HEADER).to_ascii_lowercase();
        assert!(src.to_ascii_lowercase().contains(&sends), "{file} should send it: `{sends}`");
    }
}
