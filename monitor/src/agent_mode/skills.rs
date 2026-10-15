//! Skills for Agent mode: folders under the agent's `skills/`, each a
//! `SKILL.md` and the files it points to (`fl_pi_llm::host::skills`). Every
//! task is told the enabled ones and gets the `skill` tool to load them.
//!
//! The operator installs one from a GitHub repository as `npx skills add` takes
//! it, or puts a folder there; `agent_skill` (migration 031) remembers where
//! each came from and whether it is offered.

use std::collections::BTreeMap;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use fl_pi_llm::host::skills::{self as pi_skills, FoundSkill, GitHubSource, Skill, SkillTool, Skills};
use fl_pi_llm::host::{Fetch, FetchRequest, Tool};
use serde::Serialize;
use serde_json::{Value, json};
use sqlx::SqlitePool;

/// What a source's archive may be, downloaded and unpacked.
const MAX_DOWNLOAD: usize = 50 << 20;
const MAX_UNPACKED: usize = 200 << 20;
const MAX_ENTRIES: usize = 20_000;
/// One file of a skill, at most; a larger one is left out.
const MAX_FILE: usize = 8 << 20;
pub const MAX_SKILLS: usize = 64;

/// `skills/` in the agent's directory.
pub fn root(agent_dir: &Path) -> PathBuf {
    agent_dir.join("skills")
}

/// A skill as the settings page shows it.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SkillView {
    pub dir: String,
    pub name: String,
    pub description: String,
    pub enabled: bool,
    /// Where it was installed from (`owner/repo[/path]`); None for a folder
    /// put there by hand.
    pub source: Option<String>,
    pub files: usize,
}

async fn rows(db: &SqlitePool) -> Result<BTreeMap<String, (bool, Option<String>)>, sqlx::Error> {
    Ok(sqlx::query_as::<_, (String, bool, Option<String>)>("SELECT dir, enabled, source FROM agent_skill")
        .fetch_all(db)
        .await?
        .into_iter()
        .map(|(dir, enabled, source)| (dir, (enabled, source)))
        .collect())
}

/// Every skill in [root], with whether it is offered.
pub async fn list(db: &SqlitePool, root: &Path) -> Result<Vec<SkillView>, sqlx::Error> {
    let rows = rows(db).await?;
    let skills = Skills::new(root);
    Ok(skills
        .list()
        .into_iter()
        .map(|s| {
            let (enabled, source) = rows.get(&s.dir).cloned().unwrap_or((true, None));
            let source = source.and_then(|j| serde_json::from_str::<Value>(&j).ok()).and_then(|v| v["id"].as_str().map(String::from));
            let files = skills.files_of(&s.dir).len();
            SkillView { dir: s.dir, name: s.name, description: s.description, enabled, source, files }
        })
        .collect())
}

/// The enabled skills: what a task is told and may load.
pub async fn offered(db: &SqlitePool, root: &Path) -> Vec<Skill> {
    let rows = rows(db).await.unwrap_or_default();
    Skills::new(root).list().into_iter().filter(|s| rows.get(&s.dir).is_none_or(|(on, _)| *on)).collect()
}

/// The system prompt's part and the `skill` tool for a task; None without an
/// enabled skill.
pub async fn for_task(db: &SqlitePool, root: &Path) -> Option<(String, Arc<dyn Tool>)> {
    let offered = offered(db, root).await;
    let prompt = pi_skills::prompt(&offered)?;
    Some((prompt, Arc::new(SkillTool { skills: Skills::new(root), offered })))
}

pub async fn set_enabled(db: &SqlitePool, root: &Path, dir: &str, enabled: bool) -> Result<bool, sqlx::Error> {
    if !Skills::new(root).list().iter().any(|s| s.dir == dir) {
        return Ok(false);
    }
    sqlx::query(
        "INSERT INTO agent_skill (dir, enabled, source, installed_at) VALUES (?, ?, NULL, ?) \
         ON CONFLICT(dir) DO UPDATE SET enabled = excluded.enabled",
    )
    .bind(dir)
    .bind(enabled)
    .bind(chrono::Utc::now().to_rfc3339())
    .execute(db)
    .await?;
    Ok(true)
}

/// Removes skill [dir]: its folder and its row. False when there is none.
pub async fn remove(db: &SqlitePool, root: &Path, dir: &str) -> Result<bool, String> {
    if !Skills::new(root).list().iter().any(|s| s.dir == dir) {
        return Ok(false);
    }
    tokio::fs::remove_dir_all(root.join(dir)).await.map_err(|e| e.to_string())?;
    sqlx::query("DELETE FROM agent_skill WHERE dir = ?").bind(dir).execute(db).await.map_err(|e| e.to_string())?;
    Ok(true)
}

