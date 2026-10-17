use crate::{
    api::authz::{self, Reader},
    api::cors::Cors,
    api::ws::{
        self,
        audit::{self, Action, Event, Kind, Outcome},
        terminal::{start_reaper, terminal_ws},
        ticket::{Purpose, TicketRequest, TicketResponse},
    },
    monitoring,
    utils::error::{MonitorError, Result},
};
use ntex::http::header::RETRY_AFTER;
use ntex::web::{self, App, HttpRequest, HttpResponse, HttpServer, middleware::Logger};
use ntex_files::Files;
use sbm_parser::{SystemType, capabilities::Capabilities};
use serde::Serialize;
use std::sync::Arc;
use std::time::Duration;
use tracing::info;

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

/// Require a panel JWT issued since the password was last set — see
/// `api::authz`.
macro_rules! require_jwt {
    ($req:expr, $app_state:expr) => {{
        match authz::jwt_caller($req, $app_state).await {
            Ok(caller) => caller,
            Err(response) => return Ok(response),
        }
    }};
}

/// Require a panel JWT over a link that may act — see
/// `authz::acting_caller`.
macro_rules! require_acting {
    ($req:expr, $app_state:expr) => {{
        match authz::acting_caller($req, $app_state).await {
            Ok(caller) => caller,
            Err(response) => return Ok(response),
        }
    }};
}

/// Require either a panel JWT or a watch token with the `read` scope.
macro_rules! require_read_access {
    ($req:expr, $app_state:expr) => {{
        match authz::read_caller($req, $app_state).await {
            Ok(reader) => reader,
            Err(response) => return Ok(response),
        }
    }};
}

/// Every `/api/v1` route, in one place both the real server and the tests
/// mount.
///
/// Extracted because the auth gate an endpoint gets is a property of *this*
/// table, not of the handler: [`require_read_access`] accepts a watch token
/// and [`require_jwt`] does not, and which one a route ends up behind is
/// decided here. A test that hand-built its own scope could assert whatever it
/// liked about a handler and still say nothing about what the shipped binary
/// exposes — see `tests/watch_token_scope.rs`, whose whole subject is this
/// table.
///
/// [`exec_max_request`] is `remote_access.exec.max_request_bytes` as resolved
/// at startup. It arrives as an argument rather than being read from
/// `AppState`: ntex applies a payload limit while extracting the body, before
/// any handler — and therefore before any state — is reached.
pub fn configure_api(exec_max_request: usize) -> impl FnOnce(&mut web::ServiceConfig) {
    move |cfg: &mut web::ServiceConfig| configure_api_inner(cfg, exec_max_request)
}

