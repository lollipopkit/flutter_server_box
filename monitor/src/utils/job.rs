//! A command and every process it starts, as one Windows job object: what
//! a process group is on Unix. `taskkill /T` walks the tree by parent PID
//! after the fact, so a process started while it walks, or one whose parent
//! already exited, is missed; a job holds every descendant from its start.
//!
//! The command is started suspended and joins the job before it runs, so
//! nothing it starts can be outside it.

use std::io;

use tokio::process::{Child, Command};
use windows_sys::Win32::Foundation::{CloseHandle, HANDLE, INVALID_HANDLE_VALUE};
use windows_sys::Win32::System::Diagnostics::ToolHelp::{
    CreateToolhelp32Snapshot, TH32CS_SNAPTHREAD, THREADENTRY32, Thread32First, Thread32Next,
};
use windows_sys::Win32::System::JobObjects::{AssignProcessToJobObject, CreateJobObjectW, TerminateJobObject};
use windows_sys::Win32::System::Threading::{CREATE_SUSPENDED, OpenThread, ResumeThread, THREAD_SUSPEND_RESUME};

pub const CREATE_NO_WINDOW: u32 = 0x0800_0000;

pub struct Job(HANDLE);

// SAFETY: a job handle may be used and closed from any thread.
unsafe impl Send for Job {}
unsafe impl Sync for Job {}

impl Job {
    /// Ends every process in the job; one that already exited is not there.
    pub fn kill(&self) -> bool {
        // SAFETY: the handle is this job's, open until drop.
        unsafe { TerminateJobObject(self.0, 1) != 0 }
    }
}

impl Drop for Job {
    fn drop(&mut self) {
        // SAFETY: as above; closed once. What is still running keeps running,
        // as a process group does once its leader is reaped.
        unsafe {
            CloseHandle(self.0);
        }
    }
}

/// [command] spawned with [flags], in a job of its own.
pub fn spawn(command: &mut Command, flags: u32) -> io::Result<(Child, Job)> {
    command.creation_flags(flags | CREATE_SUSPENDED);
    let mut child = command.spawn()?;
    match adopt(&child) {
        Ok(job) => Ok((child, job)),
        Err(e) => {
            let _ = child.start_kill();
            Err(e)
        }
    }
}

fn adopt(child: &Child) -> io::Result<Job> {
    let process = child.raw_handle().ok_or_else(|| io::Error::other("the process is gone"))? as HANDLE;
    let pid = child.id().ok_or_else(|| io::Error::other("the process is gone"))?;
    // SAFETY: no attributes and no name: a new, unnamed job.
    let job = unsafe { CreateJobObjectW(std::ptr::null(), std::ptr::null()) };
    if job.is_null() {
        return Err(io::Error::last_os_error());
    }
    let job = Job(job);
    // SAFETY: both handles are open; the process has not run yet.
    if unsafe { AssignProcessToJobObject(job.0, process) } == 0 {
        return Err(io::Error::last_os_error());
    }
    resume(pid)?;
    Ok(job)
}

/// Resumes the one thread a process started suspended has.
fn resume(pid: u32) -> io::Result<()> {
    // SAFETY: a snapshot of every thread, closed below.
    let snapshot = unsafe { CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0) };
    if snapshot == INVALID_HANDLE_VALUE {
        return Err(io::Error::last_os_error());
    }
    let snapshot = Owned(snapshot);
    // SAFETY: zeroed is a valid THREADENTRY32 once its size is set.
    let mut entry: THREADENTRY32 = unsafe { std::mem::zeroed() };
    entry.dwSize = std::mem::size_of::<THREADENTRY32>() as u32;
    // SAFETY: the snapshot is open and [entry] sized.
    let mut more = unsafe { Thread32First(snapshot.0, &mut entry) } != 0;
    while more {
        if entry.th32OwnerProcessID == pid {
            // SAFETY: a thread of the process this spawned.
            let thread = unsafe { OpenThread(THREAD_SUSPEND_RESUME, 0, entry.th32ThreadID) };
            if thread.is_null() {
                return Err(io::Error::last_os_error());
            }
            let thread = Owned(thread);
            // SAFETY: as above.
            if unsafe { ResumeThread(thread.0) } == u32::MAX {
                return Err(io::Error::last_os_error());
            }
            return Ok(());
        }
        // SAFETY: as above.
        more = unsafe { Thread32Next(snapshot.0, &mut entry) } != 0;
    }
    Err(io::Error::other("the process has no thread"))
}

struct Owned(HANDLE);

impl Drop for Owned {
    fn drop(&mut self) {
        // SAFETY: opened above and closed once.
        unsafe {
            CloseHandle(self.0);
        }
    }
}