/// Why an install did not happen, in the panel's terms.
#[derive(Debug, PartialEq, Eq)]
pub enum InstallError {
    /// Not a source this reads.
    Source(String),
    /// The download or its archive failed.
    Fetch(String),
    /// Nothing in it is a skill (or not the one asked for).
    NoSkill,
    TooMany,
    Write(String),
}

/// Installs the skills [input] names (all of the source's, or the one it
/// asks for), replacing those of the same name; answers their folders.
pub async fn install(db: &SqlitePool, root: &Path, fetch: &dyn Fetch, input: &str) -> Result<Vec<String>, InstallError> {
    let source = GitHubSource::parse(input).map_err(InstallError::Source)?;
    let files = download(fetch, &source.archive_url()).await.map_err(InstallError::Fetch)?;
    let mut found: Vec<FoundSkill> = pi_skills::find(&files, source.path.as_deref());
    if let Some(wanted) = &source.skill {
        found.retain(|s| s.name.eq_ignore_ascii_case(wanted) || pi_skills::dir_name(&s.name) == pi_skills::dir_name(wanted));
    }
    if found.is_empty() {
        return Err(InstallError::NoSkill);
    }
    let existing: Vec<String> = Skills::new(root).list().into_iter().map(|s| s.dir).collect();
    let new = found.iter().filter(|s| !existing.contains(&pi_skills::dir_name(&s.name))).count();
    if existing.len() + new > MAX_SKILLS {
        return Err(InstallError::TooMany);
    }
    let now = chrono::Utc::now().to_rfc3339();
    let mut dirs = Vec::new();
    for skill in found {
        let dir = pi_skills::dir_name(&skill.name);
        // Written beside, then put in place: a failure leaves the old one.
        let staged = root.join(format!(".{dir}.new"));
        let write = async {
            let _ = tokio::fs::remove_dir_all(&staged).await;
            for (rel, bytes) in &skill.files {
                let path = staged.join(rel);
                if let Some(parent) = path.parent() {
                    tokio::fs::create_dir_all(parent).await?;
                }
                tokio::fs::write(&path, bytes).await?;
            }
            let target = root.join(&dir);
            let _ = tokio::fs::remove_dir_all(&target).await;
            tokio::fs::rename(&staged, &target).await
        };
        if let Err(e) = write.await {
            let _ = tokio::fs::remove_dir_all(&staged).await;
            return Err(InstallError::Write(e.to_string()));
        }
        let mut from = json!({ "type": "github", "owner": source.owner, "repo": source.repo, "id": source.id() });
        if let Some(r) = &source.r#ref {
            from["ref"] = json!(r);
        }
        if !skill.dir.is_empty() {
            from["path"] = json!(skill.dir);
        }
        sqlx::query(
            "INSERT INTO agent_skill (dir, enabled, source, installed_at) VALUES (?, 1, ?, ?) \
             ON CONFLICT(dir) DO UPDATE SET source = excluded.source, installed_at = excluded.installed_at",
        )
        .bind(&dir)
        .bind(from.to_string())
        .bind(&now)
        .execute(db)
        .await
        .map_err(|e| InstallError::Write(e.to_string()))?;
        dirs.push(dir);
    }
    Ok(dirs)
}

/// [url]'s `.tar.gz`, unpacked: its files by path, without the folder the
/// archive wraps them in. Files too large for a skill are left out.
async fn download(fetch: &dyn Fetch, url: &str) -> Result<BTreeMap<String, Vec<u8>>, String> {
    let req = FetchRequest { url: url.into(), method: "GET".into(), headers: vec![("user-agent".into(), "server-box-monitor".into())], body: None };
    let mut res = fetch.fetch(req).await?;
    if res.status != 200 {
        return Err(format!("HTTP {}", res.status));
    }
    let mut bytes = Vec::new();
    while let Some(chunk) = res.body.recv().await {
        bytes.extend(chunk?);
        if bytes.len() > MAX_DOWNLOAD {
            return Err("the archive is larger than 50 MiB".into());
        }
    }
    tokio::task::spawn_blocking(move || unpack(&bytes)).await.map_err(|e| e.to_string())?
}

