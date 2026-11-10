//! Kernels' backend: the machine's Linux kernels and which GRUB boots
//! (`sbm_parser::kernel`). The view is read as the agent's account; each
//! change is checked against a fresh read and run as root as a job. A new
//! kernel runs after a restart, which the page asks the desk for.

wit_bindgen::generate!({ path: ["../../wit", "wit"], world: "serverbox:kernel/kernel", generate_all });

use exports::serverbox::kernel::api::{self, Kernel, Offered, Series, Kernels};
use exports::serverbox::kernel::jobs;
use sbm::app::types::Error;
use sbm::app::{host, job};
use sbm_parser::kernel::{self as kn, Action};

struct App;

fn read() -> Result<kn::KernelView, Error> {
    let out = host::exec(kn::READ_COMMAND, None)?;
    Ok(kn::parse(&String::from_utf8_lossy(&out.stdout)))
}

fn view(v: kn::KernelView) -> Kernels {
    Kernels {
        supported: v.supported,
        running: v.running,
        installed: v
            .installed
            .into_iter()
            .map(|k| Kernel { release: k.release, package: k.package, version: k.version, running: k.running, default: k.default, next: k.next, needed_by: k.needed_by })
            .collect(),
        pinned: v.pinned,
        series: v.series.into_iter().map(|s| Series { package: s.package, version: s.version, installed: s.installed }).collect(),
        versions: v.versions.into_iter().map(|o| Offered { package: o.package, release: o.release, version: o.version }).collect(),
        reboot_required: v.reboot_required,
    }
}

/// [action] checked against a fresh read, then run as root.
fn act(action: Action) -> Result<(), Error> {
    let now = read()?;
    kn::check(&now, &action).map_err(|e| Error::FailedPrecondition(e.into()))?;
    match job::run_root(&kn::script(&action))? {
        0 => Ok(()),
        kn::EXIT_WOULD_REMOVE_MORE => Err(Error::FailedPrecondition("wouldRemoveMore".into())),
        kn::EXIT_NO_ENTRY => Err(Error::FailedPrecondition("noEntry".into())),
        n => Err(Error::Internal(format!("exited with {n}"))),
    }
}

impl api::Guest for App {
    fn view() -> Result<Kernels, Error> {
        read().map(view)
    }
}

impl jobs::Guest for App {
    fn install(package: String) -> Result<(), Error> {
        act(Action::Install { package })
    }

    fn remove(release: String) -> Result<(), Error> {
        act(Action::Remove { release })
    }

    fn boot(release: String, once: bool) -> Result<(), Error> {
        act(Action::Boot { release, once })
    }

    fn boot_newest() -> Result<(), Error> {
        act(Action::BootNewest)
    }
}

export!(App);