fn configure_api_inner(cfg: &mut web::ServiceConfig, exec_max_request: usize) {
    cfg.service(
        web::scope("/api/v1")
            .middleware(crate::api::unread_body::CloseUnreadBody)
            .route("/login", web::post().to(login))
            .service(
                web::resource("/watch-token")
                    .route(web::post().to(issue_watch_token))
                    .route(web::delete().to(revoke_watch_token)),
            )
            .route("/status", web::get().to(get_status))
            .route("/metrics", web::get().to(get_metrics))
            .route("/capabilities", web::get().to(get_capabilities))
            .route("/ws-ticket", web::post().to(issue_ws_ticket))
            .route("/terminal/ws", web::get().to(terminal_ws))
            .route("/stream/ws", web::get().to(crate::api::ws::stream::stream_ws))
            .route("/rdp/ws", web::get().to(crate::api::ws::rdcleanpath::rdp_ws))
            .route("/listen/ws", web::get().to(ws::listen::listen_ws))
            .route("/virt/console/ws", web::get().to(ws::virt_console::virt_console_ws))
            .service(
                // Its own payload limit: ntex allows 32 KiB by
                // default, and this endpoint's `stdin` carries the
                // generated status script — 5 KiB today, but it grows
                // with every custom command a user adds, and going
                // over would answer 413 with nothing to explain it.
                // Configurable, because what a caller legitimately sends
                // here is not something this file can know — see
                // `remote_access::ExecConfig`.
                web::resource("/exec")
                    .state(web::types::JsonConfig::default().limit(exec_max_request))
                    .route(web::post().to(crate::api::exec::exec)),
            )
            .service(web::resource("/power").route(web::post().to(crate::api::power::power)))
            .service(
                web::resource("/process")
                    .route(web::get().to(crate::api::process::list))
                    .route(web::post().to(crate::api::process::kill)),
            )
            .service(
                web::resource("/services")
                    .route(web::get().to(crate::api::service::list))
                    .route(web::post().to(crate::api::service::act)),
            )
            .service(
                web::resource("/cron")
                    .route(web::get().to(crate::api::cron::list))
                    .route(web::put().to(crate::api::cron::edit)),
            )
            .service(
                web::resource("/containers")
                    .route(web::get().to(crate::api::containers::list))
                    .route(web::post().to(crate::api::containers::act)),
            )
            .service(web::resource("/tmux").route(web::get().to(crate::api::tmux::list)))
            .service(
                web::resource("/benchmark")
                    .route(web::get().to(crate::api::benchmark::get))
                    .route(web::post().to(crate::api::benchmark::act))
                    .route(web::delete().to(crate::api::benchmark::remove)),
            )
            .service(web::resource("/firewall").route(web::post().to(crate::api::firewall::read)))
            .service(web::resource("/firewall/plan").route(web::post().to(crate::api::firewall::plan)))
            .service(web::resource("/firewall/act").route(web::post().to(crate::api::firewall::act)))
            .service(
                web::resource("/system-users")
                    .route(web::get().to(crate::api::system_users::list))
                    .route(web::post().to(crate::api::system_users::act)),
            )
            .service(
                // Its own payload limit, like `/custom-cmds`: a write is
                // the whole library at once.
                web::resource("/snippets")
                    .state(
                        web::types::JsonConfig::default()
                            .limit(crate::api::snippets::MAX_REQUEST),
                    )
                    .route(web::get().to(crate::api::snippets::list))
                    .route(web::put().to(crate::api::snippets::replace)),
            )
            .service(
                web::resource("/bmc")
                    .route(web::get().to(crate::api::bmc::list))
                    .route(web::put().to(crate::api::bmc::replace)),
            )
            .service(web::resource("/bmc/probe").route(web::post().to(crate::api::bmc::probe)))
            .service(web::resource("/virt").route(web::post().to(crate::api::virt::load)))
            .service(web::resource("/virt/power").route(web::post().to(crate::api::virt::power)))
            .service(web::resource("/virt/detail").route(web::post().to(crate::api::virt::detail)))
            .service(web::resource("/virt/history").route(web::post().to(crate::api::virt::history)))
            .service(web::resource("/virt/console").route(web::post().to(crate::api::virt::console)))
            .service(web::resource("/virt/snapshots").route(web::post().to(crate::api::virt::snapshots)))
            .service(web::resource("/virt/snapshot").route(web::post().to(crate::api::virt::snapshot)))
            .service(web::resource("/virt/snapshot/diff").route(web::post().to(crate::api::virt::snapshot_diff)))
            .service(web::resource("/virt/storage").route(web::post().to(crate::api::virt_resources::storage)))
            .service(web::resource("/virt/volumes").route(web::post().to(crate::api::virt_resources::volumes)))
            .service(web::resource("/virt/networks").route(web::post().to(crate::api::virt_resources::networks)))
            .service(web::resource("/virt/manage").route(web::post().to(crate::api::virt_resources::manage)))
            .service(web::resource("/virt/create/form").route(web::post().to(crate::api::virt_guests::create_form)))
            .service(web::resource("/virt/create").route(web::post().to(crate::api::virt_guests::create)))
            .service(web::resource("/virt/delete").route(web::post().to(crate::api::virt_guests::delete)))
            .service(web::resource("/virt/clone/form").route(web::post().to(crate::api::virt_guests::clone_form)))
            .service(web::resource("/virt/clone").route(web::post().to(crate::api::virt_guests::clone)))
            .service(web::resource("/virt/template").route(web::post().to(crate::api::virt_guests::template)))
            .service(web::resource("/virt/hardware").route(web::post().to(crate::api::virt_hardware::hardware)))
            .service(web::resource("/virt/hardware/change").route(web::post().to(crate::api::virt_hardware::change)))
            .service(web::resource("/virt/hardware/revert").route(web::post().to(crate::api::virt_hardware::revert)))
            .service(web::resource("/virt/cloud-init").route(web::post().to(crate::api::virt_hardware::cloud_init)))
            .service(web::resource("/virt/cloud-init/set").route(web::post().to(crate::api::virt_hardware::set_cloud_init)))
            .service(web::resource("/virt/host-devices").route(web::post().to(crate::api::virt_hardware::host_devices)))
            .service(web::resource("/virt/backups").route(web::post().to(crate::api::virt_backups::backups)))
            .service(web::resource("/virt/backup").route(web::post().to(crate::api::virt_backups::backup)))
            .service(web::resource("/virt/backup/restore").route(web::post().to(crate::api::virt_backups::restore)))
            .service(web::resource("/virt/backup/edit").route(web::post().to(crate::api::virt_backups::edit)))
            .service(web::resource("/virt/backup/delete").route(web::post().to(crate::api::virt_backups::delete)))
            .service(web::resource("/virt/backup-jobs").route(web::post().to(crate::api::virt_backups::jobs)))
            .service(web::resource("/virt/backup-jobs/edit").route(web::post().to(crate::api::virt_backups::edit_job)))
            .service(web::resource("/virt/backup-jobs/run").route(web::post().to(crate::api::virt_backups::run_job)))
            .service(web::resource("/virt/backup-jobs/schedule").route(web::post().to(crate::api::virt_backups::schedule)))
            .service(
                web::resource("/virt/pve")
                    .route(web::get().to(crate::api::virt::pve_get))
                    .route(web::put().to(crate::api::virt::pve_put))
                    .route(web::delete().to(crate::api::virt::pve_delete)),
            )
            .service(web::resource("/virt/pve/cert").route(web::post().to(crate::api::virt::pve_cert)))
            .service(web::resource("/virt/pve/tfa").route(web::post().to(crate::api::virt::pve_tfa)))
            .service(web::resource("/bmc/{id}").route(web::get().to(crate::api::bmc::status)))
            .service(
                web::resource("/bmc/{id}/power").route(web::post().to(crate::api::bmc::power)),
            )
            .service(
                web::resource("/backup").route(web::get().to(crate::api::backup::list)),
            )
            .service(
                web::resource("/backup/blob")
                    .route(web::get().to(crate::api::backup::download))
                    .route(web::put().to(crate::api::backup::upload))
                    .route(web::delete().to(crate::api::backup::remove)),
            )
            .service(
                web::resource("/desktops")
                    .route(web::get().to(crate::api::desktops::list))
                    .route(web::put().to(crate::api::desktops::replace)),
            )
            .service(web::resource("/desk").route(web::get().to(crate::api::desk::get)))
            .service(
                web::resource("/desk/preferences")
                    .state(web::types::JsonConfig::default().limit(crate::api::desk::MAX_REQUEST))
                    .route(web::put().to(crate::api::desk::put_preferences)),
            )
            .service(
                web::resource("/desk/onboarding")
                    .route(web::put().to(crate::api::desk::put_onboarding))
                    .route(web::delete().to(crate::api::desk::delete_onboarding)),
            )
            .service(
                // A streamed body, read whole and bounded in the handler.
                web::resource("/desk/wallpaper")
                    .route(web::get().to(crate::api::desk::get_wallpaper))
                    .route(web::put().to(crate::api::desk::put_wallpaper))
                    .route(web::delete().to(crate::api::desk::delete_wallpaper)),
            )
            .service(
                web::resource("/desk/session")
                    .state(web::types::JsonConfig::default().limit(crate::api::desk::MAX_REQUEST))
                    .route(web::get().to(crate::api::desk::get_session))
                    .route(web::put().to(crate::api::desk::put_session)),
            )
            .service(
                web::resource("/desk/themes")
                    .route(web::get().to(crate::api::desk_themes::list))
                    .route(web::post().to(crate::api::desk_themes::upload)),
            )
            .service(
                web::resource("/desk/themes/store")
                    .route(web::get().to(crate::api::desk_themes::store)),
            )
            .service(
                web::resource("/desk/themes/store/install")
                    .route(web::post().to(crate::api::desk_themes::store_install)),
            )
            .service(web::resource("/desk/themes/{installation}").route(web::delete().to(crate::api::desk_themes::remove)))
            .service(
                web::resource("/desk/themes/{installation}/background")
                    .route(web::get().to(crate::api::desk_themes::background)),
            )
            .service(web::resource("/desk/notifications").route(web::get().to(crate::api::desk::notifications)))
            .route("/alerts", web::get().to(crate::api::desk::alerts))
            .route("/update", web::get().to(crate::api::update::get))
            .route("/update/run", web::post().to(crate::api::update::start))
            .route("/audit", web::get().to(crate::api::audit_log::list))
            .route("/live", web::get().to(crate::api::live::list))
            .route("/live/sessions/{id}", web::delete().to(crate::api::live::end_session))
            .route("/live/connections/{id}", web::delete().to(crate::api::live::end_connection))
            .route("/live/devices/{id}", web::delete().to(crate::api::live::forget_device))
            .service(web::resource("/desk/notifications/read").route(web::post().to(crate::api::desk::mark_read)))
            .service(web::resource("/desk/events").route(web::get().to(crate::api::desk::events)))
            .service(
                web::resource("/agent/flows")
                    .state(web::types::JsonConfig::default().limit(crate::api::agent::MAX_REQUEST))
                    .route(web::get().to(crate::api::agent::list))
                    .route(web::post().to(crate::api::agent::start)),
            )
            .service(
                web::resource("/agent/flows/{id}")
                    .route(web::get().to(crate::api::agent::detail))
                    .route(web::delete().to(crate::api::agent::remove)),
            )
            .service(
                web::resource("/agent/flows/{id}/reply")
                    .state(web::types::JsonConfig::default().limit(crate::api::agent::MAX_REQUEST))
                    .route(web::post().to(crate::api::agent::reply)),
            )
            .service(web::resource("/agent/flows/{id}/answer").route(web::post().to(crate::api::agent::answer)))
            .service(web::resource("/agent/flows/{id}/stop").route(web::post().to(crate::api::agent::stop)))
            .service(web::resource("/agent/events").route(web::get().to(crate::api::agent::events)))
            .service(
                web::resource("/agent/settings")
                    .route(web::get().to(crate::api::agent::get_settings))
                    .route(web::put().to(crate::api::agent::put_settings)),
            )
            .service(web::resource("/agent/choices").route(web::get().to(crate::api::agent::choices)))
            .service(
                web::resource("/agent/mcp")
                    .route(web::get().to(crate::api::agent::get_mcp))
                    .route(web::put().to(crate::api::agent::put_mcp)),
            )
            .service(web::resource("/agent/mcp/apps/{stack}/{index}").route(web::put().to(crate::api::agent::put_mcp_app)))
            .service(web::resource("/agent/mcp/oauth/start").route(web::post().to(crate::api::agent::mcp_oauth_start)))
            .service(web::resource("/agent/mcp/oauth/callback").route(web::get().to(crate::api::agent::mcp_oauth_callback)))
            .service(web::resource("/agent/mcp/oauth").route(web::delete().to(crate::api::agent::mcp_oauth_forget)))
            .service(
                web::resource("/agent/skills")
                    .route(web::get().to(crate::api::agent::get_skills))
                    .route(web::post().to(crate::api::agent::install_skill)),
            )
            .service(
                web::resource("/agent/skills/{dir}")
                    .route(web::put().to(crate::api::agent::put_skill))
                    .route(web::delete().to(crate::api::agent::delete_skill)),
            )
            .service(web::resource("/agent/models").route(web::get().to(crate::api::agent::models)))
            .service(web::resource("/agent/models/probe").route(web::post().to(crate::api::agent::probe)))
            .service(
                web::resource("/agent/permissions")
                    .route(web::get().to(crate::api::agent::get_permissions))
                    .route(web::put().to(crate::api::agent::put_permissions)),
            )
            .service(web::resource("/agent/search").route(web::post().to(crate::api::agent::search)))
            .service(web::resource("/agent/search/{id}/task").route(web::post().to(crate::api::agent::adopt_search)))
            .service(
                web::resource("/agent/files")
                    .state(web::types::PayloadConfig::new(crate::agent_mode::files::MAX_BYTES))
                    .route(web::post().to(crate::api::agent::upload)),
            )
            .service(web::resource("/agent/files/{id}").route(web::delete().to(crate::api::agent::discard)))
            .service(web::resource("/agent/memory").route(web::get().to(crate::api::agent::memory_list)))
            .service(
                web::resource("/agent/memory/file")
                    .state(web::types::JsonConfig::default().limit(crate::api::agent::MAX_MEMORY_REQUEST))
                    .route(web::get().to(crate::api::agent::memory_get))
                    .route(web::put().to(crate::api::agent::memory_put))
                    .route(web::delete().to(crate::api::agent::memory_delete)),
            )
            .service(
                web::resource("/apps")
                    .state(web::types::PayloadConfig::new(crate::api::apps::MAX_PACKAGE_BYTES))
                    .route(web::get().to(crate::api::apps::list))
                    .route(web::post().to(crate::api::apps::install)),
            )
            .service(web::resource("/apps/sudo").route(web::get().to(crate::api::app_backend::sudo)))
            .service(web::resource("/apps/{id}").route(web::delete().to(crate::api::apps::remove)))
            .service(web::resource("/apps/{id}/approval").route(web::put().to(crate::api::apps::approve)))
            .service(web::resource("/apps/{id}/launch").route(web::get().to(crate::api::apps::launch)))
            .service(
                web::resource("/apps/{id}/call")
                    .state(web::types::JsonConfig::default().limit(crate::api::app_backend::MAX_REQUEST))
                    .route(web::post().to(crate::api::app_backend::call)),
            )
            .service(
                web::resource("/apps/{id}/jobs")
                    .state(web::types::JsonConfig::default().limit(crate::api::app_backend::MAX_REQUEST))
                    .route(web::get().to(crate::api::app_backend::job))
                    .route(web::post().to(crate::api::app_backend::start_job)),
            )
            .service(web::resource("/apps/{id}/jobs/cancel").route(web::post().to(crate::api::app_backend::cancel_job)))
            .service(web::resource("/apps/{id}/ui/{ticket}/{path}*").route(web::get().to(crate::api::apps::ui)))
            .service(web::resource("/storage").route(web::get().to(crate::api::storage::view)))
            .service(web::resource("/storage/health").route(web::post().to(crate::api::storage::health)))
            .service(web::resource("/storage/maintenance").route(web::put().to(crate::api::storage::set_maintenance)))
            .service(web::resource("/storage/maintenance/{task}/run").route(web::post().to(crate::api::storage::run_maintenance)))
            .service(web::resource("/storage/act").route(web::post().to(crate::api::storage::act)))
            .service(web::resource("/shares").route(web::get().to(crate::api::shares::view)))
            .service(web::resource("/shares/smb").route(web::put().to(crate::api::shares::set_smb)))
            .service(web::resource("/shares/nfs").route(web::put().to(crate::api::shares::set_nfs)))
            .service(web::resource("/shares/smb/password").route(web::post().to(crate::api::shares::smb_password)))
            .service(web::resource("/shares/connections").route(web::post().to(crate::api::shares::connections)))
            .service(web::resource("/shares/install").route(web::post().to(crate::api::shares::install)))
            .service(web::resource("/shares/job").route(web::get().to(crate::api::shares::job)))
            .service(web::resource("/storage/job").route(web::get().to(crate::api::storage::job)))
            .service(
                web::resource("/container-backups")
                    .route(web::get().to(crate::api::container_backups::list))
                    .route(web::post().to(crate::api::container_backups::create)),
            )
            .service(web::resource("/container-backups/job").route(web::get().to(crate::api::container_backups::job)))
            .service(web::resource("/container-backups/destinations").route(web::get().to(crate::api::container_backups::destinations)))
            .service(web::resource("/container-backups/settings").route(web::put().to(crate::api::container_backups::put_settings)))
            .service(web::resource("/container-backups/schedules").route(web::post().to(crate::api::container_backups::add_schedule)))
            .service(web::resource("/container-backups/schedules/{id}").route(web::delete().to(crate::api::container_backups::remove_schedule)))
            .service(web::resource("/container-backups/job/cancel").route(web::post().to(crate::api::container_backups::cancel)))
            .service(web::resource("/container-backups/{id}/restore").route(web::post().to(crate::api::container_backups::restore)))
            .service(web::resource("/container-backups/{id}").route(web::delete().to(crate::api::container_backups::remove)))
            .service(web::resource("/stacks").route(web::get().to(crate::api::stacks::list)))
            .service(web::resource("/stacks/refresh").route(web::post().to(crate::api::stacks::refresh)))
            .service(
                web::resource("/stacks/{id}")
                    .route(web::post().to(crate::api::stacks::install))
                    .route(web::delete().to(crate::api::stacks::remove)),
            )
            .service(web::resource("/stacks/{id}/prepare").route(web::get().to(crate::api::stacks::prepare)))
            .service(web::resource("/stacks/{id}/check").route(web::post().to(crate::api::stacks::check)))
            .service(web::resource("/stacks/{id}/settings").route(web::put().to(crate::api::stacks::reconfigure)))
            .service(web::resource("/stacks/{id}/action").route(web::post().to(crate::api::stacks::act)))
            .service(web::resource("/stacks/{id}/job").route(web::get().to(crate::api::stacks::job)))
            .service(web::resource("/stacks/{id}/job/cancel").route(web::post().to(crate::api::stacks::cancel)))
            .service(web::resource("/stacks/{id}/services").route(web::get().to(crate::api::stacks::services)))
            .service(web::resource("/stacks/{id}/login").route(web::post().to(crate::api::stacks::login)))
            .service(web::resource("/stacks/{id}/enter").route(web::post().to(crate::api::stacks::enter)))
            .service(web::resource("/kernel").route(web::get().to(crate::api::kernel::view)))
            .service(web::resource("/kernel/act").route(web::post().to(crate::api::kernel::act)))
            .service(web::resource("/kernel/job").route(web::get().to(crate::api::kernel::job)))
            .service(web::resource("/tailscale").route(web::get().to(crate::api::tailscale::view)))
            .service(web::resource("/tailscale/act").route(web::post().to(crate::api::tailscale::act)))
            .service(web::resource("/tailscale/job").route(web::get().to(crate::api::tailscale::job)))
            .service(web::resource("/tailscale/job/cancel").route(web::post().to(crate::api::tailscale::cancel)))
            .service(web::resource("/tailscale/ping").route(web::post().to(crate::api::tailscale::ping)))
            .service(web::resource("/cleanup").route(web::get().to(crate::api::cleanup::view)))
            .service(web::resource("/cleanup/scan").route(web::post().to(crate::api::cleanup::start_scan)))
            .service(web::resource("/cleanup/clean").route(web::post().to(crate::api::cleanup::clean)))
            .service(web::resource("/cleanup/job").route(web::get().to(crate::api::cleanup::job)))
            .service(web::resource("/ubuntu-pro").route(web::get().to(crate::api::ubuntu_pro::view)))
            .service(web::resource("/ubuntu-pro/act").route(web::post().to(crate::api::ubuntu_pro::act)))
            .service(web::resource("/ubuntu-pro/job").route(web::get().to(crate::api::ubuntu_pro::job)))
            .service(web::resource("/waf").route(web::get().to(crate::api::waf::view)))
            .service(web::resource("/waf/{server}").route(web::put().to(crate::api::waf::set)))
            .service(web::resource("/waf/{server}/events").route(web::post().to(crate::api::waf::events)))
            .service(web::resource("/waf/{server}/install").route(web::post().to(crate::api::waf::install)))
            .service(web::resource("/proxy").route(web::get().to(crate::api::proxy::view)))
            .service(web::resource("/proxy/job").route(web::get().to(crate::api::proxy::job)))
            .service(web::resource("/proxy/{server}/sites").route(web::put().to(crate::api::proxy::set_sites)))
            .service(web::resource("/proxy/{server}/install").route(web::post().to(crate::api::proxy::install)))
            .service(web::resource("/agent-tools").route(web::get().to(crate::api::agent_tools::list)))
            .service(web::resource("/agent-tools/providers").route(web::get().to(crate::api::agent_tools::providers)))
            .service(web::resource("/agent-tools/job").route(web::get().to(crate::api::agent_tools::job)))
            .service(web::resource("/agent-tools/job/cancel").route(web::post().to(crate::api::agent_tools::cancel)))
            .service(web::resource("/agent-tools/{tool}/configure").route(web::post().to(crate::api::agent_tools::configure)))
            .service(web::resource("/agent-tools/{tool}/gateway").route(web::post().to(crate::api::agent_tools::gateway)))
            .service(web::resource("/agent-tools/{tool}/{verb}").route(web::post().to(crate::api::agent_tools::change)))
            .service(web::resource("/inference").route(web::get().to(crate::api::inference::overview)))
            .service(web::resource("/inference/recommend").route(web::post().to(crate::api::inference::recommend)))
            .service(web::resource("/inference/job").route(web::get().to(crate::api::inference::job)))
            .service(web::resource("/inference/job/cancel").route(web::post().to(crate::api::inference::job_cancel)))
            .service(web::resource("/inference/mlx/install").route(web::post().to(crate::api::inference::mlx_install)))
            .service(
                web::resource("/inference/mlx")
                    .route(web::put().to(crate::api::inference::mlx_start))
                    .route(web::delete().to(crate::api::inference::mlx_stop)),
            )
            .service(web::resource("/inference/ollama/{instance}/models").route(web::get().to(crate::api::inference::ollama_models)))
            .service(web::resource("/inference/ollama/{instance}/pull").route(web::post().to(crate::api::inference::ollama_pull)))
            .service(web::resource("/inference/ollama/{instance}/delete").route(web::post().to(crate::api::inference::ollama_delete)))
            .service(
                web::resource("/desk/apps/{app}/storage")
                    .state(web::types::JsonConfig::default().limit(crate::api::desk_storage::MAX_BODY))
                    .route(web::get().to(crate::api::desk_storage::list))
                    .route(web::put().to(crate::api::desk_storage::put))
                    .route(web::delete().to(crate::api::desk_storage::remove)),
            )
            .service(
                web::resource("/snippets/plan")
                    .state(
                        web::types::JsonConfig::default()
                            .limit(crate::api::snippets::MAX_REQUEST),
                    )
                    .route(web::post().to(crate::api::snippets::plan)),
            )
            .service(
                // A streamed body, so ntex's payload limit must not
                // apply: the point of this endpoint is the file that
                // `/exec` could not carry.
                web::resource("/fs/write").route(web::put().to(crate::api::fs::write)),
            )
            .route("/fs/roots", web::get().to(crate::api::fs::roots))
            .route("/fs/list", web::get().to(crate::api::fs::list))
            .route("/fs/stat", web::get().to(crate::api::fs::stat))
            .route("/fs/read", web::get().to(crate::api::fs::read))
            .route("/fs/mkdir", web::post().to(crate::api::fs::mkdir))
            .route("/fs/rename", web::post().to(crate::api::fs::rename))
            .route("/fs/chmod", web::post().to(crate::api::fs::chmod))
            .route("/fs/remove", web::delete().to(crate::api::fs::remove))
            .route("/me/password", web::put().to(crate::api::admin::change_own_password))
            .service(
                // Its own payload limit, like `/exec`: the body is
                // every custom command at once, and a user who pastes
                // a real script into one would otherwise meet ntex's
                // 32 KiB default as a 413 with nothing to explain it.
                web::resource("/custom-cmds")
                    .state(
                        web::types::JsonConfig::default()
                            .limit(crate::api::custom_cmds::MAX_REQUEST),
                    )
                    .route(web::get().to(crate::api::custom_cmds::list))
                    .route(web::put().to(crate::api::custom_cmds::replace)),
            )
            .service(
                // Its own payload limit, like `/custom-cmds`: the body is
                // every notification channel at once, and a webhook's
                // `body_template` is a document the user pastes in.
                web::resource("/push")
                    .state(
                        web::types::JsonConfig::default()
                            .limit(crate::api::push::MAX_REQUEST),
                    )
                    .route(web::get().to(crate::api::push::list))
                    .route(web::put().to(crate::api::push::replace)),
            )
            .service(
                web::resource("/push/test")
                    .state(
                        web::types::JsonConfig::default()
                            .limit(crate::api::push::MAX_REQUEST),
                    )
                    .route(web::post().to(crate::api::push::test)),
            )
            .route("/settings", web::get().to(get_settings))
            .route("/settings", web::put().to(update_settings))
            .route("/card-order", web::get().to(get_card_order))
            .route("/card-order", web::put().to(update_card_order))
            .route("/metrics/history", web::get().to(get_metrics_history))
            .route("/health", web::get().to(health_check))
            .route("/velocity", web::get().to(get_velocity))
            .route("/velocity/history", web::get().to(get_velocity_history))
            // An endpoint this agent does not have is a JSON 404, not the
            // panel's page the app-level fallback would answer with a 200.
            .default_service(web::to(api_not_found)),
    );
}

