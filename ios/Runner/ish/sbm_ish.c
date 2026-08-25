#include "sbm_ish.h"

#if !SBM_ISH_ENABLED

// The switch is off: no engine is linked, so there is nothing here to call
// into. Every entry point answers the same way it would on a platform that
// never had one, which is what the Dart side is already written against.

bool sbm_ish_available(void) { return false; }

int sbm_ish_boot(const char *rootfs, const char *profile) {
    (void)rootfs; (void)profile; return -1;
}
int sbm_ish_attach(const char *profile) { (void)profile; return -1; }
int sbm_ish_detach(const char *profile) { (void)profile; return -1; }
int sbm_ish_sessions(const char *profile) { (void)profile; return 0; }
int sbm_ish_open(const char *profile, const char *shell, const char *command,
                 const char *environment, int columns, int rows) {
    (void)profile; (void)shell; (void)command; (void)environment;
    (void)columns; (void)rows;
    return -1;
}
int sbm_ish_read(int session, char *buffer, int length, int timeout_ms) {
    (void)session; (void)buffer; (void)length; (void)timeout_ms;
    return -1;
}
int sbm_ish_write(int session, const char *buffer, int length) {
    (void)session; (void)buffer; (void)length;
    return -1;
}
void sbm_ish_resize(int session, int columns, int rows) {
    (void)session; (void)columns; (void)rows;
}
int sbm_ish_exit_code(int session) { (void)session; return -1; }
void sbm_ish_close(int session) { (void)session; }

#else

#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <syslog.h>
#include <sqlite3.h>
#include <unistd.h>

#include "kernel/calls.h"
#include "kernel/init.h"
#include "kernel/task.h"
#include "fs/dev.h"
#include "fs/devices.h"
#include "fs/fd.h"
#include "fs/path.h"
#include "fs/fake-db.h"
#include "fs/real.h"
#include "fs/tty.h"

// `kernel/uname.c` defines it and no header declares it. The engine's own
// tests reach it this way too.
extern const char *uname_hostname_override;

// — Surviving a guest fault ————————————————————————————————————————
//
// Not optional, and not the same handler a command-line iSH installs. The
// interpreter recovers from a guest segfault by unwinding the block it was in,
// which it can only do from a signal handler; without one the first guest
// fault kills the process. Embedded, "the process" is the whole app, so this
// one also has to keep its hands off threads that are not the guest's — a
// handler that intercepts a crash on Dart's or UIKit's thread turns somebody
// else's bug into ours.
//
// The shape is OpenMinis' `ISHKernel.m`, which is the same engine shipping in
// an app. The offsets below are `cpu-offsets.h` values and must match it.

extern __thread volatile sig_atomic_t in_jit;
extern __thread volatile uint64_t jit_saved_pc;
extern __thread int ish_thread_marker;
extern void jit_crash_trampoline(void);
extern void (*die_handler)(const char *msg);

#define CPU_OFFSET_pc 272
#define CPU_OFFSET_segfault_addr 832
#define CPU_OFFSET_segfault_was_write 840
#define CPU_OFFSET_jit_exit_sp 920

static void guest_crash_handler(int signal_number, siginfo_t *info, void *context) {
#ifdef __aarch64__
    if ((signal_number == SIGSEGV || signal_number == SIGBUS) && in_jit) {
        ucontext_t *uc = (ucontext_t *)context;
        uint64_t cpu = uc->uc_mcontext->__ss.__x[1];
        uint64_t x7 = uc->uc_mcontext->__ss.__x[7];
        uint64_t x10 = uc->uc_mcontext->__ss.__x[10];

        *(uint64_t *)(cpu + CPU_OFFSET_segfault_addr) = (x7 - x10) & 0xffffffffffffULL;
        *(int *)(cpu + CPU_OFFSET_segfault_was_write) =
            (uc->uc_mcontext->__es.__esr & 0x40) != 0;
        *(uint64_t *)(cpu + CPU_OFFSET_pc) = (uint64_t)jit_saved_pc;
        uc->uc_mcontext->__ss.__sp = *(uint64_t *)(cpu + CPU_OFFSET_jit_exit_sp);
        uc->uc_mcontext->__ss.__pc = (uint64_t)jit_crash_trampoline;

        sigset_t unblock;
        sigemptyset(&unblock);
        sigaddset(&unblock, signal_number);
        sigprocmask(SIG_UNBLOCK, &unblock, NULL);
        return;
    }
#else
    (void)info;
#endif
    // Not a guest thread at all. Put the default handler back and re-raise, so
    // whatever crashed is reported as itself rather than swallowed here.
    if (!ish_thread_marker) {
        struct sigaction restore = {0};
        restore.sa_handler = SIG_DFL;
        sigaction(signal_number, &restore, NULL);
        raise(signal_number);
        return;
    }
    // A guest thread, outside the interpreter. Standalone iSH exits here;
    // exiting would take the app with it, so the thread is parked instead.
    // `pthread_exit` is not an option: on iOS it raises SIGTRAP from some
    // thread states, which is the crash this is avoiding.
    //
    // Said out loud first. A parked thread is silent by construction, and a
    // silent app that has stopped answering is the hardest thing here to tell
    // apart from a deadlock — which is exactly what it looked like.
    syslog(LOG_ERR, "sbm_ish: guest thread parked after signal %d at %p",
           signal_number, info->si_addr);
    sigset_t all;
    sigfillset(&all);
    pthread_sigmask(SIG_BLOCK, &all, NULL);
    select(0, NULL, NULL, NULL, NULL);
}

/// What `die()` does when the app must not go with it.
static void park_on_die(const char *message) {
    syslog(LOG_ERR, "sbm_ish: die(%s)", message == NULL ? "" : message);
    sigset_t all;
    sigfillset(&all);
    pthread_sigmask(SIG_BLOCK, &all, NULL);
    select(0, NULL, NULL, NULL, NULL);
}

static void install_crash_handler(void) {
    static char alternate_stack[SIGSTKSZ];
    stack_t stack = { .ss_sp = alternate_stack, .ss_size = SIGSTKSZ };
    sigaltstack(&stack, NULL);

    struct sigaction action = {0};
    action.sa_sigaction = guest_crash_handler;
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
    sigaction(SIGSEGV, &action, NULL);
    sigaction(SIGBUS, &action, NULL);
    sigaction(SIGILL, &action, NULL);
    sigaction(SIGTRAP, &action, NULL);
    // Not SIGABRT: the system uses it for assertions and allocation failures,
    // and taking it over hides those.
}

