// The Linux userland on iOS, and the switch that removes it.
//
// iOS gives an App Store app no fork/exec and no /bin/sh, so the Android
// answer — a real rootfs entered through proot — has nothing to enter it with.
// ish-arm64 is an interpreter instead: guest AArch64 dispatched to
// pre-compiled native gadgets, no machine code written at runtime, and no
// guest binary ever handed to the kernel. See local-ssh-plan.md, stage 4.
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

/// Boots the guest and runs [command] in it, with [rootfs] as its filesystem.
///
/// Returns 0, or a negative errno. One guest per process: the kernel this
/// links against keeps its state in globals, so a second boot is refused with
/// -EEXIST rather than corrupting the first.
///
/// [rootfs] is a directory in iSH's own format — a `data` tree beside a sqlite
/// metadata db — built by `fakefsify`, not a plain tarball.
SBM_ISH_EXPORT int sbm_ish_boot(const char *rootfs, const char *command, int columns, int rows);

/// Reads what the guest has printed, waiting up to [timeout_ms] for the first
/// byte. Returns the number of bytes, 0 on timeout, or -1 once the guest has
/// exited and its output has been drained.
SBM_ISH_EXPORT int sbm_ish_read(char *buffer, int length, int timeout_ms);

/// Types [length] bytes at the guest.
SBM_ISH_EXPORT int sbm_ish_write(const char *buffer, int length);

/// Tells the guest its terminal changed size.
SBM_ISH_EXPORT void sbm_ish_resize(int columns, int rows);

/// The guest's exit status, or -1 while it is still running.
SBM_ISH_EXPORT int sbm_ish_exit_code(void);

#ifdef __cplusplus
}
#endif

#endif // SBM_ISH_H