async fn api_not_found() -> HttpResponse {
    crate::api::authz::error(ntex::http::StatusCode::NOT_FOUND, "not_found", "No such endpoint")
}

pub async fn start_server(app_state: Arc<AppState>) -> Result<()> {
    let server_config = app_state.config.get_server();
    let bind_addr = format!("{}:{}", server_config.host, server_config.port);

    // Always: a terminal may be opened at any time. A quarter of the grace period:
    // often enough that a reaped session isn't held much past its deadline,
    // rare enough to be invisible.
    start_reaper(
        app_state.sessions.clone(),
        (app_state.remote_access.terminal.detached_timeout / 4).max(Duration::from_secs(10)),
    );

    // Read once here rather than inside the factory: the factory runs per
    // worker, and every worker must apply the same limit.
    let exec_max_request = app_state.remote_access.exec.max_request_bytes;

    let server = HttpServer::new(async move || {
        let cors = Cors::new(app_state.config.get_server().cors_allowed_origins);

        App::new()
            .state(app_state.clone())
            .middleware(Logger::default())
            .middleware(cors)
            .configure(configure_api(exec_max_request))
            // Built assets: hashed, precompressed, cached for good.
            .service(crate::api::assets::asset)
            .service(crate::api::assets::desk_app)
            // Serve legacy `/static` paths and root assets from the bundled
            // Svelte frontend. TODO: drop `/static` once no bookmark or old
            // panel build can still ask for it (the build serves `/assets`).
            .service(
                Files::new("/static", "frontend/dist")
                    .use_etag(true)
                    .use_last_modified(true),
            )
            .service(
                Files::new("/", "frontend/dist")
                    .use_etag(true)
                    .use_last_modified(true)
                    .index_file("index.html"),
            )
            // Serve index.html for unmatched client-side routes.
            .service(serve_index)
            .default_service(web::to(spa_fallback))
    });

    let server = match &server_config.tls {
        Some(tls) => {
            info!("Starting web server on {} (TLS)", bind_addr);
            server.bind_rustls(&bind_addr, &load_rustls_config(tls)?)?
        }
        None => {
            info!("Starting web server on {}", bind_addr);
            server.bind(&bind_addr)?
        }
    };
    server.run().await?;

    Ok(())
}