// — Sessions ————————————————————————————————————————————————————————
//
// A session is a process in the machine with a pseudo-terminal of its own.
// There is one machine per app process — the kernel's state is in globals —
// but a machine runs as many processes as it is asked to, and giving each its
// own pty is what keeps a terminal's output and a one-shot command's from
// arriving on the same wire.
//
// Output is a ring buffer per session rather than a pipe, because a guest's
// write must never block on nobody reading: a terminal on a page that is off
// screen is exactly that, and a blocked write inside the interpreter stops the
// whole guest. Overrunning drops the oldest bytes, which is what scrollback
// does anyway.

#define SBM_MAX_SESSIONS 8
#define SBM_OUTPUT_CAPACITY (256 * 1024)

struct session {
    bool used;
    struct tty *tty;
    pid_t_ pid;
    /// Which system it is running in, so that taking that system down can end
    /// what is inside it. Deleting one used to leave its processes running and
    /// holding its `/dev/pts`, which is why the unmount answered `_EBUSY`.
    char profile[64];
    int exit_code;
    char data[SBM_OUTPUT_CAPACITY];
    size_t head, tail;
};

static struct session sessions[SBM_MAX_SESSIONS];
static pthread_mutex_t sessions_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t sessions_wrote = PTHREAD_COND_INITIALIZER;

static pid_t_ close_session(int session_id, const char *profile);

/// The session a tty belongs to, or -1. Called from the guest's threads.
static int session_of(struct tty *tty) {
    for (int i = 0; i < SBM_MAX_SESSIONS; i++)
        if (sessions[i].used && sessions[i].tty == tty) return i;
    return -1;
}

// — What a session prints ————————————————————————————————————————————

static int console_init(struct tty *tty) { (void)tty; return 0; }
static int console_open(struct tty *tty) { (void)tty; return 0; }
static int console_close(struct tty *tty) { (void)tty; return 0; }
static void console_cleanup(struct tty *tty) { (void)tty; }

static int console_write(struct tty *tty, const void *buffer, size_t length, bool blocking) {
    (void)blocking;
    pthread_mutex_lock(&sessions_lock);
    int index = session_of(tty);
    if (index < 0) {
        pthread_mutex_unlock(&sessions_lock);
        // Written by a session that has been closed. Dropped, not an error:
        // the guest is entitled to finish a line nobody is reading.
        return (int)length;
    }
    struct session *session = &sessions[index];
    const char *bytes = buffer;
    for (size_t i = 0; i < length; i++) {
        size_t next = (session->head + 1) % SBM_OUTPUT_CAPACITY;
        if (next == session->tail)
            session->tail = (session->tail + 1) % SBM_OUTPUT_CAPACITY;
        session->data[session->head] = bytes[i];
        session->head = next;
    }
    pthread_cond_broadcast(&sessions_wrote);
    pthread_mutex_unlock(&sessions_lock);
    return (int)length;
}

static const struct tty_driver_ops console_ops = {
    .init = console_init,
    .open = console_open,
    .close = console_close,
    .write = console_write,
    .cleanup = console_cleanup,
};

// One driver, many ttys: `pty_open_fake` points it at the pty slave table and
// hands back a tty per session.
static struct tty *sbm_pty_ttys[SBM_MAX_SESSIONS];
struct tty_driver sbm_pty_driver = {
    .ops = &console_ops,
    .major = TTY_PSEUDO_SLAVE_MAJOR,
    .ttys = sbm_pty_ttys,
    .limit = SBM_MAX_SESSIONS,
};

/// Points a session's fds 0, 1 and 2 at its own pty.
///
/// Not `create_stdio`, which stood here and was the second of the two reasons
/// `tty` answered "not a tty". It opens the path and then requires
/// `S_ISCHR(fd->stat.mode)` — but `fd->stat` is the adhoc filesystem's own copy
/// of a stat (`fs/fd.h`), and `generic_openat` fills `fd->type` instead. A
/// devpts fd comes from `fd_create`, which zeroes the struct, so that test was
/// false however well the open went, and the fallback was taken every time.
///
/// The first reason was that the open never succeeded at all: the engine's
/// mount lookup answered with `/dev` for a path under `/dev/pts` — see
/// `scripts/ish-patches/0001-…`, which is why the fix is not only here.
///
/// Either one alone was enough. Output still reached the driver through the
/// adhoc fd, which is why sessions worked and why this took a `tty` call to
/// find; but that fd is in none of the tables procfs lists, so `/dev/stdout`
/// and its siblings resolved to nothing and `isatty` did not know it.
///
/// Opening the slave properly has a second effect worth naming: `generic_openat`
/// routes a char device through `dev_open`, and `tty_open` claims a controlling
/// terminal for a session leader — which every task from `become_new_init_child`
/// is, since `construct_task` calls `task_setsid`. That is what makes `/dev/tty`,
/// job control and Ctrl-C reach the right process group. It also means the tty
/// is released when the session's last fd closes, which the adhoc fd never did.
static int attach_stdio(struct tty *tty) {
    char slave[64];
    snprintf(slave, sizeof(slave), "/dev/pts/%d", tty->num);

    struct fd *fd = generic_open(slave, O_RDWR_, 0);
    if (!IS_ERR(fd) && !S_ISCHR(fd->type)) {
        fd_close(fd);
        fd = ERR_PTR(_ENOTTY);
    }
    if (IS_ERR(fd)) {
        // Said out loud. A session whose stdio is an adhoc fd still runs, so
        // this degrades rather than fails — and a silent degradation is exactly
        // what hid the problem above until something called `tty`.
        syslog(LOG_ERR, "sbm_ish: %s did not open (%d); stdio is adhoc, so "
               "isatty and /dev/stdout will not work in this session",
               slave, (int)PTR_ERR(fd));
        return create_stdio(slave, TTY_PSEUDO_SLAVE_MAJOR, tty->num);
    }

    // One open, three descriptors, as `create_stdio` does it: the count is
    // reset because `generic_open` handed over a reference this table is not
    // going to hold separately.
    fd->refcount = 0;
    current->files->files[0] = fd_retain(fd);
    current->files->files[1] = fd_retain(fd);
    current->files->files[2] = fd_retain(fd);
    return 0;
}

// — Booting ————————————————————————————————————————————————————————

