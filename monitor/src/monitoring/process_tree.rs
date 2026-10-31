//! Ending a command together with everything it started.
//!
//! A command that times out is ended as a tree, or what it spawned keeps the
//! output pipes it inherited open: the reader that timed out cannot finish,
//! and the next cycle starts another one beside it. A `powershell -File`
//! running the status script starts smartctl and battery queries; `sh -c`
//! does the same on Unix.
//!
//! Only on the way out of a command that will not finish. One that does is
//! left alone, along with anything it chose to leave running, on every
//! platform.

use tokio::process::{Child, Command};

/// The processes a spawned command is the root of.
///
/// On Unix its process group, which the command leads. On Windows a job
/// object: Windows keeps no group to signal, and walking the tree by parent
/// PID — `taskkill /T` — misses a process started while the walk runs, or one
/// whose parent has already gone.
pub(super) struct CommandTree {
    #[cfg(unix)]
    group: Option<u32>,
    #[cfg(windows)]
    job: Option<job::Job>,
    #[cfg(windows)]
    pid: Option<u32>,
}

impl CommandTree {
    /// Sets up [command] so that [CommandTree::start] can hold all of it.
    pub(super) fn prepare(command: &mut Command) {
        #[cfg(unix)]
        {
            use std::os::unix::process::CommandExt;
            // Its descendants inherit this group.
            command.as_std_mut().process_group(0);
        }
        #[cfg(windows)]
        {
            // Not running until it is in the job, so nothing it starts can be
            // started outside it. `start` resumes it.
            command.creation_flags(windows_sys::Win32::System::Threading::CREATE_SUSPENDED);
        }
    }

    /// The tree [child] roots, for a command set up by [CommandTree::prepare].
    pub(super) fn start(child: &Child) -> Self {
        #[cfg(unix)]
        {
            Self { group: child.id() }
        }
        #[cfg(windows)]
        {
            let pid = child.id();
            let job = child.raw_handle().and_then(job::Job::for_process);
            if job.is_none() {
                tracing::debug!("command not placed in a job object; ending it falls back to taskkill");
            }
            // Resumed whether or not it is in a job: a command left suspended
            // would only reach its timeout.
            if let Some(pid) = pid
                && !job::resume(pid)
            {
                tracing::warn!("could not resume command {pid}; it will time out");
            }
            Self { job, pid }
        }
    }

    /// Ends every process in the tree, and then [child] for certain.
    pub(super) async fn terminate(&self, child: &mut Child) {
        if !self.terminate_tree().await
            && let Err(e) = child.start_kill()
        {
            tracing::warn!("could not end a command: {e}");
        }
    }

    /// Ends every process in the tree, without a child to fall back on. True
    /// when the whole tree was reached.
    pub(super) async fn terminate_tree(&self) -> bool {
        #[cfg(unix)]
        if let Some(id) = self.group
            // The group ID is the leader's PID. A negative PID is POSIX's
            // "signal the group" form.
            && unsafe { kill_process_group(-(id as i32), 9) } == 0
        {
            return true;
        }
        #[cfg(windows)]
        {
            if self.job.as_ref().is_some_and(job::Job::terminate) {
                return true;
            }
            // No job: a process cannot always be placed in one. Waited for,
            // because the walk goes by parent: a root ended before it runs
            // takes the way to its descendants with it.
            if let Some(pid) = self.pid {
                const CREATE_NO_WINDOW: u32 = 0x0800_0000;
                use std::process::Stdio;
                return Command::new("taskkill")
                    .args(["/T", "/F", "/PID", &pid.to_string()])
                    .creation_flags(CREATE_NO_WINDOW)
                    .stdin(Stdio::null())
                    .stdout(Stdio::null())
                    .stderr(Stdio::null())
                    .status()
                    .await
                    .is_ok_and(|status| status.success());
            }
        }
        false
    }
}

#[cfg(unix)]
unsafe extern "C" {
    #[link_name = "kill"]
    fn kill_process_group(pid: i32, signal: i32) -> i32;
}

#[cfg(windows)]
mod job {
    use std::os::windows::io::RawHandle;

    use windows_sys::Win32::Foundation::{CloseHandle, HANDLE, INVALID_HANDLE_VALUE};
    use windows_sys::Win32::System::Diagnostics::ToolHelp::{
        CreateToolhelp32Snapshot, TH32CS_SNAPTHREAD, THREADENTRY32, Thread32First, Thread32Next,
    };
    use windows_sys::Win32::System::JobObjects::{
        AssignProcessToJobObject, CreateJobObjectW, TerminateJobObject,
    };
    use windows_sys::Win32::System::Threading::{OpenThread, ResumeThread, THREAD_SUSPEND_RESUME};

    /// A job holding one command and what it starts.
    ///
    /// No kill-on-close: a command that finished is left with whatever it
    /// chose to leave running, as on Unix. Only [Job::terminate] ends it.
    pub(super) struct Job(HANDLE);

    // SAFETY: a job object handle is a kernel handle, usable from any thread.
    unsafe impl Send for Job {}
    unsafe impl Sync for Job {}

    impl Job {
        pub(super) fn for_process(process: RawHandle) -> Option<Self> {
            // SAFETY: plain Win32 calls on handles this owns or borrows for the
            // call; `job` closes its handle on every early return.
            unsafe {
                let handle = CreateJobObjectW(std::ptr::null(), std::ptr::null());
                if handle.is_null() {
                    return None;
                }
                let job = Job(handle);
                if AssignProcessToJobObject(job.0, process as HANDLE) == 0 {
                    return None;
                }
                Some(job)
            }
        }

        /// Ends every process in the job at once, which is what a walk by
        /// parent cannot promise.
        pub(super) fn terminate(&self) -> bool {
            // SAFETY: `self.0` is a live job handle until `drop`.
            unsafe { TerminateJobObject(self.0, 1) != 0 }
        }
    }

    impl Drop for Job {
        fn drop(&mut self) {
            // SAFETY: closed once, here.
            unsafe {
                CloseHandle(self.0);
            }
        }
    }

    /// Resumes process [pid], created suspended.
    ///
    /// Through its threads, since the handle to the one it was created with is
    /// not kept by `std`: a process created suspended has that thread alone.
    pub(super) fn resume(pid: u32) -> bool {
        // SAFETY: the snapshot and thread handles are opened and closed here.
        unsafe {
            let snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
            if snapshot == INVALID_HANDLE_VALUE {
                return false;
            }
            let mut entry = THREADENTRY32 {
                dwSize: size_of::<THREADENTRY32>() as u32,
                ..Default::default()
            };
            let mut resumed = false;
            let mut more = Thread32First(snapshot, &mut entry) != 0;
            while more {
                if entry.th32OwnerProcessID == pid {
                    let thread = OpenThread(THREAD_SUSPEND_RESUME, 0, entry.th32ThreadID);
                    if !thread.is_null() {
                        resumed |= ResumeThread(thread) != u32::MAX;
                        CloseHandle(thread);
                    }
                }
                more = Thread32Next(snapshot, &mut entry) != 0;
            }
            CloseHandle(snapshot);
            resumed
        }
    }
}