/// Builds the rustls server config from a PEM certificate and key using the
/// ring provider.
pub(crate) fn load_rustls_config(tls: &crate::core::config::TlsConfig) -> Result<rustls::ServerConfig> {
    use rustls::pki_types::{pem::PemObject, CertificateDer, PrivateKeyDer};

    let certs = CertificateDer::pem_file_iter(&tls.cert_path)
        .and_then(|certs| certs.collect::<std::result::Result<Vec<_>, _>>())
        .map_err(|e| anyhow::anyhow!("TLS certificate {}: {e}", tls.cert_path))?;
    let key = PrivateKeyDer::from_pem_file(&tls.key_path)
        .map_err(|e| anyhow::anyhow!("TLS private key {}: {e}", tls.key_path))?;

    let config = rustls::ServerConfig::builder_with_provider(Arc::new(
        rustls::crypto::ring::default_provider(),
    ))
    .with_safe_default_protocol_versions()
    .map_err(|e| anyhow::anyhow!("TLS protocol config: {e}"))?
    .with_no_client_auth()
    .with_single_cert(certs, key)
    .map_err(|e| anyhow::anyhow!("Invalid TLS cert/key: {e}"))?;
    Ok(config)
}

#[web::get("/")]
async fn serve_index() -> impl web::Responder {
    spa_fallback().await
}