fn unpack(gz: &[u8]) -> Result<BTreeMap<String, Vec<u8>>, String> {
    let bad = |e: std::io::Error| format!("not a readable .tar.gz: {e}");
    let mut archive = tar::Archive::new(flate2::read::GzDecoder::new(gz));
    let mut files = BTreeMap::new();
    let (mut total, mut count) = (0usize, 0usize);
    for entry in archive.entries().map_err(bad)? {
        let entry = entry.map_err(bad)?;
        count += 1;
        if count > MAX_ENTRIES {
            return Err("the archive has too many files".into());
        }
        if !entry.header().entry_type().is_file() {
            continue;
        }
        let raw = entry.path().map_err(bad)?.to_string_lossy().into_owned();
        // The wrapping folder goes; a path that climbs out is never written.
        let parts: Vec<&str> = raw.split('/').filter(|p| !p.is_empty() && *p != ".").collect();
        if parts.len() < 2 || parts.contains(&"..") {
            continue;
        }
        let size = entry.size() as usize;
        if size > MAX_FILE {
            continue;
        }
        total += size;
        if total > MAX_UNPACKED {
            return Err("the archive unpacks to more than 200 MiB".into());
        }
        let mut content = Vec::with_capacity(size);
        entry.take(MAX_FILE as u64).read_to_end(&mut content).map_err(bad)?;
        files.insert(parts[1..].join("/"), content);
    }
    Ok(files)
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use fl_pi_llm::host::{BoxFuture, FetchResponse};

    use super::*;

    fn tar_gz(entries: &[(&str, &[u8])]) -> Vec<u8> {
        let mut builder = tar::Builder::new(Vec::new());
        for (name, bytes) in entries {
            let mut header = tar::Header::new_gnu();
            header.set_size(bytes.len() as u64);
            header.set_mode(0o644);
            // Written raw: `set_path` refuses `..`, which an archive may have.
            let path = format!("repo-main/{name}");
            header.as_old_mut().name[..path.len()].copy_from_slice(path.as_bytes());
            header.set_cksum();
            builder.append(&header, *bytes).unwrap();
        }
        let mut gz = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast());
        gz.write_all(&builder.into_inner().unwrap()).unwrap();
        gz.finish().unwrap()
    }

    struct Archive(Vec<u8>, std::sync::Mutex<Vec<String>>);

    impl Fetch for Archive {
        fn fetch(&self, req: FetchRequest) -> BoxFuture<'_, Result<FetchResponse, String>> {
            self.1.lock().unwrap().push(req.url);
            let bytes = self.0.clone();
            Box::pin(async move {
                let (tx, rx) = tokio::sync::mpsc::channel(1);
                tx.send(Ok(bytes)).await.unwrap();
                Ok(FetchResponse { status: 200, status_text: "OK".into(), headers: vec![], body: rx })
            })
        }
    }

    #[tokio::test]
    async fn installed_listed_switched_off_and_removed() {
        let db = SqlitePool::connect("sqlite::memory:").await.unwrap();
        sqlx::migrate!("./migrations").run(&db).await.unwrap();
        let dir = tempfile::tempdir().unwrap();
        let root = root(dir.path());
        let md = |n: &str| format!("---\nname: {n}\ndescription: Does {n}.\n---\nbody\n");
        let fetch = Archive(
            tar_gz(&[
                ("skills/docker-cleanup/SKILL.md", md("Docker Cleanup").as_bytes()),
                ("skills/docker-cleanup/run.sh", b"docker system prune"),
                ("skills/logs/SKILL.md", md("Logs").as_bytes()),
            ]),
            Default::default(),
        );

        assert_eq!(install(&db, &root, &fetch, "npx skills add acme/ops --skill logs").await.unwrap(), ["logs"]);
        assert_eq!(fetch.1.lock().unwrap()[0], "https://codeload.github.com/acme/ops/tar.gz/HEAD");
        assert_eq!(install(&db, &root, &fetch, "acme/ops").await.unwrap(), ["docker-cleanup", "logs"]);
        assert_eq!(install(&db, &root, &fetch, "acme/ops@nope").await, Err(InstallError::NoSkill));
        assert!(matches!(install(&db, &root, &fetch, "not a source at all").await, Err(InstallError::Source(_))));

        let listed = list(&db, &root).await.unwrap();
        assert_eq!(listed.iter().map(|s| (s.dir.as_str(), s.files)).collect::<Vec<_>>(), [("docker-cleanup", 2), ("logs", 1)]);
        assert_eq!(listed[0].source.as_deref(), Some("acme/ops"));

        assert!(set_enabled(&db, &root, "logs", false).await.unwrap());
        let offered: Vec<String> = offered(&db, &root).await.into_iter().map(|s| s.dir).collect();
        assert_eq!(offered, ["docker-cleanup"]);
        let (prompt, tool) = for_task(&db, &root).await.unwrap();
        assert!(prompt.contains("- docker-cleanup: Does Docker Cleanup.") && !prompt.contains("logs"));
        assert_eq!(tool.def().name, "skill");

        assert!(remove(&db, &root, "docker-cleanup").await.unwrap());
        assert!(!remove(&db, &root, "docker-cleanup").await.unwrap());
        assert!(for_task(&db, &root).await.is_none(), "the only one left is off");
    }

    #[test]
    fn archives_never_write_outside() {
        let files = unpack(&tar_gz(&[("a/SKILL.md", b"x"), ("../../etc/x", b"y")])).unwrap();
        assert_eq!(files.keys().collect::<Vec<_>>(), ["a/SKILL.md"]);
    }
}
