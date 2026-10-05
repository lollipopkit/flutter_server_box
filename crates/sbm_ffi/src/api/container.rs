//! Containers FFI (sbm_parser::container)
//!
//! Docker and Podman by the rules the monitor agent's panel uses: every
//! command line the app sends a runtime, and the parsers for what the runtime
//! printed. The app runs the commands over its own connection and keeps the
//! refresh's state, its sudo handling and the wording a row is drawn in.
//!
//! A runtime crosses as its name (`docker`, `podman`), a container's state as
//! `sbm_parser::container::ContainerStatus`'s (`running`, `exited`, ...).
//! Every command returned is a whole line, the runtime's name included.

use sbm_parser::container::{
    self, Container, ContainerAction, ContainerCmd, ContainerImage, ContainerStats, ContainerStatus, ContainerType,
};

fn runtime(name: &str) -> Result<ContainerType, String> {
    serde_json::from_value(serde_json::Value::String(name.to_owned())).map_err(|_| format!("unknown runtime: {name}"))
}

fn status_name(status: ContainerStatus) -> String {
    serde_json::to_value(status)
        .ok()
        .and_then(|v| v.as_str().map(str::to_owned))
        .unwrap_or_else(|| "unknown".to_owned())
}

fn status(name: &str) -> Result<ContainerStatus, String> {
    serde_json::from_value(serde_json::Value::String(name.to_owned())).map_err(|_| format!("unknown status: {name}"))
}

/// One container, with its stats when the refresh asked for them and the
/// runtime reported a row for it.
pub struct ContainerItem {
    pub id: Option<String>,
    pub name: Option<String>,
    pub image: Option<String>,
    pub project: Option<String>,
    pub working_dir: Option<String>,
    /// Published ports condensed to `host→container`.
    pub ports: Option<String>,
    pub raw_status: Option<String>,
    pub status: String,
    pub stats: Option<ContainerStatsItem>,
}

/// The runtime's own renderings, split so the app can word the row.
pub struct ContainerStatsItem {
    pub cpu: Option<String>,
    /// Podman's average over the sample window; Docker reports none.
    pub cpu_avg: Option<String>,
    pub mem: Option<String>,
    pub net_down: Option<String>,
    pub net_up: Option<String>,
    pub disk_read: Option<String>,
    pub disk_write: Option<String>,
}

pub struct ContainerImageItem {
    pub repository: String,
    pub tag: Option<String>,
    pub id: Option<String>,
    pub digest: Option<String>,
    pub size: Option<String>,
    /// `None` is unknown, never zero.
    pub containers: Option<i64>,
    /// Docker's creation text, passed through.
    pub created_at: Option<String>,
    /// Podman's creation time in Unix seconds.
    pub created: Option<i64>,
    /// `<none>:<none>`: nothing to lose by removing it.
    pub dangling: bool,
    /// Dangling, or known to have no container referencing it.
    pub unused: bool,
}

pub struct ContainerDiskUsageItem {
    pub image_count: Option<i64>,
    pub reclaimable_bytes: Option<i64>,
}

fn item(container: Container, stats: Option<ContainerStats>) -> ContainerItem {
    ContainerItem {
        status: status_name(container.status),
        id: container.id,
        name: container.name,
        image: container.image,
        project: container.project,
        working_dir: container.working_dir,
        ports: container.ports,
        raw_status: container.raw_status,
        stats: stats.map(|s| ContainerStatsItem {
            cpu: s.cpu,
            cpu_avg: s.cpu_avg,
            mem: s.mem,
            net_down: s.net_down,
            net_up: s.net_up,
            disk_read: s.disk_read,
            disk_write: s.disk_write,
        }),
    }
}

fn image_item(image: ContainerImage) -> ContainerImageItem {
    ContainerImageItem {
        dangling: image.is_dangling(),
        unused: image.is_unused(),
        repository: image.repository,
        tag: image.tag,
        id: image.id,
        digest: image.digest,
        size: image.size,
        containers: image.containers,
        created_at: image.created_at,
        created: image.created,
    }
}

fn image_back(image: ContainerImageItem) -> ContainerImage {
    ContainerImage {
        repository: image.repository,
        tag: image.tag,
        id: image.id,
        digest: image.digest,
        size: image.size,
        containers: image.containers,
        created_at: image.created_at,
        created: image.created,
    }
}