async fn spa_fallback() -> HttpResponse {
    match tokio::fs::read_to_string("frontend/dist/index.html").await {
        Ok(content) => HttpResponse::Ok()
            .content_type("text/html; charset=utf-8")
            .body(content),
        Err(_) => HttpResponse::InternalServerError().json(&ErrorResponse {
            error: "Failed to load index.html".to_string(),
        }),
    }
}

/// Which `ServerStatus` fields this platform can collect at all — depends
/// only on the OS the agent runs on, never on a sample, so unlike `/metrics`
/// this isn't meant to be polled; the frontend fetches it once per server
/// connection. See `sbm_parser::capabilities` for the three-state meaning and
/// `monitoring::effective_capabilities` for monitor's native-sampling overrides.
/// `Capabilities` plus the OS family — mechanically derived from the same
/// `system_type()` used to compute `capabilities` itself, so it can't drift
/// out of sync. Used by the panel to pick an OS icon for the sidebar/header;
/// `Bsd` covers macOS (the only Bsd target this monitor actually ships on).
#[derive(Serialize)]
struct CapabilitiesView {
    #[serde(flatten)]
    capabilities: Capabilities,
    platform: SystemType,
    /// This agent's own version, so a client can say which one it is talking
    /// to — and tell an old one apart from a misconfigured one.
    version: &'static str,
    /// How far back this agent is configured to keep readings, in days.
    ///
    /// What a client can ask for is this, not a number it decided: an agent
    /// keeping three days and one keeping ninety are both ordinary, and a
    /// client offering "30 d" to the first draws an empty chart and calls it a
    /// machine that was idle.
    retention_days: u32,
    /// The instant of the oldest reading still stored, or absent on an agent
    /// that has none.
    ///
    /// The other half of the answer, and the one that is true rather than
    /// intended: retention says what is not deleted, this says what was
    /// actually collected — an agent started yesterday under a 90-day policy
    /// has a day.
    #[serde(skip_serializing_if = "Option::is_none")]
    oldest_sample: Option<String>,
    /// The machine-management endpoints this agent serves — see
    /// `api::machine::FEATURES`. Whether they may be used over this link is
    /// `access`.
    features: Vec<&'static str>,
    /// The web apps this agent deployed, and their state (`stacks`): what
    /// decides whether a panel offers their windows. Empty for a watch token.
    stacks: Vec<StackBrief>,
    /// Whether the caller may act on the machine over this link: `ok`, and
    /// `why` (`insecure_transport`) when not. Never, for a watch token.
    access: serde_json::Value,
}

