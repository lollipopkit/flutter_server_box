//! Docker Compose stacks: the commands that deploy, run and remove one, and
//! the reading of `compose ps`.
//!
//! A stack is a directory holding its compose files and an env file, named
//! by a compose project. The agent deploys the services its catalog lists
//! this way (`monitor/src/stacks`); the commands are built here so the app can
//! read the same stacks over SSH later.
//!
//! Every command changes into the stack's directory first, so the compose
//! files may refer to each other (`extends`) and to the env file by
//! relative paths.

use serde::{Deserialize, Serialize};

use crate::container::ContainerType;
use crate::script::shell_quote_unix;

/// A compose project name: what Compose itself accepts (lowercase letters,
/// digits, `-` and `_`, starting with a letter or digit), at most 63 bytes.
pub fn valid_project(name: &str) -> bool {
    let bytes = name.as_bytes();
    (1..=63).contains(&bytes.len())
        && (bytes[0].is_ascii_lowercase() || bytes[0].is_ascii_digit())
        && bytes.iter().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || *b == b'-' || *b == b'_')
}

/// One stack on disk.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Stack {
    pub runtime: ContainerType,
    /// The compose project, see [`valid_project`].
    pub project: String,
    /// Absolute path of the stack's directory.
    pub dir: String,
    /// Compose files, relative to [dir], in merge order.
    pub files: Vec<String>,
    /// The env file, relative to [dir].
    pub env_file: String,
}

impl Stack {
    /// `cd <dir> && <runtime> compose -p <project> --env-file <env> -f <file>…`.
    fn base(&self) -> String {
        let mut out = format!(
            "cd {} && {} compose -p {} --env-file {}",
            shell_quote_unix(&self.dir),
            self.runtime.name(),
            shell_quote_unix(&self.project),
            shell_quote_unix(&self.env_file),
        );
        for file in &self.files {
            out.push_str(" -f ");
            out.push_str(&shell_quote_unix(file));
        }
        out
    }

    /// Progress as plain lines, one per event, for a log the panel shows.
    /// Docker's Compose only: `podman compose` hands the command to whichever
    /// provider is installed, and not all of them know the flag.
    fn plain(&self) -> &'static str {
        match self.runtime {
            ContainerType::Docker => " --progress plain",
            ContainerType::Podman => "",
        }
    }

    /// Pulls every image the stack names.
    pub fn pull(&self) -> String {
        format!("{}{} pull", self.base(), self.plain())
    }

    /// Creates and starts everything, removing services the files no longer
    /// list. Pulls what is missing.
    pub fn up(&self) -> String {
        format!("{}{} up -d --remove-orphans", self.base(), self.plain())
    }

    pub fn start(&self) -> String {
        format!("{} start", self.base())
    }

    pub fn stop(&self) -> String {
        format!("{}{} stop", self.base(), self.plain())
    }

    pub fn restart(&self) -> String {
        format!("{}{} restart", self.base(), self.plain())
    }

    /// Removes the containers and the stack's network; its named volumes too
    /// when [volumes]. Bind-mounted directories are never touched.
    pub fn down(&self, volumes: bool) -> String {
        let volumes = if volumes { " --volumes" } else { "" };
        format!("{}{} down --remove-orphans{volumes}", self.base(), self.plain())
    }

    /// Every container of the stack, stopped ones included, as JSON (read by
    /// [`parse_ps`]).
    pub fn ps(&self) -> String {
        format!("{} ps --all --format json", self.base())
    }

    /// The last [tail] lines of [service]'s log, or of every service's.
    pub fn logs(&self, service: Option<&str>, tail: u32) -> String {
        let mut out = format!("{} logs --no-color --timestamps --tail {tail}", self.base());
        if let Some(service) = service {
            out.push(' ');
            out.push_str(&shell_quote_unix(service));
        }
        out
    }
}