fn command_kind(name: &str) -> Result<ContainerCmd, String> {
    Ok(match name {
        "version" => ContainerCmd::Version,
        "ps" => ContainerCmd::Ps,
        "stats" => ContainerCmd::Stats,
        "images" => ContainerCmd::Images,
        "df" => ContainerCmd::Df,
        other => return Err(format!("unknown command: {other}")),
    })
}

/// The prefix of the marker echoed between batched commands.
#[flutter_rust_bridge::frb(sync)]
pub fn container_separator_prefix() -> String {
    container::SEPARATOR_PREFIX.to_owned()
}

/// `version`, `ps`, `stats`, `images` or `df` as one `sh -c`, their outputs
/// told apart by `separator` — which carries the caller's freshness marker.
#[flutter_rust_bridge::frb(sync)]
pub fn container_batch_command(runtime_name: String, kinds: Vec<String>, separator: String) -> Result<String, String> {
    let ty = runtime(&runtime_name)?;
    let cmds = kinds.iter().map(|k| command_kind(k)).collect::<Result<Vec<_>, _>>()?;
    Ok(ContainerCmd::exec_selected(&cmds, ty, &separator))
}

/// One command (`version`, `ps`, ...) on its own.
#[flutter_rust_bridge::frb(sync)]
pub fn container_command(runtime_name: String, kind: String) -> Result<String, String> {
    Ok(command_kind(&kind)?.exec(runtime(&runtime_name)?))
}

/// `command` with the runtime's environment, under `sudo -S` when asked. No
/// password travels in it: `sudo -S` reads one from stdin.
#[flutter_rust_bridge::frb(sync)]
pub fn container_runtime_command(command: String, runtime_name: String, container_host: Option<String>, sudo: bool) -> Result<String, String> {
    Ok(container::build_runtime_command(&command, runtime(&runtime_name)?, container_host.as_deref(), sudo))
}

/// `start`, `stop`, `restart` or `remove` (with `id`), `prune_containers` or
/// `prune_volumes`.
#[flutter_rust_bridge::frb(sync)]
pub fn container_action_command(runtime_name: String, action: String, id: Option<String>, force: bool) -> Result<String, String> {
    let ty = runtime(&runtime_name)?;
    let id = || id.clone().ok_or_else(|| format!("{action} needs a container"));
    let action = match action.as_str() {
        "start" => ContainerAction::Start { id: id()? },
        "stop" => ContainerAction::Stop { id: id()? },
        "restart" => ContainerAction::Restart { id: id()? },
        "remove" => ContainerAction::Remove { id: id()?, force },
        "prune_containers" => ContainerAction::PruneContainers,
        "prune_volumes" => ContainerAction::PruneVolumes,
        other => return Err(format!("unknown action: {other}")),
    };
    Ok(action.exec(ty))
}

#[flutter_rust_bridge::frb(sync)]
pub fn container_image_prune_command(runtime_name: String, all_unused: bool) -> Result<String, String> {
    Ok(format!("{} {}", runtime(&runtime_name)?.name(), container::build_image_prune_cmd(all_unused)))
}

#[flutter_rust_bridge::frb(sync)]
pub fn container_system_prune_command(runtime_name: String, all_unused_images: bool, include_volumes: bool) -> Result<String, String> {
    Ok(format!(
        "{} {}",
        runtime(&runtime_name)?.name(),
        container::build_system_prune_cmd(all_unused_images, include_volumes)
    ))
}

#[flutter_rust_bridge::frb(sync)]
pub fn container_image_remove_command(runtime_name: String, id: String) -> Result<String, String> {
    Ok(container::image_remove_command(runtime(&runtime_name)?, &id))
}

#[flutter_rust_bridge::frb(sync)]
pub fn container_image_pull_command(runtime_name: String, reference: String) -> Result<String, String> {
    Ok(container::image_pull_command(runtime(&runtime_name)?, &reference))
}

/// `run -itd`, every user-typed part quoted. `extra_args` is
/// [`container_parse_run_args`]'s answer.
#[flutter_rust_bridge::frb(sync)]
pub fn container_run_command(runtime_name: String, image: String, name: String, extra_args: Vec<String>) -> Result<String, String> {
    Ok(format!("{} {}", runtime(&runtime_name)?.name(), container::build_run_cmd(&image, &name, &extra_args)))
}

