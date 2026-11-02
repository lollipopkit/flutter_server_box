//! Cleanup's backend: what can go to free space (`sbm_parser::cleanup`).
//! `api.view` answers the last scan; `jobs.scan` and `jobs.clean` run as
//! root. The last scan is kept in the app's storage, as `sbm_parser` writes
//! it.

wit_bindgen::generate!({ path: ["../../wit", "wit"], world: "serverbox:cleanup/cleanup", generate_all });

use exports::serverbox::cleanup::api::{self, Group, Item, Report};
use exports::serverbox::cleanup::jobs;
use sbm::app::types::Error;
use sbm::app::{agent, host, job};
use sbm_parser::cleanup as cl;
use serde::{Deserialize, Serialize};

struct App;

/// What is kept between calls: the parser's own items.
#[derive(Serialize, Deserialize)]
struct Kept {
    at: i64,
    items: Vec<cl::Item>,
}

const LAST: &str = "last";

fn home() -> Result<String, Error> {
    host::home().filter(|h| h.starts_with('/')).ok_or_else(|| Error::Unavailable("noHome".into()))
}

fn last() -> Option<Kept> {
    host::kv_get(LAST).and_then(|v| serde_json::from_str(&v).ok())
}

fn now_ms() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_millis() as i64).unwrap_or(0)
}

fn report(kept: Kept) -> Report {
    Report {
        at: kept.at,
        items: kept
            .items
            .into_iter()
            .map(|i| Item {
                id: i.id,
                group: match i.group {
                    cl::Group::System => Group::System,
                    cl::Group::Account => Group::Account,
                    cl::Group::Apps => Group::Apps,
                    cl::Group::Containers => Group::Containers,
                },
                bytes: i.bytes,
                count: i.count,
                detail: i.detail,
                cleanable: i.cleanable,
            })
            .collect(),
    }
}

/// A scan as root; items holding the agent's state are not cleanable.
fn scan(home: &str, left: &[(String, String)]) -> Result<Vec<cl::Item>, Error> {
    let out = host::exec_root(&cl::scan_script(home, left))?;
    let stderr = String::from_utf8_lossy(&out.stderr);
    for line in stderr.lines() {
        job::line(line);
    }
    if out.status != 0 {
        return Err(Error::Internal(format!("the scan exited with {}", out.status)));
    }
    let mut items = cl::parse_scan(&String::from_utf8_lossy(&out.stdout));
    for item in &mut items {
        if cl::account_path(home, &item.id).is_some_and(|p| agent::holds_state(&p)) {
            item.cleanable = false;
        }
    }
    Ok(items)
}

fn keep(items: Vec<cl::Item>) -> Result<Report, Error> {
    let kept = Kept { at: now_ms(), items };
    host::kv_set(LAST, &serde_json::to_string(&kept).map_err(|e| Error::Internal(e.to_string()))?)?;
    Ok(report(kept))
}

impl api::Guest for App {
    fn view() -> Result<Option<Report>, Error> {
        Ok(last().map(report))
    }
}

impl jobs::Guest for App {
    fn scan() -> Result<Report, Error> {
        let home = home()?;
        keep(scan(&home, &agent::stack_leftovers())?)
    }

    fn clean(ids: Vec<String>) -> Result<Report, Error> {
        let home = home()?;
        // Refused on what the page saw; checked again on a fresh scan.
        let seen = last().ok_or_else(|| Error::FailedPrecondition("notScanned".into()))?;
        cl::check(&seen.items, &ids).map_err(|e| Error::InvalidArgument(e.into()))?;
        let left = agent::stack_leftovers();
        let now = scan(&home, &left)?;
        cl::check(&now, &ids).map_err(|e| Error::FailedPrecondition(format!("{e}: the machine changed since its scan")))?;
        let freed: u64 = now.iter().filter(|i| ids.contains(&i.id)).map(|i| i.bytes).sum();
        let status = job::run_root(&cl::clean_script(&home, &ids, &left))?;
        if status != 0 {
            return Err(Error::Internal(format!("the removal exited with {status}")));
        }
        let after = keep(scan(&home, &agent::stack_leftovers())?)?;
        job::line(&format!("about {} MiB freed", freed >> 20));
        Ok(after)
    }
}

export!(App);
