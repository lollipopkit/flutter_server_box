// The Linux userland on iOS, and the switch that removes it.
//
// iOS gives an App Store app no fork/exec and no /bin/sh, so the Android
// answer — a real rootfs entered through proot — has nothing to enter it with.
// ish-arm64 is an interpreter instead: guest AArch64 dispatched to
// pre-compiled native gadgets, no machine code written at runtime, and no
// guest binary ever handed to the kernel. See TODOS.md, "本机 shell 与 rootfs", stage 4.
//
// ## The switch
//
// Everything below is compiled out unless SBM_ISH_ENABLED is 1, and the engine
// is only linked in the same case — one line in ios/Flutter/Ish.xcconfig
// controls both. With it off, this file is a handful of stubs, the binary
// carries no interpreter and no guest code path, and sbm_ish_available()
// returns false, which is what the Dart side asks before offering anything.
//
// It exists because the risk here is not the feature being rejected: App Store
// guideline 2.5.2 is about downloading and running executable code, iSH was
// nearly pulled over it, and what gets blocked in that argument is the whole
// app's next update. A build without the engine has to be one edit and a
// rebuild away, not a refactor.
//
// The functions are safe to call whichever way the switch is set. A caller
// that checks sbm_ish_available() first is asking the question honestly; one
// that does not gets a refusal rather than a crash.

#ifndef SBM_ISH_H
#define SBM_ISH_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Kept, because nothing in the app calls these.
///
/// Dart looks them up by name at runtime through `DynamicLibrary.process()`,
/// which the linker cannot see: without this it dead-strips every one of them,
/// and the engine they reference goes with them — measured, an app binary of
/// 58 KB and no `sbm_ish` symbol in it.
#define SBM_ISH_EXPORT __attribute__((visibility("default"), used))

/// Whether this build carries the engine at all.
SBM_ISH_EXPORT bool sbm_ish_available(void);

/// Starts the machine, with [rootfs] as its filesystem.
///
/// Returns 0, or a negative errno; a second call answers -EEXIST. One machine
/// per app process, because the kernel keeps its state in globals — but a
/// machine runs as many processes as it is asked to, which is what
/// [sbm_ish_open] is for, and it holds as many Linux systems as it is given,
/// which is what [sbm_ish_attach] is for.
///
/// [rootfs] is a directory holding one subdirectory per system, each an
/// ordinary unpacked tree. Nothing ever runs at that root: a session is rooted
/// at its own subtree, the way a container is. That is as much isolation as
/// there is — one kernel means one PID space, one network and one pty
/// numbering, and the systems can see each other through `/proc`.
///
/// [profile] names the subdirectory init itself lives in, since the root of a
/// container of trees holds no shell to start it with.
SBM_ISH_EXPORT int sbm_ish_boot(const char *rootfs, const char *profile);

/// Mounts one system's `/proc`, `/dev`, `/dev/pts` and `/dev/shm`.
///
/// Returns 0, or a negative errno. Idempotent: the second call for a name that
/// is already attached answers 0 without mounting anything again. Called for
/// you by [sbm_ish_open], so a caller only needs this to attach a system ahead
/// of wanting a terminal in it.
SBM_ISH_EXPORT int sbm_ish_attach(const char *profile);

/// Unmounts one system's filesystems and forgets it, so a later [sbm_ish_attach]
/// for the same name mounts afresh.
///
/// Returns 0, or a negative errno — `EBUSY` while a session still holds the
/// mounts. Call it before deleting or replacing a system's directory: the
/// `/dev` mounted for it is backed by a database inside that directory.
SBM_ISH_EXPORT int sbm_ish_detach(const char *profile);

/// How many sessions are open in `profile`.
///
/// Asked before offering to delete a system. Detaching one hangs up whatever
/// is running in it, which is right as a last resort and wrong as a surprise:
/// a shell someone left a half-typed command in is not something to close on
/// their behalf without saying so.
///
/// The engine's own count rather than the app's, because this is the same list
/// that decides whether the unmount can succeed. A session the app has
/// forgotten about would still hold the filesystem.
///
/// Answers 0 for a machine that never booted, which has no sessions in it.
SBM_ISH_EXPORT int sbm_ish_sessions(const char *profile);

/// Opens a session: a process in the machine, on a pseudo-terminal of its own.
///
/// Returns a handle, or a negative errno. [command] is what to run; NULL or
/// empty gives an interactive shell. Sessions are independent — a terminal and
/// a one-shot command do not share a console, and neither sees the other's
/// output.
///
/// [shell] is what to run it with, NULL or empty meaning `/bin/sh`. It is a
/// parameter because the guest has no `login` and nothing there reads
/// `/etc/passwd` — the shell is this app's choice and no other, which is why
/// Alpine shipping no `chsh` does not come into it. A shell that will not exec
/// falls back to `/bin/sh` rather than handing back a terminal that dies on
/// sight.
/// [profile] is which system to run it in — the subdirectory name, not a path.
SBM_ISH_EXPORT int sbm_ish_open(const char *profile, const char *shell,
                                const char *command, int columns, int rows);

/// Reads what [session] has printed, waiting up to [timeout_ms] for the first
/// byte. Returns the number of bytes, 0 on timeout, or -1 once that session
/// has ended and its output has been drained.
SBM_ISH_EXPORT int sbm_ish_read(int session, char *buffer, int length, int timeout_ms);

/// Types [length] bytes at [session].
SBM_ISH_EXPORT int sbm_ish_write(int session, const char *buffer, int length);

/// Tells [session] its terminal changed size.
SBM_ISH_EXPORT void sbm_ish_resize(int session, int columns, int rows);

/// [session]'s exit status, or -1 while it is still running.
SBM_ISH_EXPORT int sbm_ish_exit_code(int session);

/// Ends [session]: its process is signalled and its handle released.
SBM_ISH_EXPORT void sbm_ish_close(int session);

#ifdef __cplusplus
}
#endif

#endif // SBM_ISH_H
