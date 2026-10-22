//! The backend of an example desk app (`kind: wasm`, docs/dev/desk-sys.md):
//! a component exporting `api` (`wit/uptime.wit`). `status` answers the
//! machine's name, uptime and CPU use from the agent's sample, `who` runs
//! `who` as the agent's account (the `process` permission).

wit_bindgen::generate!({ path: ["../../wit", "wit"], world: "example:uptime/uptime", generate_all });

use exports::example::uptime::api::{Guest, Sample};
use sbm::app::host;
use sbm::app::types::Error;

struct Uptime;

impl Guest for Uptime {
    fn status() -> Result<Sample, Error> {
        let sample: serde_json::Value = serde_json::from_str(&host::status()?).map_err(|e| Error::Internal(e.to_string()))?;
        let text = |k: &str| sample.get(k).and_then(|v| v.as_str().map(str::to_owned).or_else(|| (!v.is_null()).then(|| v.to_string())));
        Ok(Sample { host: text("server_name"), uptime: text("uptime"), cpu: sample.get("cpu_usage").and_then(serde_json::Value::as_f64) })
    }

    fn who() -> Result<String, Error> {
        let out = host::exec("who", None)?;
        Ok(String::from_utf8_lossy(&out.stdout).into_owned())
    }
}

export!(Uptime);
