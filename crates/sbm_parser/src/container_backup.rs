//! Backing up and restoring what containers keep: their volumes and the
//! folders bound into them, each archived from inside a throwaway container
//! (so files the caller's account does not own go too), and put back the
//! same way.
//!
//! The commands are built here, as every other container command
//! (`container`); the agent runs them as a job (`monitor/src/container_backups.rs`).

use serde::{Deserialize, Serialize};

use crate::container::ContainerType;
use crate::script::shell_quote_unix;

/// The image the archives are made and read in.
pub const HELPER_IMAGE: &str = "docker.io/library/alpine:3";

/// Host folders never archived or written back: restoring one would replace
/// the system's own files.
const SYSTEM_DIRS: &[&str] = &[
    "/", "/bin", "/boot", "/dev", "/etc", "/lib", "/lib32", "/lib64", "/libx32", "/proc", "/root", "/run", "/sbin", "/sys",
    "/usr", "/var", "/var/run", "/var/lib", "/var/lib/docker", "/var/lib/containers", "/home", "/tmp",
];

/// One container, as the backup needs it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Inspected {
    pub id: String,
    /// Without the leading `/`.
    pub name: String,
    pub image: String,
    pub project: Option<String>,
    pub running: bool,
    pub mounts: Vec<Mount>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum Mount {
    /// A named volume.
    Volume { name: String, destination: String },
    /// A host folder bound in.
    Bind { source: String, destination: String },
}

impl Mount {
    pub fn destination(&self) -> &str {
        match self {
            Mount::Volume { destination, .. } | Mount::Bind { destination, .. } => destination,
        }
    }

    /// What `-v` mounts it from: the volume's name or the host folder.
    pub fn source(&self) -> &str {
        match self {
            Mount::Volume { name, .. } => name,
            Mount::Bind { source, .. } => source,
        }
    }

    /// Whether this is a system folder of the host, never archived or
    /// written back.
    pub fn is_system(&self) -> bool {
        match self {
            Mount::Bind { source, .. } => {
                let trimmed = source.trim_end_matches('/');
                SYSTEM_DIRS.contains(&if trimmed.is_empty() { "/" } else { trimmed })
            }
            Mount::Volume { .. } => false,
        }
    }
}

