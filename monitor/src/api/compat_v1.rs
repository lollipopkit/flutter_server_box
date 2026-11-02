//! What a client at protocol 1 is answered in its own shape
//! (`sbm_parser::protocol`): one place for every shim, so raising
//! `MIN_CLIENT_PROTOCOL` to 2 is deleting this module and its callers.
//!
//! TODO: remove when MIN_CLIENT_PROTOCOL reaches 2.

use ntex::web::HttpRequest;
use serde_json::{Value, json};

/// Whether [req]'s client is at protocol 1 (or names none).
pub fn applies(req: &HttpRequest) -> bool {
    super::protocol::client_of(req) < 2
}

/// `/capabilities` as protocol 1 had it, beside `access`: `remote_access` and
/// `grants`, every one of them what `access` says, since the one account may
/// do whatever the agent's system account may. `ssh_terminal` is never held
/// (the SSH terminal is gone), so a client offers the agent's own shell
/// instead. `me` stays absent: a client reads that as an agent with no
/// accounts to manage, which is what this one is.
pub fn capabilities(body: &mut Value) {
    let ok = body["access"]["ok"] == true;
    let grant = || match body["access"]["why"].as_str() {
        _ if ok => json!({ "ok": true }),
        Some(why) => json!({ "ok": false, "why": why }),
        None => json!({ "ok": false, "why": "not_granted" }),
    };
    // With the options a full role's grant carried: files writable,
    // connections anywhere, listening on every address.
    let with = |extra: Value| {
        let mut g = grant();
        if let (Value::Object(g), Value::Object(extra)) = (&mut g, extra) {
            g.extend(extra);
        }
        g
    };
    let grants = json!({
        "shell": grant(),
        "ssh_terminal": { "ok": false, "why": "not_granted" },
        "files": with(json!({ "mode": "write" })),
        "connect": with(json!({ "allow": [] })),
        "listen": with(json!({ "public": true })),
        "virt": grant(),
    });
    let remote_access = json!({
        "terminal": ok,
        "full_access": ok,
        "files": ok,
        "stream": ok,
        "listen": ok,
    });
    if let Value::Object(map) = body {
        map.insert("grants".into(), grants);
        map.insert("remote_access".into(), remote_access);
    }
}

/// `GET`/`PUT /bmc` as protocol 1 had it: `editable`, which is always so for
/// whoever reaches the list (the gate before it is the one a change passes).
pub fn bmc_list(body: &mut Value) {
    if let Value::Object(map) = body {
        map.insert("editable".into(), Value::Bool(true));
    }
}