#[derive(Serialize)]
struct StackBrief {
    id: String,
    /// `installing` | `installed` | `failed`.
    state: String,
}

async fn get_capabilities(req: HttpRequest, app_state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    let reader = require_read_access!(&req, &app_state);
    let caller = match &reader {
        Reader::Account(caller) => Some(caller),
        Reader::Watch => None,
    };
    let platform = monitoring::system_type();
    let capabilities = monitoring::effective_capabilities(platform);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    // Indexed by timestamp, so this is a seek rather than a scan. Failure is
    // not fatal to the answer: a client that cannot learn the oldest sample
    // falls back to offering the fixed windows, which is what it did before
    // this field existed.
    let oldest_sample: Option<String> =
        sqlx::query_scalar("SELECT min(timestamp) FROM system_metrics")
            .fetch_one(&app_state.db)
            .await
            .unwrap_or(None);
    Ok(HttpResponse::Ok().json(&CapabilitiesView {
        capabilities,
        platform,
        version: env!("CARGO_PKG_VERSION"),
        // The default is what the agent itself falls back to when the section
        // is absent, so a client is told the policy in force rather than that
        // there is none.
        retention_days: app_state
            .config
            .get_monitoring()
            .data_retention
            .unwrap_or_default()
            .metrics_days,
        oldest_sample,
        features: crate::api::machine::features(),
        stacks: match caller {
            Some(_) => crate::stacks::store::all(&app_state.db)
                .await
                .unwrap_or_default()
                .into_iter()
                .map(|r| StackBrief { id: r.id, state: r.state })
                .collect(),
            None => Vec::new(),
        },
        access: authz::access_view(caller, &app_state, secure),
    }))
}