/// Removes [path] (a directory a stack's containers wrote, often as root)
/// from inside a throwaway container, so files the agent's user does not own
/// go too. The directory's parent is mounted; the directory itself is
/// removed.
pub fn purge_command(runtime: ContainerType, path: &str) -> Option<String> {
    let path = path.trim_end_matches('/');
    let (parent, name) = path.rsplit_once('/')?;
    if !path.starts_with('/') || name.is_empty() || name == "." || name == ".." || path.contains('\n') {
        return None;
    }
    let parent = if parent.is_empty() { "/" } else { parent };
    Some(format!(
        "{} run --rm -v {}:/sbm-purge docker.io/library/alpine:3 rm -rf {}",
        runtime.name(),
        shell_quote_unix(parent),
        shell_quote_unix(&format!("/sbm-purge/{name}")),
    ))
}

/// Asks Docker which OCI runtimes it has (`nvidia` once the NVIDIA Container
/// Toolkit is set up); read by [`parse_runtimes`]. Podman reaches GPUs
/// through CDI specs only, so there is nothing to ask it.
pub fn runtimes_command(runtime: ContainerType) -> Option<String> {
    match runtime {
        ContainerType::Docker => Some("docker info --format '{{json .Runtimes}}'".into()),
        ContainerType::Podman => None,
    }
}

/// The runtime names `docker info --format '{{json .Runtimes}}'` printed.
pub fn parse_runtimes(stdout: &str) -> Vec<String> {
    serde_json::from_str::<serde_json::Map<String, serde_json::Value>>(stdout.trim())
        .map(|m| m.keys().cloned().collect())
        .unwrap_or_default()
}

/// Asks the runtime for its Compose; read by [`parse_version`].
pub fn version_command(runtime: ContainerType) -> String {
    format!("{} compose version --short", runtime.name())
}

/// The version `compose version --short` printed (`5.6.0`, a leading `v`
/// dropped), or `None` when it printed none.
pub fn parse_version(stdout: &str) -> Option<String> {
    let line = stdout.lines().map(str::trim).find(|l| !l.is_empty())?;
    let version = line.strip_prefix('v').unwrap_or(line);
    version.starts_with(|c: char| c.is_ascii_digit()).then(|| version.to_string())
}

/// One container of a stack, as `compose ps` reports it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StackService {
    /// The service's name in the compose file.
    pub service: String,
    /// The container's name.
    pub name: String,
    pub image: String,
    /// `running`, `exited`, `restarting`, `created`, `paused`, `dead`, …
    pub state: String,
    /// `healthy`, `unhealthy`, `starting`; `None` without a health check.
    pub health: Option<String>,
    pub exit_code: Option<i64>,
    /// The runtime's own summary (`Up 2 hours (healthy)`).
    pub status: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
struct RawService {
    #[serde(default)]
    service: String,
    #[serde(default)]
    name: String,
    #[serde(default)]
    image: String,
    #[serde(default)]
    state: String,
    #[serde(default)]
    health: String,
    #[serde(default)]
    exit_code: Option<i64>,
    #[serde(default)]
    status: String,
}

impl From<RawService> for StackService {
    fn from(r: RawService) -> Self {
        Self {
            service: r.service,
            name: r.name,
            image: r.image,
            state: r.state.to_ascii_lowercase(),
            health: Some(r.health.to_ascii_lowercase()).filter(|h| !h.is_empty()),
            exit_code: r.exit_code,
            status: r.status,
        }
    }
}

