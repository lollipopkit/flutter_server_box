//! Telling what a server runs, over SSH, before anything is installed there:
//! `uname` first (the least invasive, and every Unix has it), then Windows'
//! `ver` when `uname` said nothing it knows.

use crate::SystemType;

/// The kernel's name, and nothing on Windows.
pub const UNAME_PROBE: &str = "uname -a 2>/dev/null";
/// `Microsoft Windows [Version …]`, and nothing on a Unix shell.
pub const VER_PROBE: &str = "ver 2>nul";

/// What `uname -a` says by the first word of its line, the kernel's name:
/// `Linux`, or `Darwin` and the BSDs. The last such line: a shell's rc file
/// may print before it (a banner on a non-interactive SSH command). `None`
/// for anything else (an MSYS or Cygwin shell on Windows, a shell that
/// printed nothing).
pub fn from_uname(output: &str) -> Option<SystemType> {
    output.lines().rev().find_map(|line| match line.split_whitespace().next()? {
        "Linux" => Some(SystemType::Linux),
        "Darwin" | "FreeBSD" | "OpenBSD" | "NetBSD" | "DragonFly" | "GNU/kFreeBSD" => Some(SystemType::Bsd),
        _ => None,
    })
}

/// Whether `ver` answered as Windows does.
pub fn from_ver(output: &str) -> Option<SystemType> {
    output.contains("Microsoft Windows").then_some(SystemType::Windows)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn uname_is_read_by_the_kernel_name() {
        assert_eq!(from_uname("Linux pve 6.8.12-4-pve #1 SMP x86_64 GNU/Linux\n"), Some(SystemType::Linux));
        assert_eq!(from_uname("Darwin mac.local 24.1.0 Darwin Kernel Version 24.1.0 arm64"), Some(SystemType::Bsd));
        assert_eq!(from_uname("FreeBSD fw 14.1-RELEASE FreeBSD 14.1-RELEASE amd64"), Some(SystemType::Bsd));
        assert_eq!(from_uname("OpenBSD gw 7.6 GENERIC.MP#338 amd64"), Some(SystemType::Bsd));
        // Not by a word further on: an MSYS shell on Windows names NT, and a
        // host may be called anything.
        assert_eq!(from_uname("MINGW64_NT-10.0-22631 box 3.4.10 x86_64 Msys"), None);
        assert_eq!(from_uname("SunOS linux-box 5.11 i86pc"), None);
        assert_eq!(from_uname(""), None);
        // A banner from the shell's rc file before it.
        assert_eq!(from_uname("Welcome to fw\n\nFreeBSD fw 14.1-RELEASE amd64\n"), Some(SystemType::Bsd));
        assert_eq!(from_uname("Linux tips: see /etc/motd\nDarwin mac.local 24.1.0 arm64\n"), Some(SystemType::Bsd));
    }

    #[test]
    fn ver_is_windows_only_when_it_says_so() {
        assert_eq!(from_ver("\r\nMicrosoft Windows [Version 10.0.22631.4317]\r\n"), Some(SystemType::Windows));
        // What the old check took for Windows: any output with "NT" in it.
        assert_eq!(from_ver("sh: ver: command not found (NT)"), None);
        assert_eq!(from_ver(""), None);
    }
}
