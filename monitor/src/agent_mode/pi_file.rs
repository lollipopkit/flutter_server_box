//! A task as a session file of pi's coding agent, where `pi` on this machine
//! looks: `pi -r` in the agent's working directory lists the tasks, and can
//! carry one on. A copy: what `pi` does with it never comes back.
//!
//! The directory is pi's: `$PI_CODING_AGENT_SESSION_DIR`, or
//! `${PI_CODING_AGENT_DIR:-~/.pi/agent}/sessions/--<cwd>--/`, the working
//! directory with its leading separator dropped and `/`, `\` and `:` as `-`.

use std::path::{Path, PathBuf};

/// pi's session directory for [cwd], for the account the agent runs as.
fn dir(cwd: &Path) -> Option<PathBuf> {
    dir_with(cwd, |name| std::env::var_os(name))
}

/// [dir] with the environment read through [env].
fn dir_with(cwd: &Path, env: impl Fn(&str) -> Option<std::ffi::OsString>) -> Option<PathBuf> {
    let set = |name: &str| env(name).filter(|v| !v.is_empty()).map(PathBuf::from);
    if let Some(d) = set("PI_CODING_AGENT_SESSION_DIR") {
        return Some(d);
    }
    let agent = set("PI_CODING_AGENT_DIR").or_else(|| set("HOME").or_else(|| set("USERPROFILE")).map(|h| h.join(".pi").join("agent")))?;
    let cwd = cwd.to_string_lossy();
    let safe: String = cwd.strip_prefix(['/', '\\']).unwrap_or(&cwd).chars().map(|c| if matches!(c, '/' | '\\' | ':') { '-' } else { c }).collect();
    Some(agent.join("sessions").join(format!("--{safe}--")))
}

/// A task id is the file name's tail; one that could leave the directory is
/// never written.
fn usable(id: &str) -> bool {
    !id.is_empty() && id.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_'))
}

/// pi names a session `<created, ISO with : and . as ->_<id>.jsonl`.
fn name(created: &str, id: &str) -> String {
    let at = chrono::DateTime::parse_from_rfc3339(created).map(|t| t.with_timezone(&chrono::Utc)).unwrap_or_else(|_| chrono::Utc::now());
    format!("{}_{id}.jsonl", at.format("%Y-%m-%dT%H-%M-%S-%3fZ"))
}

/// Writes (or replaces) task [id]'s file, 0600 in a 0700 directory.
pub async fn write(cwd: &Path, created: &str, id: &str, text: &str) -> std::io::Result<()> {
    if !usable(id) {
        return Ok(());
    }
    let Some(dir) = dir(cwd) else { return Ok(()) };
    let mut b = tokio::fs::DirBuilder::new();
    b.recursive(true);
    #[cfg(unix)]
    b.mode(0o700);
    b.create(&dir).await?;
    let path = dir.join(name(created, id));
    let staged = dir.join(format!(".{id}.sbm-part"));
    let mut o = tokio::fs::OpenOptions::new();
    o.write(true).create(true).truncate(true);
    #[cfg(unix)]
    o.mode(0o600);
    let mut f = o.open(&staged).await?;
    tokio::io::AsyncWriteExt::write_all(&mut f, text.as_bytes()).await?;
    f.sync_all().await?;
    drop(f);
    tokio::fs::rename(&staged, &path).await
}

/// Removes task [id]'s file, if there is one.
pub async fn remove(id: &str) {
    if !usable(id) {
        return;
    }
    let Some(dir) = std::env::current_dir().ok().and_then(|cwd| dir(&cwd)) else { return };
    let Ok(mut files) = tokio::fs::read_dir(&dir).await else { return };
    let tail = format!("_{id}.jsonl");
    while let Ok(Some(f)) = files.next_entry().await {
        if f.file_name().to_string_lossy().ends_with(&tail) {
            let _ = tokio::fs::remove_file(f.path()).await;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn named_as_pi_names_a_session() {
        assert_eq!(name("2026-10-12T13:14:14.726+00:00", "abc"), "2026-10-12T13-14-14-726Z_abc.jsonl");
        assert!(usable("0199-ab_c"));
        assert!(!usable("../x") && !usable("a/b") && !usable(""));
    }

    #[test]
    fn found_where_pi_looks() {
        let env = |vars: &'static [(&'static str, &'static str)]| move |name: &str| vars.iter().find(|(k, _)| *k == name).map(|(_, v)| v.into());
        assert_eq!(
            dir_with(Path::new("/home/u/work"), env(&[("HOME", "/home/u")])),
            Some(PathBuf::from("/home/u/.pi/agent/sessions/--home-u-work--")),
        );
        assert_eq!(
            dir_with(Path::new("/srv"), env(&[("HOME", "/home/u"), ("PI_CODING_AGENT_DIR", "/opt/pi")])),
            Some(PathBuf::from("/opt/pi/sessions/--srv--")),
        );
        assert_eq!(
            dir_with(Path::new("/srv"), env(&[("HOME", "/home/u"), ("PI_CODING_AGENT_SESSION_DIR", "/s")])),
            Some(PathBuf::from("/s")),
        );
        assert_eq!(dir_with(Path::new("/srv"), env(&[])), None);
    }
}