static bool booted;
static char *rootfs_path;

static void guest_exited(struct task *task, int code) {
    // `code` is the raw wait(2) status word, and only a normal exit puts the
    // code in the high byte: a guest killed by a signal carries the signal in
    // the low 7 bits and nothing above them (`kernel/exit.c` calls
    // `do_exit_group(sig)` for that, against `do_exit(status << 8)` for
    // `_exit`). So `code >> 8` alone answered 0 for every death by signal —
    // indistinguishable from success, which is what `ExecResult.exitCode == 0`
    // means to every caller on the Dart side.
    //
    // 128 + signal is what a shell reports for the same thing, so a caller
    // that already knows what 143 means needs no telling. It also stays
    // positive, which this field requires: `sbm_ish_exit_code` answers with a
    // negative value while a session is still running, and Dart reads that as
    // "no exit code yet".
    //
    // Masked with 0x7f rather than 0xff because 0x80 is the core-dump bit.
    // Nothing in iSH sets it today, so the two agree; the narrower mask is the
    // one that keeps agreeing if that changes.
    int status = (code & 0x7f) ? 128 + (code & 0x7f) : code >> 8;
    pthread_mutex_lock(&sessions_lock);
    for (int i = 0; i < SBM_MAX_SESSIONS; i++) {
        if (sessions[i].used && sessions[i].pid == task->pid) {
            sessions[i].exit_code = status;
            break;
        }
    }
    pthread_cond_broadcast(&sessions_wrote);
    pthread_mutex_unlock(&sessions_lock);
}

/// A filesystem for `/dev`, and the one place a database earns its keep.
///
/// Nothing else can hold a device node. `realfs` refuses — creating one needs
/// root on the host — and `tmpfs` has no `mknod` at all. `fakefs` can, because
/// it keeps `rdev` in sqlite, which is exactly the thing the *root* filesystem
/// no longer does. A dozen nodes is a database of a few kilobytes, built once
/// and next to nothing to carry; the whole tree's metadata was the part worth
/// refusing.
///
/// Only the root row is written here. The nodes themselves are created through
/// the kernel afterwards, so how a path is spelled in that table stays the
/// kernel's business rather than something this file has to guess.
///
/// TODO: delete the schema and the root row below in favour of the engine's
/// `fake_db_create(dir)` (`kernel/fs.h`), which writes both from the one copy
/// in `fs/fake-schema.c` that `tools/fakefsify` also uses. Compared against it:
/// the directory modes agree (0755), nothing else goes into `meta.db`, and the
/// `pragma journal_mode=wal` here is redundant because `fake_db_init` sets it
/// on every mount. Keep the `access()` guard when switching — `fake_db_create`
/// runs bare `create table`, so a second call on an existing database fails.
/// Waiting on ShellBox PR #10 (`feat/sbm-api-harness`); the function does not
/// exist at the current gitlink.
static int make_dev_db(const char *profile, char *data_out, size_t data_len) {
    char dir[MAX_PATH];
    // Beside the tree it belongs to, so that deleting a profile takes its
    // `/dev` with it rather than leaving a database nothing will ever mount.
    snprintf(dir, sizeof(dir), "%s/%s/.dev", rootfs_path, profile);
    mkdir(dir, 0755);
    snprintf(data_out, data_len, "%s/data", dir);
    mkdir(data_out, 0755);

    char db_path[MAX_PATH];
    snprintf(db_path, sizeof(db_path), "%s/meta.db", dir);
    if (access(db_path, F_OK) == 0) return 0;

    sqlite3 *db;
    if (sqlite3_open_v2(db_path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL) != SQLITE_OK) {
        syslog(LOG_ERR, "sbm_ish: could not create %s", db_path);
        return -EIO;
    }
    // The schema `fakefsify` writes, and the version `fake_db_init` expects to
    // find so it does not try to migrate one that was never older.
    static const char *schema =
        "pragma journal_mode=wal;"
        "create table meta (id integer unique default 0, db_inode integer);"
        "insert into meta (db_inode) values (0);"
        "create table stats (inode integer primary key, stat blob);"
        "create table paths (path blob primary key, inode integer references stats(inode));"
        "create index inode_to_path on paths (inode, path);"
        "pragma user_version=3;";
    char *message = NULL;
    if (sqlite3_exec(db, schema, NULL, NULL, &message) != SQLITE_OK) {
        syslog(LOG_ERR, "sbm_ish: /dev schema: %s", message == NULL ? "?" : message);
        sqlite3_close(db);
        unlink(db_path);
        return -EIO;
    }

    // The root of that filesystem, which has to exist before it can be mounted.
    struct ish_stat root = { .mode = S_IFDIR | 0755, .uid = 0, .gid = 0, .rdev = 0 };
    sqlite3_stmt *statement;
    sqlite3_prepare_v2(db, "insert into stats (stat) values (?)", -1, &statement, NULL);
    sqlite3_bind_blob(statement, 1, &root, sizeof(root), SQLITE_TRANSIENT);
    sqlite3_step(statement);
    sqlite3_finalize(statement);
    sqlite3_prepare_v2(db, "insert or replace into paths values ('', last_insert_rowid())", -1, &statement, NULL);
    sqlite3_step(statement);
    sqlite3_finalize(statement);
    sqlite3_close(db);
    return 0;
}

