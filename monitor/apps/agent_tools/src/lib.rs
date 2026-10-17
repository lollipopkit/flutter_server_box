//! AI agents' backend (`sbm_parser::agents`), all as the agent's account:
//! what is installed read by the probe; install, update and removal run as
//! the app's job; a tool pointed at one of Agent mode's providers by its own
//! files, merged with what is there and written 0600 by a script reading
//! them on its standard input, so the provider's key is in no command line,
//! log or audit.

wit_bindgen::generate!({ path: ["../../wit", "wit"], world: "serverbox:agent-tools/agent-tools", generate_all });

use exports::serverbox::agent_tools::api::{self, Found, GatewayAction, GatewayOutput, Provider};
use exports::serverbox::agent_tools::jobs;
use sbm::app::types::Error;
use sbm::app::{agent, host, job};
use sbm_parser::agents::{self as model, Api, ConfigureError};
use serverbox::agent_tools::types::Tool;

struct App;

fn of(tool: Tool) -> model::Tool {
    match tool {
        Tool::Codex => model::Tool::Codex,
        Tool::Claude => model::Tool::ClaudeCode,
        Tool::Pi => model::Tool::Pi,
        Tool::Opencode => model::Tool::Opencode,
        Tool::Hermes => model::Tool::Hermes,
        Tool::Openclaw => model::Tool::Openclaw,
    }
}

fn back(tool: model::Tool) -> Tool {
    match tool {
        model::Tool::Codex => Tool::Codex,
        model::Tool::ClaudeCode => Tool::Claude,
        model::Tool::Pi => Tool::Pi,
        model::Tool::Opencode => Tool::Opencode,
        model::Tool::Hermes => Tool::Hermes,
        model::Tool::Openclaw => Tool::Openclaw,
    }
}

fn api_id(api: Api) -> String {
    serde_json::to_value(api).ok().and_then(|v| v.as_str().map(str::to_string)).unwrap_or_default()
}

fn text(b: &[u8]) -> String {
    String::from_utf8_lossy(b).into_owned()
}

/// [script] as the job's step: its lines in the job's log, failing on a
/// non-zero exit.
fn step(script: &str) -> Result<(), Error> {
    match job::run(script)? {
        0 => Ok(()),
        n => Err(Error::Internal(format!("exited with {n}"))),
    }
}

impl api::Guest for App {
    fn view() -> Result<Vec<Found>, Error> {
        let out = host::exec(&model::probe_command(), None)?;
        Ok(model::parse_probe(&text(&out.stdout))
            .into_iter()
            .map(|f| Found {
                tool: back(f.tool),
                path: f.path,
                version: f.version,
                pinned: f.tool.pinned().map(str::to_string),
                homepage: f.tool.homepage().into(),
                gateway: f.tool.has_gateway(),
                apis: f.tool.apis().iter().copied().map(api_id).collect(),
            })
            .collect())
    }

    fn providers() -> Result<Vec<Provider>, Error> {
        Ok(agent::providers()?
            .into_iter()
            .map(|p| Provider { id: p.id, name: p.name, api: p.api, base_url: p.base_url, models: p.models })
            .collect())
    }

    fn configure(tool: Tool, provider: String, model_id: String) -> Result<(), Error> {
        let tool = of(tool);
        let endpoint = agent::endpoint(&provider)?.ok_or_else(|| Error::NotFound("unknownProvider".into()))?;
        let api = Api::from_id(&endpoint.api).ok_or_else(|| Error::InvalidArgument("wrongApi".into()))?;
        let target = model::Target { base_url: endpoint.base_url, api, key: endpoint.key.unwrap_or_default(), model: model_id };
        let mut existing = Vec::new();
        for rel in model::config_files(tool) {
            let out = host::exec(&model::read_file_command(rel), None)?;
            existing.push((out.status == 0).then(|| text(&out.stdout)));
        }
        let (writes, commands) = model::configure(tool, &target, &existing).map_err(|e| match e {
            ConfigureError::WrongApi => Error::InvalidArgument("wrongApi".into()),
            ConfigureError::Invalid => Error::InvalidArgument("invalid".into()),
            ConfigureError::Unreadable { path } => Error::FailedPrecondition(format!("unreadable\n{path}")),
        })?;
        for w in &writes {
            let out = host::exec(&model::write_private_script(w.path), Some(w.content.as_bytes()))?;
            if out.status != 0 {
                return Err(Error::Internal(format!("writeFailed\n{}", w.path)));
            }
        }
        // OpenClaw's configuration changes only with its gateway stopped:
        // stopped first when it runs, started again after.
        let gateway_ran = tool == model::Tool::Openclaw && host::exec(model::OPENCLAW_STATUS, None).is_ok_and(|o| model::openclaw_gateway_running(&text(&o.stdout)));
        if gateway_ran
            && let Some(stop) = model::gateway_script(tool, model::GatewayAction::Stop)
            && !host::exec(&stop, None).is_ok_and(|o| o.status == 0)
        {
            return Err(Error::FailedPrecondition("gatewayWouldNotStop".into()));
        }
        let restart = || {
            if gateway_ran && let Some(start) = model::gateway_script(tool, model::GatewayAction::Start) {
                let _ = host::exec(&start, None);
            }
        };
        for cmd in &commands {
            match host::exec(cmd, None) {
                Ok(o) if o.status == 0 => {}
                Ok(o) => {
                    restart();
                    return Err(Error::Unavailable(format!("commandFailed\n{}{}", text(&o.stdout), text(&o.stderr)).trim().to_string()));
                }
                Err(e) => {
                    restart();
                    return Err(e);
                }
            }
        }
        restart();
        host::log(host::Level::Info, &format!("{} uses {provider}/{}", tool.id(), target.model));
        Ok(())
    }

    fn gateway(tool: Tool, action: GatewayAction) -> Result<GatewayOutput, Error> {
        let action = match action {
            GatewayAction::Status => model::GatewayAction::Status,
            GatewayAction::Install => model::GatewayAction::Install,
            GatewayAction::Start => model::GatewayAction::Start,
            GatewayAction::Stop => model::GatewayAction::Stop,
        };
        let script = model::gateway_script(of(tool), action).ok_or_else(|| Error::NotFound("noGateway".into()))?;
        let out = host::exec(&script, None)?;
        Ok(GatewayOutput { exit_code: out.status, output: text(&out.stdout) })
    }
}

impl jobs::Guest for App {
    fn install(tool: Tool) -> Result<(), Error> {
        step(&model::install_script(of(tool)))
    }

    fn update(tool: Tool) -> Result<(), Error> {
        step(&model::update_script(of(tool)))
    }

    fn uninstall(tool: Tool, purge: bool) -> Result<(), Error> {
        step(&model::uninstall_script(of(tool), purge))
    }
}

export!(App);
