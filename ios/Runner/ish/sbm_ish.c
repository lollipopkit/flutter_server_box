#include "sbm_ish.h"

#if !SBM_ISH_ENABLED

// The switch is off: no engine is linked, so there is nothing here to call
// into. Every entry point answers the same way it would on a platform that
// never had one, which is what the Dart side is already written against.

bool sbm_ish_available(void) { return false; }
int sbm_ish_boot(const char *rootfs, const char *command, int columns, int rows) {
    (void)rootfs; (void)command; (void)columns; (void)rows;
    return -1;
}

int sbm_ish_read(char *buffer, int length, int timeout_ms) {
    (void)buffer; (void)length; (void)timeout_ms;
    return -1;
}
int sbm_ish_write(const char *buffer, int length) {
    (void)buffer; (void)length;
    return -1;
}
void sbm_ish_resize(int columns, int rows) { (void)columns; (void)rows; }
int sbm_ish_exit_code(void) { return -1; }

#else

#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#include <sys/stat.h>
#include <syslog.h>

#include "kernel/calls.h"
#include "kernel/init.h"
#include "kernel/task.h"
#include "fs/dev.h"
#include "fs/devices.h"
#include "fs/fd.h"
#include "fs/path.h"
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

// — What the guest prints ————————————————————————————————————————————
//
// A ring buffer rather than a pipe, because the guest's writes must never
// block on nobody reading: a terminal whose page is off screen is exactly that
// case, and a blocked write inside the interpreter stops the whole guest.
// Overrunning drops the oldest bytes, which is what a terminal's scrollback
// does anyway.

#define OUTPUT_CAPACITY (256 * 1024)

static struct {
    char data[OUTPUT_CAPACITY];
    size_t head, tail;
    pthread_mutex_t lock;
    pthread_cond_t wrote;
} output = {
    .lock = PTHREAD_MUTEX_INITIALIZER,
    .wrote = PTHREAD_COND_INITIALIZER,
};

static void output_push(const char *bytes, size_t length) {
    pthread_mutex_lock(&output.lock);
    for (size_t i = 0; i < length; i++) {
        size_t next = (output.head + 1) % OUTPUT_CAPACITY;
        if (next == output.tail) {
            // Full. Drop the oldest byte rather than the newest: what a user
            // is waiting for is the end of the output, not its beginning.
            output.tail = (output.tail + 1) % OUTPUT_CAPACITY;
        }
        output.data[output.head] = bytes[i];
        output.head = next;
    }
    pthread_cond_broadcast(&output.wrote);
    pthread_mutex_unlock(&output.lock);
}

// — The console ————————————————————————————————————————————————————
//
// A tty driver of our own, in place of the one that reads and writes the
// host's own stdin and stdout. Those belong to the app — its logs go there —
// and a guest console pointed at them would be both invisible and destructive.

static struct tty *console_tty;

static int console_init(struct tty *tty) {
    console_tty = tty;
    return 0;
}

static int console_write(struct tty *tty, const void *buffer, size_t length, bool blocking) {
    (void)tty; (void)blocking;
    output_push((const char *)buffer, length);
    return (int)length;
}

static int console_open(struct tty *tty) { (void)tty; return 0; }
static int console_close(struct tty *tty) { (void)tty; return 0; }
static void console_cleanup(struct tty *tty) { (void)tty; }

static const struct tty_driver_ops console_ops = {
    .init = console_init,
    .open = console_open,
    .close = console_close,
    .write = console_write,
    .cleanup = console_cleanup,
};

DEFINE_TTY_DRIVER(sbm_console_driver, &console_ops, TTY_CONSOLE_MAJOR, 1);

// — Booting ————————————————————————————————————————————————————————

static bool booted;
static int guest_exit_code = -1;
static pthread_mutex_t boot_lock = PTHREAD_MUTEX_INITIALIZER;

/// What the guest was started with, kept for the boot sequence to read.
static struct {
    const char *rootfs;
    const char *command;
    int columns, rows;
} boot;