/// What a user typed as `docker run` arguments, split the way a shell would
/// without evaluating anything. `Err` for an unterminated quote.
#[flutter_rust_bridge::frb(sync)]
pub fn container_parse_run_args(raw: String) -> Result<Vec<String>, String> {
    container::parse_run_args(&raw).map_err(|e| e.to_string())
}

/// Follow a container's log in a terminal.
#[flutter_rust_bridge::frb(sync)]
pub fn container_logs_command(runtime_name: String, id: String) -> Result<String, String> {
    Ok(container::logs_command(runtime(&runtime_name)?, &id))
}

/// A shell inside a container, the best one it has.
#[flutter_rust_bridge::frb(sync)]
pub fn container_shell_command(runtime_name: String, id: String) -> Result<String, String> {
    Ok(container::shell_command(runtime(&runtime_name)?, &id))
}

/// The actions a container in `status` is offered: `start`, `stop`,
/// `restart`, `remove`, `logs`, `terminal`.
#[flutter_rust_bridge::frb(sync)]
pub fn container_menu_items(status_name: String) -> Result<Vec<String>, String> {
    Ok(container::menu_items(status(&status_name)?)
        .into_iter()
        .filter_map(|kind| serde_json::to_value(kind).ok().and_then(|v| v.as_str().map(str::to_owned)))
        .collect())
}

/// Whether the shell said the runtime is not installed.
#[flutter_rust_bridge::frb(sync)]
pub fn container_is_not_installed(runtime_name: String, stdout: String, stderr: String, exit_code: i32) -> Result<bool, String> {
    Ok(container::is_not_installed(runtime(&runtime_name)?, &stdout, &stderr, exit_code))
}

/// Whether the `docker` that answered is a `podman` wearing its name.
#[flutter_rust_bridge::frb(sync)]
pub fn container_is_podman_emulation(stderr: String) -> bool {
    container::is_podman_emulation(&stderr)
}

/// What the machine said, stderr first, without the batch's markers and
/// with repeated lines collapsed.
#[flutter_rust_bridge::frb(sync)]
pub fn container_user_facing_output(stderr: String, stdout: String) -> Option<String> {
    container::user_facing_output(&stderr, &stdout)
}

/// The client's version from `version`'s output.
#[flutter_rust_bridge::frb(sync)]
pub fn container_parse_version(raw: String) -> Option<String> {
    container::parse_version(&raw)
}

/// `ps`, and `stats` when it was asked for: each container with its row's
/// stats. Rows that do not parse are skipped.
pub fn container_parse_ps(runtime_name: String, ps: String, stats: Option<String>, version: Option<String>) -> Result<Vec<ContainerItem>, String> {
    let ty = runtime(&runtime_name)?;
    let containers = match ty {
        ContainerType::Docker => container::parse_docker_ps(&ps),
        ContainerType::Podman => container::parse_podman_ps(&ps),
    };
    let rows = stats.as_deref().map(container::parse_stats_rows).unwrap_or_default();
    Ok(containers
        .into_iter()
        .map(|c| {
            let stats = container::find_stats_row(&rows, c.id.as_deref())
                .and_then(|raw| container::parse_stats(ty, raw, version.as_deref()));
            item(c, stats)
        })
        .collect())
}

pub fn container_parse_images(runtime_name: String, raw: String) -> Result<Vec<ContainerImageItem>, String> {
    Ok(container::parse_images(&raw, runtime(&runtime_name)?).into_iter().map(image_item).collect())
}

#[flutter_rust_bridge::frb(sync)]
pub fn container_parse_disk_usage(raw: String) -> Option<ContainerDiskUsageItem> {
    container::parse_disk_usage(&raw).map(|u| ContainerDiskUsageItem {
        image_count: u.image_count,
        reclaimable_bytes: u.reclaimable_bytes,
    })
}

/// The tagged images known to have nothing referencing them, matched against
/// the containers' image references; `None` when one's use is unknown.
#[flutter_rust_bridge::frb(sync)]
pub fn container_count_unused_tagged_images(images: Vec<ContainerImageItem>, container_images: Vec<String>) -> Option<i64> {
    let images: Vec<ContainerImage> = images.into_iter().map(image_back).collect();
    container::count_unused_tagged_images(&images, &container_images)
}