/// Exchanges the caller's JWT for a short-lived, single-use ticket that
/// authorises one WebSocket upgrade — see `api::ws::ticket` for why the
/// upgrade can't just carry the JWT.
///
/// Refuses to mint a ticket while the endpoint it is for is unavailable, so a
/// client finds out here rather than at a failed handshake. The purpose is
/// checked rather than assumed: it arrives in a request body, and issuing a
/// terminal ticket for a client that asked for a stream would hand it exactly
/// the authorisation it did not qualify for.
async fn issue_ws_ticket(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
    payload: web::types::Json<TicketRequest>,
) -> Result<HttpResponse> {
    let caller = require_jwt!(&req, &app_state);

    let remote_ip = audit::peer_ip(&req);
    let purpose = payload.into_inner().purpose;
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let ok = caller.check(&app_state, secure).is_ok();
    let (available, detail) = match purpose {
        Purpose::Terminal => (ok, "terminal not available"),
        Purpose::Stream => (ok, "stream not available"),
        Purpose::Listen => (ok, "listen not available"),
        Purpose::Rdp => (ok, "rdp not available"),
        // Bound to the console it opens, so only `POST /virt/console` mints
        // one.
        Purpose::Virt => (false, "virt consoles are opened through /virt/console"),
        Purpose::Proxy => (false, "app windows are entered through /stacks/{id}/enter"),
    };
    if !available {
        Event::new(Kind::Ticket, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail(detail)
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().json(&ErrorResponse {
            error: detail.to_string(),
        }));
    }

    match app_state.tickets.issue(purpose) {
        Ok(ticket) => {
            Event::new(Kind::Ticket, Action::Open, Outcome::Ok)
                .remote_ip(remote_ip)
                .detail(match purpose {
                    Purpose::Terminal => "terminal",
                    Purpose::Stream => "stream",
                    Purpose::Listen => "listen",
                    Purpose::Rdp => "rdp",
                    Purpose::Virt => "virt",
                    Purpose::Proxy => "proxy",
                })
                .record(&app_state.db)
                .await;
            Ok(HttpResponse::Ok()
                .json(&TicketResponse::new(ticket)))
        }
        Err(e) => {
            Event::new(Kind::Ticket, Action::Denied, Outcome::Error)
                .remote_ip(remote_ip)
                .detail("issue failed")
                .record(&app_state.db)
                .await;
            match e {
                MonitorError::Quota {
                    message,
                    retry_after_secs,
                } => Ok(HttpResponse::TooManyRequests()
                    .header(RETRY_AFTER, retry_after_secs.to_string())
                    .json(&ErrorResponse { error: message })),
                other => Ok(HttpResponse::ServiceUnavailable().json(&ErrorResponse {
                    error: other.to_string(),
                })),
            }
        }
    }
}