static void guest_exited(struct task *task, int code) {
    // Only the first process ending is the guest ending; anything it spawned
    // exits all the time.
    if (task->parent != NULL) return;
    pthread_mutex_lock(&output.lock);
    guest_exit_code = code >> 8;
    pthread_cond_broadcast(&output.wrote);
    pthread_mutex_unlock(&output.lock);
}

/// Everything `xX_main_Xx` does, minus the parts an app cannot use.
///
/// Not that function, though it is tempting: it parses a command line,
/// installs the tty driver that reads and writes the *host's* stdin and
/// stdout, and builds the guest's stdio out of it. In an app those are the
/// app's own streams. This is the same sequence with the console pointed
/// somewhere a terminal can see, and it is the sequence OpenMinis uses to ship
/// this engine.
static int boot_kernel(void) {
    install_crash_handler();
    // Otherwise `die()` calls abort(), and the app goes with the guest.
    die_handler = park_on_die;

    // The filesystem's files live under `data`; the metadata db sits beside it.
    char data_path[MAX_PATH + 1];
    snprintf(data_path, sizeof(data_path), "%s/data", boot.rootfs);
    int err = mount_root(&fakefs, data_path);
    if (err < 0) return err;

    err = become_first_process();
    if (err < 0) return err;
    current->thread = pthread_self();

    // What a userland expects to find. fakefs can hold device nodes; a real
    // directory could not, which is half of why the filesystem has this shape.
    generic_mknodat(AT_PWD, "/dev/null", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_NULL_MINOR));
    generic_mknodat(AT_PWD, "/dev/zero", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_ZERO_MINOR));
    generic_mknodat(AT_PWD, "/dev/full", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_FULL_MINOR));
    generic_mknodat(AT_PWD, "/dev/random", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_RANDOM_MINOR));
    generic_mknodat(AT_PWD, "/dev/urandom", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_URANDOM_MINOR));
    generic_mknodat(AT_PWD, "/dev/tty", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_TTY_MINOR));
    generic_mknodat(AT_PWD, "/dev/console", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_CONSOLE_MINOR));
    generic_mknodat(AT_PWD, "/dev/ptmx", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_PTMX_MINOR));

    do_mount(&procfs, "proc", "/proc", "", 0);
    do_mount(&devptsfs, "devpts", "/dev/pts", "", 0);
    exit_hook = guest_exited;

    tty_drivers[TTY_CONSOLE_MAJOR] = &sbm_console_driver;
    set_console_device(TTY_CONSOLE_MAJOR, 1);
    err = create_stdio("/dev/console", TTY_CONSOLE_MAJOR, 1);
    if (err < 0) return err;
    sbm_ish_resize(boot.columns, boot.rows);

    char environment[512] = {0};
    size_t written = 0;
    written += snprintf(environment + written, sizeof(environment) - written,
                        "TERM=xterm-256color") + 1;
    written += snprintf(environment + written, sizeof(environment) - written,
                        "HOME=/root") + 1;
    written += snprintf(environment + written, sizeof(environment) - written,
                        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin") + 1;
    written += snprintf(environment + written, sizeof(environment) - written,
                        "PYTHONMALLOC=malloc") + 1;

    // A shell, and not the caller's command. The first process is init, and
    // `kernel/exit.c` ends the *host process* with `_exit(0)` when init dies —
    // so a command as init means the app quits when the command finishes.
    // Measured, and it is what the first version did: the guest booted, the
    // command ran, and the app was gone before anything could read a byte of
    // its output.
    //
    // So init is a shell that stays, and a command is typed at it. That is
    // also what a terminal is, which is where this ends up anyway.
    char argv[4096];
    const char *shell = "/bin/sh";
    size_t length = strlen(shell) + 1;
    memcpy(argv, shell, length);
    argv[length] = '\0';

    err = do_execve(shell, 1, argv, environment);
    if (err < 0) return err;

    // Started, not run here. `task_run_current` would turn this thread into
    // the guest and never return — fine for a command-line iSH, and a hang for
    // anything with a caller waiting.
    task_start(current);

    // Typed at the shell once it is running, if the caller asked for anything.
    if (boot.command != NULL && boot.command[0] != '\0') {
        // It has to have got as far as reading its input. That is a process
        // starting, not a network round trip, so this is short — and it is the
        // caller's thread waiting, never the guest's.
        struct timespec settle = { .tv_sec = 0, .tv_nsec = 200 * 1000 * 1000 };
        nanosleep(&settle, NULL);
        sbm_ish_write(boot.command, (int)strlen(boot.command));
        sbm_ish_write("\n", 1);
    }
    return 0;
}