/// Everything a userland expects to find at `/dev`, for one profile.
///
/// Paths are spelled from the *machine* root — `/alpine/dev`, not `/dev` —
/// because this runs as init, which lives at the machine root and mounts for
/// every profile. A session sees them as `/dev`, since it is rooted at its own
/// subtree. Doing it by prefix rather than by chrooting init keeps this off any
/// path where two profiles being attached at once could see each other's root.
/// Returns 0, or a negative errno if the system has no usable `/dev`.
///
/// Only the two steps everything below rests on are reported: the database and
/// the mount that makes it `/dev`. A `mknod` that fails leaves one node
/// missing, which is a worse `/dev` rather than an absent one; a failed mount
/// leaves an empty directory that every path below writes into the *host*
/// tree instead.
static int make_dev(const char *profile) {
    char path[MAX_PATH];
#define GUEST(...) (snprintf(path, sizeof(path), __VA_ARGS__), path)

    // The mount point first: a minirootfs unpacked without root may have no
    // `/dev` at all, since the device nodes in the tarball are what create it.
    generic_mkdirat(AT_PWD, GUEST("/%s/dev", profile), 0755);

    char data_path[MAX_PATH];
    int err = make_dev_db(profile, data_path, sizeof(data_path));
    if (err < 0) return err;
    err = do_mount(&fakefs, data_path, GUEST("/%s/dev", profile), "", 0);
    if (err < 0) {
        syslog(LOG_ERR, "sbm_ish: %s has no /dev (%d)", profile, err);
        return err;
    }

    generic_mknodat(AT_PWD, GUEST("/%s/dev/null", profile), S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_NULL_MINOR));
    generic_mknodat(AT_PWD, GUEST("/%s/dev/zero", profile), S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_ZERO_MINOR));
    generic_mknodat(AT_PWD, GUEST("/%s/dev/full", profile), S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_FULL_MINOR));
    generic_mknodat(AT_PWD, GUEST("/%s/dev/random", profile), S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_RANDOM_MINOR));
    generic_mknodat(AT_PWD, GUEST("/%s/dev/urandom", profile), S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_URANDOM_MINOR));
    generic_mknodat(AT_PWD, GUEST("/%s/dev/tty", profile), S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_TTY_MINOR));
    generic_mknodat(AT_PWD, GUEST("/%s/dev/console", profile), S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_CONSOLE_MINOR));
    generic_mknodat(AT_PWD, GUEST("/%s/dev/ptmx", profile), S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_PTMX_MINOR));

    // Where the pty slaves appear. Its mount point has to exist first, since
    // `/dev` is a filesystem that was empty a moment ago.
    //
    // Checked like the `/dev` mount above: a session is a pty, so a system
    // without this is one whose terminal cannot open. Discarding the result
    // let the attach report success and left the failure to be met later, as
    // a shell that would not start.
    generic_mkdirat(AT_PWD, GUEST("/%s/dev/pts", profile), 0755);
    err = do_mount(&devptsfs, "devpts", GUEST("/%s/dev/pts", profile), "", 0);
    if (err < 0) {
        syslog(LOG_ERR, "sbm_ish: %s has no /dev/pts (%d)", profile, err);
        return err;
    }

    // Not device nodes but expected to be there, and cheap to be right about:
    // a shell's `>/dev/stdout`, a script's `/dev/fd/3`, and anything that
    // writes to `/dev/shm` all fail without them.
    // The *targets* keep no prefix: they are followed from inside the session,
    // which is rooted at this profile, so `/proc/self/fd` is already its own.
    generic_symlinkat("/proc/self/fd", AT_PWD, GUEST("/%s/dev/fd", profile));
    generic_symlinkat("/proc/self/fd/0", AT_PWD, GUEST("/%s/dev/stdin", profile));
    generic_symlinkat("/proc/self/fd/1", AT_PWD, GUEST("/%s/dev/stdout", profile));
    generic_symlinkat("/proc/self/fd/2", AT_PWD, GUEST("/%s/dev/stderr", profile));
    // A directory, where a `tmpfs` would be the obvious choice. `tmpfs_umount`
    // is unimplemented in the engine — `fs/tmp.c` answers it with
    // `TODO("tmpfs umount")`, which is `die()` — and this app's `die_handler`
    // parks the calling thread with every signal blocked rather than letting
    // `abort()` take the app. The thread that detaches a system is the one
    // running Dart, so mounting one here froze the whole app the first time a
    // system was detached, with no crash and nothing in the log.
    //
    // Nothing is lost that a caller can see: `/dev` is a fakefs over an
    // ordinary directory, so a 01777 directory inside it is writable by
    // everything that expects `/dev/shm` to be. The difference is that what is
    // written there is on disk rather than in memory, and goes when the system
    // does rather than when the app does.
    generic_mkdirat(AT_PWD, GUEST("/%s/dev/shm", profile), 01777);
#undef GUEST
    return 0;
}

/// Which profiles have had their filesystems mounted, so that mounting is done
/// once and asking is cheap.
///
/// A fixed table rather than a list: the count is the number of Linux systems
/// a person keeps on a phone, and a bounded array cannot fail to allocate on
/// the path that opens a terminal.
#define SBM_MAX_PROFILES 8
static char attached[SBM_MAX_PROFILES][64];
static pthread_mutex_t attached_lock = PTHREAD_MUTEX_INITIALIZER;

/// Whether `profile` names a directory directly under the machine root.
///
/// `..` matters here as much as `/` does, and is the reason this is one
/// function rather than a check repeated at each entry point: every path below
/// is built as `/<profile>/...`, and `..` normalizes that straight back to the
/// machine root — reaching outside the container without ever writing a slash.
/// `.` resolves to the container itself, which is not a system either.
static int check_profile(const char *profile) {
    if (profile == NULL || profile[0] == '\0') return -EINVAL;
    if (strchr(profile, '/') != NULL) return -EINVAL;
    if (strcmp(profile, ".") == 0 || strcmp(profile, "..") == 0) return -EINVAL;
    if (strlen(profile) >= sizeof(attached[0])) return -ENAMETOOLONG;
    return 0;
}

static bool is_attached(const char *profile) {
    for (int i = 0; i < SBM_MAX_PROFILES; i++)
        if (strcmp(attached[i], profile) == 0) return true;
    return false;
}

/// Everything [sbm_ish_attach] and [make_dev] mount, innermost first:
/// `/dev/pts` is inside `/dev`, and the outer one cannot go while it holds it.
///
/// `dev/shm` is not here because nothing mounts one any more — see [make_dev].
/// It was, and unmounting it is what froze the app.
static const char *const mount_points[] = { "dev/pts", "dev", "proc" };

/// Takes one profile's filesystems down. Returns 0, or the first real failure.
///
/// `do_umount` answers `_EINVAL` for a point that carries nothing and `_EBUSY`
/// while something still holds one — those are its only two errors. The first
/// is not a failure here: an attach may have stopped partway, and unmounting
/// twice has to be safe.
///
/// The constants in `kernel/errno.h` are already negative, so this compares
/// against `_EINVAL` rather than negating it. Negating gave `+22`, which no
/// error equals, and the exemption never applied — every detach of a profile
/// whose mounts were not all present reported failure.
static int unmount_profile(const char *profile) {
    char path[MAX_PATH];
    int err = 0;
    for (size_t i = 0; i < sizeof(mount_points) / sizeof(mount_points[0]); i++) {
        snprintf(path, sizeof(path), "/%s/%s", profile, mount_points[i]);
        int one = do_umount(path);
        if (one < 0 && one != _EINVAL) {
            // Which one, because the caller's error says only that something
            // would not go. `_EBUSY` means a reference is still out on that
            // mount, and which mount it is says who is holding it.
            syslog(LOG_ERR, "sbm_ish: %s will not unmount (%d)", path, one);
            if (err == 0) err = one;
        }
    }
    return err;
}