/// [ids]' names, images, projects, states and mounts, one line each; read
/// by [`parse_inspect`].
pub fn inspect_command(runtime: ContainerType, ids: &[String]) -> String {
    let mut out = format!(
        "{} inspect --format '{{{{.Id}}}}\t{{{{.Name}}}}\t{{{{.Config.Image}}}}\t{{{{index .Config.Labels \"com.docker.compose.project\"}}}}\t{{{{.State.Running}}}}\t{{{{json .Mounts}}}}'",
        runtime.name()
    );
    for id in ids {
        out.push(' ');
        out.push_str(&shell_quote_unix(id));
    }
    out
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
struct RawMount {
    #[serde(rename = "Type", default)]
    kind: String,
    #[serde(default)]
    name: String,
    #[serde(default)]
    source: String,
    #[serde(default)]
    destination: String,
}

/// Reads [`inspect_command`]'s lines. Mounts other than volumes and binds
/// (tmpfs, named pipes) hold nothing to keep and are left out.
pub fn parse_inspect(stdout: &str) -> Vec<Inspected> {
    stdout
        .lines()
        .filter_map(|line| {
            let mut f = line.splitn(6, '\t');
            let (id, name, image, project, running, mounts) = (f.next()?, f.next()?, f.next()?, f.next()?, f.next()?, f.next()?);
            let raw: Vec<RawMount> = serde_json::from_str(mounts.trim()).ok()?;
            let mounts = raw
                .into_iter()
                .filter_map(|m| match m.kind.as_str() {
                    "volume" if !m.name.is_empty() => Some(Mount::Volume { name: m.name, destination: m.destination }),
                    "bind" if !m.source.is_empty() => Some(Mount::Bind { source: m.source, destination: m.destination }),
                    _ => None,
                })
                .collect();
            Some(Inspected {
                id: id.to_string(),
                name: name.trim_start_matches('/').to_string(),
                image: image.to_string(),
                project: Some(project.to_string()).filter(|p| !p.is_empty() && p != "<no value>"),
                running: running == "true",
                mounts,
            })
        })
        .collect()
}

/// The ids of compose project [project]'s containers, stopped ones included.
pub fn project_command(runtime: ContainerType, project: &str) -> String {
    format!("{} ps -aq --filter {}", runtime.name(), shell_quote_unix(&format!("label=com.docker.compose.project={project}")))
}

/// The ids of the containers named exactly [names], stopped ones included.
pub fn named_command(runtime: ContainerType, names: &[String]) -> String {
    let mut out = format!("{} ps -aq", runtime.name());
    for name in names {
        out.push_str(" --filter ");
        out.push_str(&shell_quote_unix(&format!("name=^/?{}$", name.replace('.', "\\."))));
    }
    out
}

/// Stops (or, with [start], starts) [ids].
pub fn lifecycle_command(runtime: ContainerType, ids: &[String], start: bool) -> String {
    let mut out = format!("{} {}", runtime.name(), if start { "start" } else { "stop" });
    for id in ids {
        out.push(' ');
        out.push_str(&shell_quote_unix(id));
    }
    out
}

/// Archives [mount] into [dir]/[file] (a `.tar.gz`), read only.
pub fn archive_command(runtime: ContainerType, mount: &Mount, dir: &str, file: &str) -> String {
    format!(
        "{} run --rm -v {}:/sbm-src:ro -v {}:/sbm-backup {HELPER_IMAGE} tar czf {} -C /sbm-src .",
        runtime.name(),
        shell_quote_unix(mount.source()),
        shell_quote_unix(dir),
        shell_quote_unix(&format!("/sbm-backup/{file}")),
    )
}

/// Replaces what [mount] holds with [dir]/[file]'s contents.
pub fn restore_command(runtime: ContainerType, mount: &Mount, dir: &str, file: &str) -> String {
    let script = format!("find /sbm-dst -mindepth 1 -delete && tar xzf {} -C /sbm-dst", shell_quote_unix(&format!("/sbm-backup/{file}")));
    format!(
        "{} run --rm -v {}:/sbm-dst -v {}:/sbm-backup:ro {HELPER_IMAGE} sh -c {}",
        runtime.name(),
        shell_quote_unix(mount.source()),
        shell_quote_unix(dir),
        shell_quote_unix(&script),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn inspect_reads_volumes_and_binds() {
        let out = concat!(
            "abc\t/sbm-futo-immich-database-1\tpostgres:14\tsbm-futo-immich\ttrue\t",
            r#"[{"Type":"volume","Name":"pgdata","Source":"/var/lib/docker/volumes/pgdata/_data","Destination":"/var/lib/postgresql/data"},"#,
            r#"{"Type":"bind","Source":"/srv/photos","Destination":"/data"},{"Type":"tmpfs","Destination":"/tmp"}]"#,
            "\n",
            "def\t/plain\tnginx\t<no value>\tfalse\t[]\n",
            "garbage\n",
        );
        let found = parse_inspect(out);
        assert_eq!(found.len(), 2);
        assert_eq!(found[0].name, "sbm-futo-immich-database-1");
        assert_eq!(found[0].project.as_deref(), Some("sbm-futo-immich"));
        assert!(found[0].running);
        assert_eq!(
            found[0].mounts,
            vec![
                Mount::Volume { name: "pgdata".into(), destination: "/var/lib/postgresql/data".into() },
                Mount::Bind { source: "/srv/photos".into(), destination: "/data".into() },
            ]
        );
        assert_eq!(found[1].project, None);
        assert!(!found[1].running);
    }

    #[test]
    fn system_folders_are_never_touched() {
        for source in ["/", "/etc", "/etc/", "/var/run", "/home"] {
            assert!(Mount::Bind { source: source.into(), destination: "/x".into() }.is_system(), "{source}");
        }
        for source in ["/srv/photos", "/home/lk/photos", "/etc/nginx"] {
            assert!(!Mount::Bind { source: source.into(), destination: "/x".into() }.is_system(), "{source}");
        }
        assert!(!Mount::Volume { name: "etc".into(), destination: "/etc".into() }.is_system());
    }

    #[test]
    fn commands_quote_what_they_name() {
        let bind = Mount::Bind { source: "/srv/it's".into(), destination: "/data".into() };
        assert_eq!(
            archive_command(ContainerType::Docker, &bind, "/b/1", "m1.tar.gz"),
            "docker run --rm -v '/srv/it'\\''s':/sbm-src:ro -v '/b/1':/sbm-backup docker.io/library/alpine:3 tar czf '/sbm-backup/m1.tar.gz' -C /sbm-src ."
        );
        assert_eq!(
            restore_command(ContainerType::Podman, &Mount::Volume { name: "pg".into(), destination: "/d".into() }, "/b/1", "m1.tar.gz"),
            "podman run --rm -v 'pg':/sbm-dst -v '/b/1':/sbm-backup:ro docker.io/library/alpine:3 sh -c 'find /sbm-dst -mindepth 1 -delete && tar xzf '\\''/sbm-backup/m1.tar.gz'\\'' -C /sbm-dst'"
        );
        assert_eq!(lifecycle_command(ContainerType::Docker, &["a".into(), "b".into()], false), "docker stop 'a' 'b'");
        assert_eq!(
            project_command(ContainerType::Docker, "sbm-x"),
            "docker ps -aq --filter 'label=com.docker.compose.project=sbm-x'"
        );
        assert!(inspect_command(ContainerType::Docker, &["abc".into()]).ends_with("{{json .Mounts}}' 'abc'"));
    }
}
