#include "sbm_ish.h"

#if !SBM_ISH_ENABLED

// The switch is off: no engine is linked, so there is nothing here to call
// into. Every entry point answers the same way it would on a platform that
// never had one, which is what the Dart side is already written against.

bool sbm_ish_available(void) { return false; }
int sbm_ish_boot(const char *rootfs) { (void)rootfs; return -1; }
int sbm_ish_open(const char *shell, const char *command, int columns, int rows) {
    (void)shell; (void)command; (void)columns; (void)rows;
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
    int exit_code;
    char data[SBM_OUTPUT_CAPACITY];
    size_t head, tail;
};

static struct session sessions[SBM_MAX_SESSIONS];
static pthread_mutex_t sessions_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t sessions_wrote = PTHREAD_COND_INITIALIZER;

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
    pthread_mutex_lock(&sessions_lock);
    for (int i = 0; i < SBM_MAX_SESSIONS; i++) {
        if (sessions[i].used && sessions[i].pid == task->pid) {
            sessions[i].exit_code = code >> 8;
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
static int make_dev_db(char *data_out, size_t data_len) {
    char dir[MAX_PATH];
    snprintf(dir, sizeof(dir), "%s/.dev", rootfs_path);
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

/// Everything a userland expects to find at `/dev`.
static void make_dev(void) {
    // The mount point first: a minirootfs unpacked without root may have no
    // `/dev` at all, since the device nodes in the tarball are what create it.
    generic_mkdirat(AT_PWD, "/dev", 0755);

    char data_path[MAX_PATH];
    if (make_dev_db(data_path, sizeof(data_path)) < 0) return;
    do_mount(&fakefs, data_path, "/dev", "", 0);

    generic_mknodat(AT_PWD, "/dev/null", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_NULL_MINOR));
    generic_mknodat(AT_PWD, "/dev/zero", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_ZERO_MINOR));
    generic_mknodat(AT_PWD, "/dev/full", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_FULL_MINOR));
    generic_mknodat(AT_PWD, "/dev/random", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_RANDOM_MINOR));
    generic_mknodat(AT_PWD, "/dev/urandom", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_URANDOM_MINOR));
    generic_mknodat(AT_PWD, "/dev/tty", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_TTY_MINOR));
    generic_mknodat(AT_PWD, "/dev/console", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_CONSOLE_MINOR));
    generic_mknodat(AT_PWD, "/dev/ptmx", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_PTMX_MINOR));

    // Where the pty slaves appear. Its mount point has to exist first, since
    // `/dev` is a filesystem that was empty a moment ago.
    generic_mkdirat(AT_PWD, "/dev/pts", 0755);
    do_mount(&devptsfs, "devpts", "/dev/pts", "", 0);

    // Not device nodes but expected to be there, and cheap to be right about:
    // a shell's `>/dev/stdout`, a script's `/dev/fd/3`, and anything that
    // writes to `/dev/shm` all fail without them.
    generic_symlinkat("/proc/self/fd", AT_PWD, "/dev/fd");
    generic_symlinkat("/proc/self/fd/0", AT_PWD, "/dev/stdin");
    generic_symlinkat("/proc/self/fd/1", AT_PWD, "/dev/stdout");
    generic_symlinkat("/proc/self/fd/2", AT_PWD, "/dev/stderr");
    generic_mkdirat(AT_PWD, "/dev/shm", 01777);
    do_mount(&tmpfs, "shm", "/dev/shm", "", 0);
}

bool sbm_ish_available(void) { return true; }

int sbm_ish_boot(const char *rootfs) {
    if (rootfs == NULL) return -EINVAL;
    if (booted) return -EEXIST;

    install_crash_handler();
    // Otherwise `die()` calls abort(), and the app goes with the guest.
    die_handler = park_on_die;

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

    // `/proc` first: `/dev/stdout` and friends are symlinks into it, and a
    // shell following one before it is mounted gets "nonexistent directory".
    generic_mkdirat(AT_PWD, "/proc", 0755);
    do_mount(&procfs, "proc", "/proc", "", 0);
    make_dev();
    exit_hook = guest_exited;

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
    if (err < 0) return err;
    task_start(current);

    booted = true;
    return 0;
}

int sbm_ish_open(const char *shell, const char *command, int columns, int rows) {
    if (!booted) return -ENOTCONN;

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
    pthread_mutex_unlock(&sessions_lock);

    // A task of its own, under init. Everything from here happens as that
    // task, on this thread, until `task_start` gives it one.
    int err = become_new_init_child();
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

    char environment[256] = {0};
    size_t written = 0;
    written += snprintf(environment + written, sizeof(environment) - written,
                        "TERM=xterm-256color") + 1;
    written += snprintf(environment + written, sizeof(environment) - written, "HOME=/root") + 1;
    written += snprintf(environment + written, sizeof(environment) - written,
                        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin") + 1;

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
    pthread_mutex_lock(&sessions_lock);
    session->used = false;
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

void sbm_ish_close(int session_id) {
    if (session_id < 0 || session_id >= SBM_MAX_SESSIONS) return;
    pthread_mutex_lock(&sessions_lock);
    struct session *session = &sessions[session_id];
    pid_t_ pid = session->used ? session->pid : 0;
    session->used = false;
    session->tty = NULL;
    pthread_mutex_unlock(&sessions_lock);

    // Hung up, not killed. A shell ignores SIGTERM by design and takes SIGHUP
    // as its terminal going away, which is what has happened.
    if (pid > 0) {
        struct task *task = pid_get_task(pid);
        if (task != NULL) send_group_signal(task->group->pgid, SIGHUP_, SIGINFO_NIL);
    }
}

#endif // SBM_ISH_ENABLED