/// Reads `compose ps --format json`: one object per line from Compose 2.21
/// on, a single array before. Lines that are not JSON (a warning Compose
/// printed to stdout) are skipped.
pub fn parse_ps(raw: &str) -> Vec<StackService> {
    let trimmed = raw.trim();
    if trimmed.starts_with('[') {
        return serde_json::from_str::<Vec<RawService>>(trimmed)
            .map(|v| v.into_iter().map(Into::into).collect())
            .unwrap_or_default();
    }
    trimmed
        .lines()
        .filter_map(|line| serde_json::from_str::<RawService>(line.trim()).ok())
        .map(Into::into)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn stack(runtime: ContainerType) -> Stack {
        Stack {
            runtime,
            project: "sbm-immich".into(),
            dir: "/var/lib/sbm/stacks/it's".into(),
            files: vec!["compose.yaml".into(), "hwaccel.ml.yml".into()],
            env_file: ".env".into(),
        }
    }

    #[test]
    fn project_names() {
        assert!(valid_project("sbm-immich"));
        assert!(valid_project("a_1"));
        assert!(!valid_project(""));
        assert!(!valid_project("-x"));
        assert!(!valid_project("Immich"));
        assert!(!valid_project("a b"));
        assert!(!valid_project(&"a".repeat(64)));
    }

    #[test]
    fn commands_quote_and_change_directory() {
        let s = stack(ContainerType::Docker);
        assert_eq!(
            s.up(),
            "cd '/var/lib/sbm/stacks/it'\\''s' && docker compose -p 'sbm-immich' --env-file '.env' \
             -f 'compose.yaml' -f 'hwaccel.ml.yml' --progress plain up -d --remove-orphans"
        );
        assert!(s.down(true).ends_with("--progress plain down --remove-orphans --volumes"));
        assert!(s.down(false).ends_with("down --remove-orphans"));
        assert!(s.ps().ends_with(" ps --all --format json"));
        assert!(s.logs(Some("immich-server"), 200).ends_with("logs --no-color --timestamps --tail 200 'immich-server'"));
        assert!(s.logs(None, 50).ends_with("--tail 50"));
    }

    #[test]
    fn podman_gets_no_progress_flag() {
        let s = stack(ContainerType::Podman);
        assert!(s.pull().contains("podman compose -p"));
        assert!(!s.pull().contains("--progress"));
        assert_eq!(version_command(ContainerType::Podman), "podman compose version --short");
    }

    #[test]
    fn purge_mounts_the_parent() {
        assert_eq!(
            purge_command(ContainerType::Docker, "/srv/it's/library/").as_deref(),
            Some("docker run --rm -v '/srv/it'\\''s':/sbm-purge docker.io/library/alpine:3 rm -rf '/sbm-purge/library'")
        );
        assert!(purge_command(ContainerType::Docker, "/").is_none());
        assert!(purge_command(ContainerType::Docker, "relative").is_none());
        assert!(purge_command(ContainerType::Docker, "a/b").is_none());
        assert!(purge_command(ContainerType::Docker, "/srv/..").is_none());
    }

    #[test]
    fn runtimes() {
        assert_eq!(parse_runtimes(r#"{"io.containerd.runc.v2":{"path":"runc"},"nvidia":{"path":"nvidia-container-runtime"}}"#),
            vec!["io.containerd.runc.v2".to_string(), "nvidia".to_string()]);
        assert!(parse_runtimes("not json").is_empty());
        assert!(runtimes_command(ContainerType::Podman).is_none());
    }

    #[test]
    fn versions() {
        assert_eq!(parse_version("5.6.0\n").as_deref(), Some("5.6.0"));
        assert_eq!(parse_version("v2.29.7").as_deref(), Some("2.29.7"));
        assert_eq!(parse_version("\n"), None);
        assert_eq!(parse_version("docker: 'compose' is not a docker command."), None);
    }

    #[test]
    fn ps_lines_and_arrays() {
        let lines = r#"{"Name":"sbm-immich-immich-server-1","Service":"immich-server","Image":"ghcr.io/immich-app/immich-server:v3.3.1","State":"running","Health":"healthy","ExitCode":0,"Status":"Up 2 hours (healthy)"}
WARN[0000] something
{"Name":"sbm-immich-redis-1","Service":"redis","Image":"valkey","State":"exited","Health":"","ExitCode":137,"Status":"Exited (137)"}"#;
        let parsed = parse_ps(lines);
        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed[0].service, "immich-server");
        assert_eq!(parsed[0].health.as_deref(), Some("healthy"));
        assert_eq!(parsed[1].health, None);
        assert_eq!(parsed[1].exit_code, Some(137));

        let array = r#"[{"Name":"a","Service":"db","Image":"pg","State":"Running","Health":"","ExitCode":0,"Status":"Up"}]"#;
        let parsed = parse_ps(array);
        assert_eq!(parsed.len(), 1);
        assert_eq!(parsed[0].state, "running");
        assert!(parse_ps("").is_empty());
    }
}
