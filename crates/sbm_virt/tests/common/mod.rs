//! A scripted PVE API for `pve::Client` tests: routes by `METHOD /path`,
//! every request recorded (path, body, query), tasks answered as done.
#![allow(dead_code)]

use std::collections::{BTreeMap, HashMap};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use sbm_virt::error::Error;
use sbm_virt::pve::http::{BoxFuture, Connector, Http, Request, Response, TransportError};
use sbm_virt::pve::{Auth, Client, Config, Options};
use serde_json::{Value, json};
use tokio::sync::Notify;

pub const UPID: &str = "UPID:pve:0001:0002:0003:srvreload:networking:root@pam:";

pub fn fixture(name: &str) -> Value {
    let path = format!("{}/tests/fixtures/pve/{name}", env!("CARGO_MANIFEST_DIR"));
    serde_json::from_str(&std::fs::read_to_string(path).unwrap()).unwrap()
}

pub fn list(name: &str) -> Vec<Value> {
    fixture(name).as_array().unwrap().clone()
}

pub type Route = Box<dyn Fn(&str) -> Response + Send>;

#[derive(Default)]
pub struct Api {
    pub routes: HashMap<String, Route>,
    /// Held until notified: a request in flight.
    pub gates: HashMap<String, Arc<Notify>>,
    pub paths: Vec<String>,
    pub bodies: Vec<String>,
    /// Each request's query, `?` left out.
    pub queries: Vec<String>,
}

#[derive(Clone, Default)]
pub struct Fake(pub Arc<Mutex<Api>>);

impl Fake {
    pub fn new() -> Self {
        let fake = Fake::default();
        fake.route("GET /nodes", |_| ok(json!([{"node": "pve", "status": "online"}])));
        fake.route("GET /cluster/resources", |_| ok(json!([])));
        // The node's own listings, which a check reads names and states
        // from: nothing more than the cluster's unless a test says so.
        fake.route("GET /nodes/pve/qemu", |_| ok(json!([])));
        fake.route("GET /nodes/pve/lxc", |_| ok(json!([])));
        fake
    }

    pub fn route(&self, key: &str, f: impl Fn(&str) -> Response + Send + 'static) {
        self.0.lock().unwrap().routes.insert(key.to_owned(), Box::new(f));
    }

    pub fn paths(&self) -> Vec<String> {
        self.0.lock().unwrap().paths.clone()
    }

    /// The form of the last request to `key`.
    pub fn form(&self, key: &str) -> BTreeMap<String, String> {
        let a = self.0.lock().unwrap();
        let i = a.paths.iter().rposition(|p| p == key).unwrap_or_else(|| panic!("no {key} in {:?}", a.paths));
        form_of(&a.bodies[i])
    }

    pub fn forms(&self, key: &str) -> Vec<BTreeMap<String, String>> {
        let a = self.0.lock().unwrap();
        a.paths.iter().zip(&a.bodies).filter(|(p, _)| *p == key).map(|(_, b)| form_of(b)).collect()
    }

    pub fn client(&self) -> Client {
        let config = Config {
            addr: "https://pve.lan:8006".into(),
            auth: Auth::Token { id: "root@pam!sb".into(), secret: "s3cret".into() },
            cert_sha256: None,
        };
        let opts = Options { task_poll: Duration::from_millis(1), ..Options::default() };
        Client::new(config, Arc::new(self.clone()), opts)
    }
}

pub fn form_of(body: &str) -> BTreeMap<String, String> {
    body.split('&')
        .filter(|f| !f.is_empty())
        .map(|f| {
            let (k, v) = f.split_once('=').unwrap_or((f, ""));
            (decode(k), decode(v))
        })
        .collect()
}

pub fn decode(s: &str) -> String {
    let b = s.replace('+', " ");
    let bytes = b.as_bytes();
    let mut out = Vec::new();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 3 <= bytes.len() {
            out.push(u8::from_str_radix(&b[i + 1..i + 3], 16).unwrap());
            i += 3;
        } else {
            out.push(bytes[i]);
            i += 1;
        }
    }
    String::from_utf8(out).unwrap()
}

pub fn ok(data: Value) -> Response {
    whole(json!({ "data": data }))
}

pub fn whole(body: Value) -> Response {
    Response { status: 200, reason: None, body: body.to_string().into_bytes() }
}

pub fn status(code: u16, message: &str) -> Response {
    Response { status: code, reason: None, body: json!({"data": null, "message": message}).to_string().into_bytes() }
}

impl Connector for Fake {
    fn http(&self, _: &Config) -> Result<Arc<dyn Http>, Error> {
        Ok(Arc::new(self.clone()))
    }
}

impl Http for Fake {
    fn send(&self, req: Request) -> BoxFuture<'_, Result<Response, TransportError>> {
        Box::pin(async move {
            let full = req.path.trim_start_matches("/api2/json");
            let (path, query) = full.split_once('?').unwrap_or((full, ""));
            let path = path.to_owned();
            let key = format!("{} {path}", req.method.as_str());
            let body = req.body.as_ref().map(|b| String::from_utf8_lossy(&b.bytes).into_owned()).unwrap_or_default();
            let gate = {
                let mut a = self.0.lock().unwrap();
                a.paths.push(key.clone());
                a.bodies.push(body.clone());
                a.queries.push(query.to_owned());
                a.gates.get(&key).cloned()
            };
            if let Some(gate) = gate {
                gate.notified().await;
            }
            let a = self.0.lock().unwrap();
            if let Some(route) = a.routes.get(&key) {
                return Ok(route(&body));
            }
            if path.contains("/tasks/") {
                return Ok(ok(json!({"status": "stopped", "exitstatus": "OK"})));
            }
            Ok(status(404, "no route"))
        })
    }
}

pub async fn err<T: std::fmt::Debug>(f: impl std::future::Future<Output = Result<T, Error>>) -> Error {
    f.await.expect_err("expected an error")
}