async fn health_check() -> HttpResponse {
    HttpResponse::Ok().json(&serde_json::json!({
        "status": "healthy",
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

pub(crate) fn bearer_token(req: &HttpRequest) -> Result<&str> {
    let auth_header = req
        .headers()
        .get("Authorization")
        .ok_or_else(|| {
            MonitorError::Auth("Missing Authorization header".to_string())
        })?
        .to_str()
        .map_err(|_| {
            MonitorError::Auth("Invalid Authorization header".to_string())
        })?;

    if !auth_header.starts_with("Bearer ") {
        return Err(MonitorError::Auth(
            "Invalid Authorization format".to_string(),
        ));
    }

    Ok(&auth_header[7..])
}

#[cfg(test)]
mod tls_tests {
    use super::load_rustls_config;
    use crate::core::config::TlsConfig;

    fn write(dir: &tempfile::TempDir, name: &str, body: &str) -> String {
        let path = dir.path().join(name);
        std::fs::write(&path, body).unwrap();
        path.to_string_lossy().into_owned()
    }

    #[test]
    fn a_pem_certificate_and_key_load() {
        let rcgen::CertifiedKey { cert, signing_key } =
            rcgen::generate_simple_self_signed(vec!["localhost".into()]).unwrap();
        let dir = tempfile::tempdir().unwrap();
        let tls = TlsConfig {
            cert_path: write(&dir, "cert.pem", &cert.pem()),
            key_path: write(&dir, "key.pem", &signing_key.serialize_pem()),
        };
        load_rustls_config(&tls).expect("load");
    }

    #[test]
    fn a_key_file_without_a_key_is_refused_by_name() {
        let rcgen::CertifiedKey { cert, .. } =
            rcgen::generate_simple_self_signed(vec!["localhost".into()]).unwrap();
        let dir = tempfile::tempdir().unwrap();
        let tls = TlsConfig {
            cert_path: write(&dir, "cert.pem", &cert.pem()),
            key_path: write(&dir, "key.pem", &cert.pem()),
        };
        let error = load_rustls_config(&tls).unwrap_err().to_string();
        assert!(error.contains("key.pem"), "{error}");
    }
}

// After the `require_*` macros, which the handlers there use.
mod login;
mod metrics;
mod settings;
mod state;

pub use state::*;
pub(crate) use login::verify_watch_token;
use login::*;
use metrics::*;
use settings::*;