/// Points `current` at one profile's subtree, the way `chroot` would.
///
/// Safe to do to a task from `become_new_init_child`: `construct_task` gives
/// each one its own `fs_info` (`kernel/init.c:107`) rather than sharing init's,
/// so nothing else sees this.
static int enter_profile(const char *profile) {
    char path[MAX_PATH];
    snprintf(path, sizeof(path), "/%s", profile);
    struct fd *dir = generic_open(path, O_RDONLY_, 0);
    if (IS_ERR(dir)) return (int)PTR_ERR(dir);
    lock(&current->fs->lock);
    fd_close(current->fs->root);
    current->fs->root = dir;
    unlock(&current->fs->lock);

    // The working directory too. It still points at the machine root, which is
    // no longer a place this task can name — every relative path would resolve
    // outside its own filesystem.
    struct fd *pwd = generic_open("/", O_RDONLY_, 0);
    if (IS_ERR(pwd)) return (int)PTR_ERR(pwd);
    fs_chdir(current->fs, pwd);
    return 0;
}

bool sbm_ish_available(void) { return true; }

/// Mounts one profile's filesystems. Idempotent, and the only thing that has
/// to happen before a session can be opened in it.
///
/// Separate from [sbm_ish_boot] because the machine is one and the profiles are
/// many: the kernel starts once, and each system is attached to it the first
/// time something wants a terminal in it.
int sbm_ish_attach(const char *profile) {
    if (!booted) return -ENOTCONN;
    int checked = check_profile(profile);
    if (checked < 0) return checked;

    pthread_mutex_lock(&attached_lock);
    if (is_attached(profile)) {
        pthread_mutex_unlock(&attached_lock);
        return 0;
    }
    int slot = -1;
    for (int i = 0; i < SBM_MAX_PROFILES; i++)
        if (attached[i][0] == '\0') { slot = i; break; }
    if (slot < 0) {
        pthread_mutex_unlock(&attached_lock);
        return -EMFILE;
    }

    // Anything still mounted here is left over from an attempt that failed or
    // from a detach that could not finish — this profile is not in the table,
    // so nothing considers it attached. `do_mount` does not ask whether a
    // point already carries a mount and would stack a second one on top, one
    // per attempt, with only the innermost reachable to unmount. Refuse rather
    // than stack: a point that will not go is `_EBUSY`, and mounting over
    // whatever is holding it would hide that.
    int stale = unmount_profile(profile);
    if (stale < 0) {
        // Something is holding one of them, which is `_EBUSY` and means the
        // system is live: mounted, and with a process still in it. Record it
        // and answer 0 rather than mounting a second set over the first.
        //
        // Not a refusal, which is what this did at first and what turned a
        // recoverable state into a permanent one — a profile whose mounts
        // could not be swept could never be opened again, for the life of the
        // process. If the sweep took some of them down before meeting the one
        // that would not go, this leaves a system missing those; that is a
        // worse system, where refusing was no system at all.
        snprintf(attached[slot], sizeof(attached[slot]), "%s", profile);
        pthread_mutex_unlock(&attached_lock);
        syslog(LOG_ERR, "sbm_ish: %s still has mounts in use (%d); taken as "
               "attached rather than mounted over", profile, stale);
        return 0;
    }

    char path[MAX_PATH];
    // `/proc` first: `/dev/stdout` and friends are symlinks into it, and a
    // shell following one before it is mounted gets "nonexistent directory".
    snprintf(path, sizeof(path), "/%s/proc", profile);
    generic_mkdirat(AT_PWD, path, 0755);
    int err = do_mount(&procfs, "proc", path, "", 0);
    if (err < 0) {
        // Same rollback as below, and for the same reason: nothing recorded
        // the profile yet, so what this mounted has to go back before the
        // next attach reaches the sweep at the top.
        syslog(LOG_ERR, "sbm_ish: %s has no /proc (%d)", profile, err);
        unmount_profile(profile);
        pthread_mutex_unlock(&attached_lock);
        return err;
    }
    // Recorded only once the system is actually mounted. Attaching is
    // idempotent by name, so a half-built profile written here is one nothing
    // ever retries: every later attach sees the name and returns 0, and the
    // session opens onto a `/dev` that was never mounted.
    err = make_dev(profile);
    if (err < 0) {
        // What was mounted above goes back with it. If it will not, say so and
        // leave it: the profile is not recorded either way, so the next attach
        // reaches the rollback above and tries again before mounting anything.
        int undone = unmount_profile(profile);
        if (undone < 0) {
            syslog(LOG_ERR, "sbm_ish: %s did not roll back (%d); its mounts stay "
                   "until an attach can take them down", profile, undone);
        }
        pthread_mutex_unlock(&attached_lock);
        return err;
    }

    snprintf(attached[slot], sizeof(attached[slot]), "%s", profile);
    pthread_mutex_unlock(&attached_lock);
    return 0;
}

/// Unmounts one system's filesystems and forgets it.
///
/// Returns 0, or a negative errno. Needed because [sbm_ish_attach] is
/// idempotent by name: without this, deleting a system or reinstalling one in
/// place left the name attached, so the next attach did nothing and the fresh
/// tree was handed the previous one's `/dev` — a fakefs whose database had been
/// deleted along with the old directory. It also frees the slot, which is one
/// of eight.
///
/// `do_umount` answers `EBUSY` while anything still holds the mount, and this
/// reports that rather than forcing it: a session still running in the system
/// is a reason not to pull its `/dev` out from under it. The caller closes
/// those first.
///
/// An unbooted machine answers 0, not an error. What this promises is that the
/// profile is not mounted afterwards, and a kernel that never started has
/// nothing mounted in it — the promise is already kept. Answering `-ENOTCONN`
/// there read as a failure to the one caller that matters: deleting a system
/// that had been installed but never opened became impossible, because the
/// delete waits for a detach that could only ever fail. Reported from a device
/// as "The Linux system is still in use (-57)", which is `-ENOTCONN` on Darwin
/// and says nothing about anything being in use.
int sbm_ish_sessions(const char *profile) {
    if (!booted) return 0;
    if (check_profile(profile) < 0) return 0;
    int count = 0;
    pthread_mutex_lock(&sessions_lock);
    for (int i = 0; i < SBM_MAX_SESSIONS; i++) {
        if (sessions[i].used && strcmp(sessions[i].profile, profile) == 0)
            count++;
    }
    pthread_mutex_unlock(&sessions_lock);
    return count;
}

