//! A service made of recorded responses, for the walks that run against
//! [`sbm_redfish::Transport`] — the Dart suites' `_FakeTransport`.
#![allow(dead_code)]

use std::collections::{HashMap, HashSet};
use std::sync::Mutex;

use sbm_redfish::{Error, Failure, Outcome, Transport};
use serde_json::{Map, Value};

pub struct FakeTransport {
    pub resources: HashMap<String, Value>,
    pub forbidden: HashSet<String>,
    pub gets: Mutex<Vec<String>>,
    pub posted: Mutex<Vec<(String, Value)>>,
}

impl FakeTransport {
    pub fn new(resources: HashMap<String, Value>) -> Self {
        Self {
            resources,
            forbidden: HashSet::new(),
            gets: Mutex::new(Vec::new()),
            posted: Mutex::new(Vec::new()),
        }
    }

    pub fn forbidding(mut self, path: &str) -> Self {
        self.forbidden.insert(path.to_string());
        self
    }

    pub fn get_count(&self) -> usize {
        self.gets.lock().unwrap().len()
    }
}

impl Transport for FakeTransport {
    async fn get(&self, path: &str) -> Result<Value, Error> {
        self.gets.lock().unwrap().push(path.to_string());
        if self.forbidden.contains(path) {
            return Err(Error::with(Failure::Forbidden, path));
        }
        self.resources
            .get(path)
            .cloned()
            .ok_or_else(|| Error::with(Failure::Unreachable, format!("no such resource: {path}")))
    }

    async fn post(&self, path: &str, body: Value) -> Result<Outcome, Error> {
        self.posted.lock().unwrap().push((path.to_string(), body));
        Ok(Outcome::Done)
    }
}

/// A vendor's recorded service: `tests/fixtures/<name>.json`, a map of path to
/// document.
pub fn vendor(name: &str) -> HashMap<String, Value> {
    let path = format!("{}/tests/fixtures/{name}.json", env!("CARGO_MANIFEST_DIR"));
    let text = std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("{path}: {e}"));
    let map: Map<String, Value> = serde_json::from_str(&text).unwrap();
    map.into_iter().collect()
}

pub fn fixture(name: &str) -> Value {
    let path = format!("{}/tests/fixtures/{name}.json", env!("CARGO_MANIFEST_DIR"));
    serde_json::from_str(&std::fs::read_to_string(&path).unwrap()).unwrap()
}
