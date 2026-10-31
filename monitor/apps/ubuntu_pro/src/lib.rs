//! Ubuntu Pro's backend (`sbm_parser::ubuntu_pro`): the view read as the
//! agent's account; each change checked against a fresh read and run as
//! root as a job. The token is written to a private file the attach reads
//! (`job.private-file`), removed when the job ends.

wit_bindgen::generate!({ path: ["../../wit", "wit"], world: "serverbox:ubuntu-pro/ubuntu-pro", generate_all });

use exports::serverbox::ubuntu_pro::api::{self, Livepatch, Pro, Service};
use exports::serverbox::ubuntu_pro::jobs;
use sbm::app::types::Error;
use sbm::app::{host, job};
use sbm_parser::ubuntu_pro::{self as pro, Action};

struct App;

fn read() -> Result<pro::ProView, Error> {
    let out = host::exec(pro::READ_COMMAND, None)?;
    Ok(pro::parse(&String::from_utf8_lossy(&out.stdout)))
}

fn view(v: pro::ProView) -> Pro {
    Pro {
        ubuntu: v.ubuntu,
        release: v.release,
        client: v.client,
        attached: v.attached,
        account: v.account,
        contract: v.contract,
        expires: v.expires,
        tech_support: v.tech_support,
        services: v
            .services
            .into_iter()
            .map(|s| Service { name: s.name, description: s.description, available: s.available, entitled: s.entitled, status: s.status, status_details: s.status_details })
            .collect(),
        livepatch: v.livepatch.map(|l| Livepatch { kernel: l.kernel, state: l.state, version: l.version, supported: l.supported }),
    }
}

/// [action] checked against a fresh read, then run as root; [config] the
/// private file of an attach.
fn act(action: Action, config: Option<&str>) -> Result<(), Error> {
    let now = read()?;
    pro::check(&now, &action).map_err(|e| Error::FailedPrecondition(e.into()))?;
    let script = pro::script(&action, config).map_err(|e| Error::InvalidArgument(e.into()))?;
    match job::run_root(&script)? {
        0 => Ok(()),
        n => Err(Error::Internal(format!("exited with {n}"))),
    }
}

impl api::Guest for App {
    fn view() -> Result<Pro, Error> {
        read().map(view)
    }
}

impl jobs::Guest for App {
    fn install_client() -> Result<(), Error> {
        act(Action::InstallClient, None)
    }

    fn attach(token: String, auto_enable: bool) -> Result<(), Error> {
        let config = pro::attach_config(token.trim()).ok_or_else(|| Error::InvalidArgument("invalidToken".into()))?;
        let path = job::private_file(config.as_bytes())?;
        act(Action::Attach { auto_enable }, Some(&path))
    }

    fn detach() -> Result<(), Error> {
        act(Action::Detach, None)
    }

    fn enable(service: String) -> Result<(), Error> {
        act(Action::Enable { service }, None)
    }

    fn disable(service: String) -> Result<(), Error> {
        act(Action::Disable { service }, None)
    }
}

export!(App);