int sbm_ish_detach(const char *profile) {
    if (!booted) return 0;
    int checked = check_profile(profile);
    if (checked < 0) return checked;

    // The unmounts under the lock as well as the slot, because the two are one
    // decision. `sbm_ish_attach` holds it across its own mounts and answers 0
    // for a name it finds in the table — so with the unmounts outside it, an
    // attach running alongside this reads the name as still attached, returns
    // without mounting anything, and hands back a system whose filesystems are
    // being pulled out underneath it.
    // What is running in it goes first. Nothing else ends these: closing a
    // terminal tab closes *that* session, and deleting a system from the
    // settings page closes none — so the shell carried on holding the pty that
    // keeps `/dev/pts` busy, every unmount answered `_EBUSY`, and the delete
    // that followed took the tree out from under a live mount.
    //
    // Read from the device as `session 0 pid 2 used=1 task=alive`, at the
    // moment a system whose terminal had been closed refused to detach.
    //
    // Signalled, not waited for: the caller retries, which is where the time
    // for a shell to take SIGHUP and exit belongs — this holds `attached_lock`.
    for (int i = 0; i < SBM_MAX_SESSIONS; i++) close_session(i, profile);

    pthread_mutex_lock(&attached_lock);
    int err = unmount_profile(profile);

    // The name stays when the unmounts did not all take. `_EBUSY` is what
    // `do_umount` answers while something still holds a mount, so a detach
    // that fails that way has left the system mounted and *in use* — the
    // truest thing the table can then say is that it is attached.
    //
    // Clearing it regardless was tried and was worse. Closing a terminal only
    // hangs its process up, and the task is not reaped, so a `/dev/pts` it
    // held can still be busy when the system is deleted a moment later. That
    // detach failed, the name went anyway, and every later attach found
    // mounts it could not take down and refused — the system could not be
    // opened again for the life of the process, and only restarting the app
    // cleared it. Reported from a device as a terminal that printed
    // "Execute: Shell" and then nothing.
    if (err == 0) {
        for (int i = 0; i < SBM_MAX_PROFILES; i++) {
            if (strcmp(attached[i], profile) == 0) { attached[i][0] = '\0'; break; }
        }
    }
    pthread_mutex_unlock(&attached_lock);

    if (err < 0) {
        syslog(LOG_ERR, "sbm_ish: %s did not detach (%d); it stays attached, "
               "because what would not unmount is still in use", profile, err);
        // Who is holding it. `sbm_ish_close` leaves `pid` behind when it
        // clears `used`, so this can say whether the process a closed session
        // hung up has actually gone — a task that is still there is still
        // holding the pty that keeps `/dev/pts` busy.
        pthread_mutex_lock(&sessions_lock);
        for (int i = 0; i < SBM_MAX_SESSIONS; i++) {
            if (sessions[i].pid == 0) continue;
            struct task *task = pid_get_task(sessions[i].pid);
            syslog(LOG_ERR, "sbm_ish:   session %d pid %d used=%d task=%s",
                   i, sessions[i].pid, sessions[i].used,
                   task == NULL ? "gone" : "alive");
        }
        pthread_mutex_unlock(&sessions_lock);
    }
    return err;
}