bool sbm_ish_available(void) { return true; }

int sbm_ish_boot(const char *rootfs, const char *command, int columns, int rows) {
    if (rootfs == NULL || command == NULL) return -EINVAL;

    pthread_mutex_lock(&boot_lock);
    if (booted) {
        pthread_mutex_unlock(&boot_lock);
        // The kernel's state is global, so a second guest would not be a
        // second machine — it would be the first one corrupted.
        return -EEXIST;
    }
    booted = true;
    pthread_mutex_unlock(&boot_lock);

    // Copied: the guest outlives this call and the caller's strings may not.
    boot.rootfs = strdup(rootfs);
    boot.command = strdup(command);
    boot.columns = columns;
    boot.rows = rows;

    // On the caller's thread, and it does not block: `task_start` gives the
    // guest a thread of its own. The first version booted on a thread of its
    // own and waited here for it, which hung — `current` is thread-local, so
    // that arrangement put the task on one thread and everything waiting on
    // another.
    int err = boot_kernel();
    if (err < 0) {
        pthread_mutex_lock(&boot_lock);
        booted = false;
        pthread_mutex_unlock(&boot_lock);
    }
    return err;
}

int sbm_ish_read(char *buffer, int length, int timeout_ms) {
    if (buffer == NULL || length <= 0) return -EINVAL;

    // Tried, not taken. The guest holds this lock while it writes, and a guest
    // thread that faults there is parked by the crash handler still holding
    // it — at which point a plain `lock` here would never return, which is
    // indistinguishable from the app having wedged. `-EBUSY` says which.
    if (pthread_mutex_trylock(&output.lock) != 0) {
        struct timespec retry = { .tv_sec = 0, .tv_nsec = 2 * 1000 * 1000 };
        int attempts = 0;
        while (pthread_mutex_trylock(&output.lock) != 0) {
            if (++attempts > 50) return -EBUSY;
            nanosleep(&retry, NULL);
        }
    }
    if (output.head == output.tail && guest_exit_code < 0) {
        struct timeval now;
        gettimeofday(&now, NULL);
        struct timespec until = {
            .tv_sec = now.tv_sec + timeout_ms / 1000,
            .tv_nsec = now.tv_usec * 1000 + (long)(timeout_ms % 1000) * 1000000,
        };
        if (until.tv_nsec >= 1000000000) {
            until.tv_sec += 1;
            until.tv_nsec -= 1000000000;
        }
        pthread_cond_timedwait(&output.wrote, &output.lock, &until);
    }

    int count = 0;
    while (count < length && output.tail != output.head) {
        buffer[count++] = output.data[output.tail];
        output.tail = (output.tail + 1) % OUTPUT_CAPACITY;
    }
    // Told apart from "nothing yet": a caller looping on this needs to know
    // the difference between a quiet guest and a finished one.
    bool ended = count == 0 && guest_exit_code >= 0;
    pthread_mutex_unlock(&output.lock);
    return ended ? -1 : count;
}

int sbm_ish_write(const char *buffer, int length) {
    if (console_tty == NULL) return -ENOTTY;
    if (buffer == NULL || length <= 0) return -EINVAL;
    return (int)tty_input(console_tty, buffer, (size_t)length, true);
}

void sbm_ish_resize(int columns, int rows) {
    if (console_tty == NULL) return;
    // What a guest reads through TIOCGWINSZ, and what makes `top` and an
    // editor draw the right shape.
    console_tty->winsize.col = (uint16_t)(columns > 0 ? columns : 80);
    console_tty->winsize.row = (uint16_t)(rows > 0 ? rows : 25);
}

int sbm_ish_exit_code(void) {
    pthread_mutex_lock(&output.lock);
    int code = guest_exit_code;
    pthread_mutex_unlock(&output.lock);
    return code;
}

#endif // SBM_ISH_ENABLED