int sbm_ish_boot(const char *rootfs, const char *profile) {
    if (rootfs == NULL || profile == NULL || profile[0] == '\0') return -EINVAL;
    if (booted) return -EEXIST;

    install_crash_handler();
    // Otherwise `die()` calls abort(), and the app goes with the guest.
    die_handler = park_on_die;

    // What the guest answers to `uname -n`, and so what its prompt shows.
    // Without this it is the host's nodename, which on iOS is the device name:
    // something the user typed, usually containing their own, and reaching the
    // guest's environment and anything it writes out. It is also not a
    // hostname — the field is 65 bytes and `do_uname` truncates to fit, so a
    // name with any multi-byte character in the wrong place is cut mid-
    // codepoint and shows up as replacement marks.
    //
    // One value for the machine rather than one per system: the kernel is
    // shared, and this is a single global in it.
    uname_hostname_override = "serverbox";

    // An ordinary directory tree, mounted by `realfs`: guest paths resolved
    // against a root fd, with nothing stored beside them. Installing a
    // userland is therefore unpacking a tarball, which an app can do.
    rootfs_path = strdup(rootfs);
    int err = mount_root(&realfs, rootfs_path);
    if (err < 0) return err;

    err = become_first_process();
    if (err < 0) return err;
    current->thread = pthread_self();

    // A working directory, before anything is created relative to one.
    // `generic_mknodat(AT_PWD, ...)` resolves against it, and without it every
    // node below is created against nothing — measured as a `/dev` that
    // mounted and stayed empty, with `head: /dev/urandom: No such file`.
    struct fd *root_fd = generic_open("/", O_RDONLY_, 0);
    if (IS_ERR(root_fd)) return (int)PTR_ERR(root_fd);
    fs_chdir(current->fs, root_fd);

    exit_hook = guest_exited;

    // The machine is up from here, which is what `sbm_ish_attach` requires.
    booted = true;
    err = sbm_ish_attach(profile);
    if (err < 0) { booted = false; return err; }

    // Init lives inside a profile rather than at the machine root, because the
    // machine root is a container of trees and holds no `/bin/sh` to exec —
    // nor the loader that shell names as its interpreter. Which profile is
    // arbitrary: init only sleeps. It keeps an fd to that directory, so
    // deleting the profile later leaves init running against an unlinked
    // directory, which is a thing Unix permits and nothing here reads again.
    err = enter_profile(profile);
    if (err < 0) { booted = false; return err; }

    // Init has to exist and must never exit — `kernel/exit.c` ends the *host
    // process* when it does. It does not have to do anything else, and it must
    // not: a terminal is `sbm_ish_open`, which makes a child of init with a
    // pty of its own, so a shell started here is one nobody can reach.
    //
    // This was `while :; do /bin/sh; done`. Init has no tty and no stdin, so
    // each of those shells read EOF and exited at once and the loop started
    // another — a fork/exec storm, inside an interpreter, for as long as the
    // machine was up. That is what made the whole app slow from the moment
    // Alpine was opened, and closing the last terminal did not stop it,
    // because the machine deliberately stays up.
    //
    // The sleep is wrapped in a loop rather than left bare so that a signal
    // cutting it short cannot end init. 2^31-1 seconds is 68 years; the fork
    // per wakeup is the only work this process ever does.
    char argv[512];
    const char *parts[] = {
        "/bin/sh",
        "-c",
        "while :; do sleep 2147483647; done",
    };
    size_t position = 0;
    for (size_t i = 0; i < 3; i++) {
        size_t length = strlen(parts[i]) + 1;
        memcpy(argv + position, parts[i], length);
        position += length;
    }
    argv[position] = '\0';

    char environment[256] = {0};
    size_t written = 0;
    written += snprintf(environment + written, sizeof(environment) - written, "HOME=/root") + 1;
    written += snprintf(environment + written, sizeof(environment) - written,
                        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin") + 1;

    err = do_execve("/bin/sh", 3, argv, environment);
    if (err < 0) { booted = false; return err; }
    task_start(current);

    return 0;
}

int sbm_ish_open(const char *profile, const char *shell, const char *command,
                 const char *environment, int columns, int rows) {
    if (!booted) return -ENOTCONN;
    // The same check `sbm_ish_sessions` and `sbm_ish_detach` apply. A weaker
    // one here would accept a name those two answer `-EINVAL` for, so a
    // session opened under it would be invisible to both.
    int checked = check_profile(profile);
    if (checked < 0) return checked;

    bool interactive = command == NULL || command[0] == '\0';
    // The guest has no `login` and nothing reads `/etc/passwd`, so which shell
    // a session gets is decided here and nowhere else — which is also why
    // Alpine having no `chsh` does not matter.
    if (shell == NULL || shell[0] == '\0') shell = "/bin/sh";

    pthread_mutex_lock(&sessions_lock);
    int index = -1;
    for (int i = 0; i < SBM_MAX_SESSIONS; i++) {
        if (!sessions[i].used) { index = i; break; }
    }
    if (index < 0) {
        pthread_mutex_unlock(&sessions_lock);
        return -EMFILE;
    }
    struct session *session = &sessions[index];
    memset(session, 0, sizeof(*session));
    session->used = true;
    session->exit_code = -1;
    // Named in the same lock hold that reserves it. `used` is what makes the
    // slot visible to `sbm_ish_sessions` and `close_session`, and both then
    // ask which profile it belongs to — so a slot reserved under an empty name
    // is one that is counted by nobody and hung up by nobody, while the mounts
    // it is about to take are held all the same. What that cost: deleting a
    // system while a terminal in it was opening read as "no sessions", went
    // ahead, and failed at the unmount with `EBUSY`.
    snprintf(session->profile, sizeof(session->profile), "%s", profile);
    pthread_mutex_unlock(&sessions_lock);

    // A task of its own, under init. Everything from here happens as that
    // task, on this thread, until `task_start` gives it one.
    int err = become_new_init_child();
    if (err < 0) goto fail;

    // Before anything opens a path. `attach_stdio` names `/dev/pts/N`, and
    // that has to mean *this* profile's devpts rather than whichever one init
    // happens to be rooted at.
    err = sbm_ish_attach(profile);
    if (err < 0) goto fail;
    err = enter_profile(profile);
    if (err < 0) goto fail;

    struct tty *tty = pty_open_fake(&sbm_pty_driver);
    if (IS_ERR(tty)) { err = (int)PTR_ERR(tty); goto fail; }
    struct winsize_ size = {
        .col = (uint16_t)(columns > 0 ? columns : 80),
        .row = (uint16_t)(rows > 0 ? rows : 25),
    };
    tty_set_winsize(tty, size);

    // A command's output should read like a pipe's. `ServerExec` is "run this
    // and tell me what it said", and a terminal answers with CRLF line endings
    // and an echo of anything written to stdin — two things a caller would have
    // to strip before it could parse a word of it. Set before the task starts,
    // so nothing else can be holding this tty yet.
    if (!interactive) {
        tty->termios.oflags &= ~OPOST_;
        tty->termios.lflags &= ~ECHO_;
    }

    pthread_mutex_lock(&sessions_lock);
    session->tty = tty;
    session->pid = current->pid;
    pthread_mutex_unlock(&sessions_lock);

    err = attach_stdio(tty);
    if (err < 0) goto fail;

    static const char default_environment[] =
        "TERM=xterm-256color\0"
        "HOME=/root\0"
        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\0";
    if (environment == NULL || environment[0] == '\0') {
        environment = default_environment;
    }

    // Built twice at most: a shell the setting names but the guest does not
    // have would otherwise be a terminal that opens and immediately dies, with
    // the reason visible nowhere. The setting is checked before it is stored,
    // so reaching the fallback means the guest changed under it — `apk del`
    // on whatever it named.
    for (int attempt = 0; attempt < 2; attempt++) {
        char argv[4096];
        size_t position = 0;
        const char *parts[3] = { shell, "-c", command };
        int count = interactive ? 1 : 3;
        bool too_long = false;
        for (int i = 0; i < count; i++) {
            size_t length = strlen(parts[i]) + 1;
            if (position + length >= sizeof(argv) - 1) { too_long = true; break; }
            memcpy(argv + position, parts[i], length);
            position += length;
        }
        if (too_long) { err = -E2BIG; goto fail; }
        argv[position] = '\0';

        err = do_execve(shell, count, argv, environment);
        if (err >= 0) break;
        if (attempt == 1 || strcmp(shell, "/bin/sh") == 0) goto fail;
        syslog(LOG_ERR, "sbm_ish: %s did not exec (%d); falling back to /bin/sh",
               shell, err);
        shell = "/bin/sh";
    }
    if (err < 0) goto fail;
    task_start(current);
    return index;

fail:
    // The name goes with the reservation, since the two were taken together.
    pthread_mutex_lock(&sessions_lock);
    session->used = false;
    session->profile[0] = '\0';
    pthread_mutex_unlock(&sessions_lock);
    return err;
}

int sbm_ish_read(int session_id, char *buffer, int length, int timeout_ms) {
    if (buffer == NULL || length <= 0) return -EINVAL;
    if (session_id < 0 || session_id >= SBM_MAX_SESSIONS) return -EINVAL;

    // Tried, not taken. A guest thread that faulted while writing is parked by
    // the crash handler still holding this, and a plain `lock` here would
    // never return — which is indistinguishable from the app having wedged.
    if (pthread_mutex_trylock(&sessions_lock) != 0) {
        struct timespec retry = { .tv_sec = 0, .tv_nsec = 2 * 1000 * 1000 };
        int attempts = 0;
        while (pthread_mutex_trylock(&sessions_lock) != 0) {
            if (++attempts > 50) return -EBUSY;
            nanosleep(&retry, NULL);
        }
    }

    struct session *session = &sessions[session_id];
    if (!session->used) {
        pthread_mutex_unlock(&sessions_lock);
        return -1;
    }
    if (session->head == session->tail && session->exit_code < 0 && timeout_ms > 0) {
        struct timeval now;
        gettimeofday(&now, NULL);
        struct timespec until = {
            .tv_sec = now.tv_sec + timeout_ms / 1000,
            .tv_nsec = now.tv_usec * 1000 + (long)(timeout_ms % 1000) * 1000000,
        };
        if (until.tv_nsec >= 1000000000) { until.tv_sec += 1; until.tv_nsec -= 1000000000; }
        pthread_cond_timedwait(&sessions_wrote, &sessions_lock, &until);
    }

    int count = 0;
    while (count < length && session->tail != session->head) {
        buffer[count++] = session->data[session->tail];
        session->tail = (session->tail + 1) % SBM_OUTPUT_CAPACITY;
    }
    // Told apart from "nothing yet": a caller looping on this needs to know
    // the difference between a quiet session and a finished one.
    bool ended = count == 0 && session->exit_code >= 0;
    pthread_mutex_unlock(&sessions_lock);
    return ended ? -1 : count;
}

int sbm_ish_write(int session_id, const char *buffer, int length) {
    if (buffer == NULL || length <= 0) return -EINVAL;
    if (session_id < 0 || session_id >= SBM_MAX_SESSIONS) return -EINVAL;
    pthread_mutex_lock(&sessions_lock);
    struct tty *tty = sessions[session_id].used ? sessions[session_id].tty : NULL;
    pthread_mutex_unlock(&sessions_lock);
    if (tty == NULL) return -ENOTTY;
    return (int)tty_input(tty, buffer, (size_t)length, true);
}

void sbm_ish_resize(int session_id, int columns, int rows) {
    if (session_id < 0 || session_id >= SBM_MAX_SESSIONS) return;
    pthread_mutex_lock(&sessions_lock);
    struct tty *tty = sessions[session_id].used ? sessions[session_id].tty : NULL;
    pthread_mutex_unlock(&sessions_lock);
    if (tty == NULL) return;
    struct winsize_ size = {
        .col = (uint16_t)(columns > 0 ? columns : 80),
        .row = (uint16_t)(rows > 0 ? rows : 25),
    };
    // What a guest reads through TIOCGWINSZ, and what makes `top` and an
    // editor draw the right shape. `tty_set_winsize` also signals SIGWINCH.
    tty_set_winsize(tty, size);
}

int sbm_ish_exit_code(int session_id) {
    if (session_id < 0 || session_id >= SBM_MAX_SESSIONS) return -1;
    pthread_mutex_lock(&sessions_lock);
    int code = sessions[session_id].used ? sessions[session_id].exit_code : -1;
    pthread_mutex_unlock(&sessions_lock);
    return code;
}

/// Ends one session: gives the tty back and hangs its process group up.
///
/// Returns the pid it signalled, or 0 if the slot was already free or belongs
/// to another system. Split out of [sbm_ish_close] because [sbm_ish_detach]
/// has to do the same thing to every session in a system before it can unmount
/// anything that system holds.
///
/// `profile` names the system this may close, or NULL for any. It is checked
/// here rather than by the caller because a slot is reused: reading `used` and
/// `profile` under one hold of the lock and then closing under another leaves
/// a window in which `sbm_ish_open` takes the freed slot for a different
/// system, and the detach hangs up a session that has nothing to do with it.
static pid_t_ close_session(int session_id, const char *profile) {
    pthread_mutex_lock(&sessions_lock);
    struct session *session = &sessions[session_id];
    bool mine = session->used &&
                (profile == NULL || strcmp(session->profile, profile) == 0);
    pid_t_ pid = mine ? session->pid : 0;
    struct tty *tty = mine ? session->tty : NULL;
    if (mine) {
        session->used = false;
        session->tty = NULL;
    }
    pthread_mutex_unlock(&sessions_lock);

    // `pty_open_fake` hands over a reference, and forgetting the pointer is
    // not the same as giving it back. Without this the pty stayed registered
    // for the life of the process, `/dev/pts` was never idle, and so every
    // `sbm_ish_detach` answered `_EBUSY` — which is how deleting a system
    // came to pull its `/dev` database out from under a mount that was still
    // live, and the sqlite error that followed reached `die()`.
    if (tty != NULL) {
        lock(&ttys_lock);
        tty_release(tty);
        unlock(&ttys_lock);
    }

    // Hung up, not killed. A shell ignores SIGTERM by design and takes SIGHUP
    // as its terminal going away, which is what has happened.
    if (pid > 0) {
        struct task *task = pid_get_task(pid);
        if (task != NULL) {
            send_group_signal(task->group->pgid, SIGHUP_, SIGINFO_NIL);
            // And the terminal is given up here rather than left to the task's
            // teardown. Every session from `become_new_init_child` is a session
            // leader, so opening its stdio takes the pty as a controlling
            // terminal and the group holds a reference — one that
            // `task_leave_session` returns only when the task is reaped.
            //
            // Nothing reaps these. The engine waits for no task, and the
            // auto-reap path needs a parent that ignores SIGCHLD, which init
            // does not. So the reference outlived the shell by the life of the
            // process: the pty stayed allocated, `/dev/pts` could never be
            // unmounted, and a system a terminal had ever been opened in could
            // never be detached. Reported from a device as a Linux system that
            // could not be deleted until the app was restarted, and as a retry
            // loop waiting for something that was never going to happen.
            tty_disown(task->group);
        }
    }
    return pid;
}

void sbm_ish_close(int session_id) {
    if (session_id < 0 || session_id >= SBM_MAX_SESSIONS) return;
    close_session(session_id, NULL);
}

#endif // SBM_ISH_ENABLED
