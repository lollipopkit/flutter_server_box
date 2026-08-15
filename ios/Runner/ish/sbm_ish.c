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

#include "kernel/calls.h"
#include "kernel/init.h"
#include "kernel/task.h"
#include "fs/devices.h"
#include "fs/tty.h"
#include "xX_main_Xx.h"

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

/// What the guest thread is told to start, and what it reports back.
///
/// All of it happens on that one thread because the kernel's `current` task is
/// thread-local: `xX_main_Xx` sets `current->thread = pthread_self()`, so a
/// boot on one thread and a run loop on another would be two different tasks,
/// one of them missing.
static struct {
    const char *rootfs;
    const char *command;
    int columns, rows;
    int result;
    bool ready;
    pthread_mutex_t lock;
    pthread_cond_t done;
} boot = {
    .result = -EAGAIN,
    .lock = PTHREAD_MUTEX_INITIALIZER,
    .done = PTHREAD_COND_INITIALIZER,
};

static void report_boot(int result) {
    pthread_mutex_lock(&boot.lock);
    boot.result = result;
    boot.ready = true;
    pthread_cond_broadcast(&boot.done);
    pthread_mutex_unlock(&boot.lock);
}

static void guest_exited(struct task *task, int code) {
    // Only the first process ending is the guest ending; anything it spawned
    // exits all the time.
    if (task->parent != NULL) return;
    pthread_mutex_lock(&output.lock);
    guest_exit_code = code >> 8;
    pthread_cond_broadcast(&output.wrote);
    pthread_mutex_unlock(&output.lock);
}

static void *run_guest(void *unused) {
    (void)unused;

    // The interpreter recovers from a guest fault by unwinding the block it
    // was in, which it can only do from a signal handler on its own stack.
    static char alternate_stack[SIGSTKSZ];
    stack_t stack = { .ss_sp = alternate_stack, .ss_size = SIGSTKSZ };
    sigaltstack(&stack, NULL);

    char environment[512] = {0};
    size_t written = 0;
    written += snprintf(environment + written, sizeof(environment) - written,
                        "TERM=xterm-256color") + 1;
    written += snprintf(environment + written, sizeof(environment) - written,
                        "HOME=/root") + 1;
    written += snprintf(environment + written, sizeof(environment) - written,
                        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin") + 1;

    char *const argv[] = {
        (char *)"ish", (char *)"-f", (char *)boot.rootfs,
        (char *)"/bin/sh", (char *)"-c", (char *)boot.command, NULL,
    };
    int err = xX_main_Xx(6, argv, environment);
    if (err < 0) { report_boot(err); return NULL; }

    // After, not before: `xX_main_Xx` installs the host's own tty driver and
    // then builds stdio out of it. Putting ours back and building stdio again
    // is what points the guest's console at this app instead of at the
    // process's stdout, which belongs to the app and its logs.
    tty_drivers[TTY_CONSOLE_MAJOR] = &sbm_console_driver;
    err = create_stdio("/dev/console", TTY_CONSOLE_MAJOR, 1);
    if (err < 0) { report_boot(err); return NULL; }
    sbm_ish_resize(boot.columns, boot.rows);

    do_mount(&procfs, "proc", "/proc", "", 0);
    do_mount(&devptsfs, "devpts", "/dev/pts", "", 0);
    exit_hook = guest_exited;

    report_boot(0);
    // Never returns while the guest lives. This is the interpreter's dispatch
    // loop, and it belongs nowhere near the UI thread.
    task_run_current();
    return NULL;
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

    // Copied, because the thread outlives this call and the caller's strings
    // may not.
    boot.rootfs = strdup(rootfs);
    boot.command = strdup(command);
    boot.columns = columns;
    boot.rows = rows;

    pthread_t thread;
    if (pthread_create(&thread, NULL, run_guest, NULL) != 0) return -EAGAIN;
    pthread_detach(thread);

    // Waited for, so a caller that gets 0 back knows the guest is running and
    // one that gets an error knows it never started. Bounded: a boot that
    // hangs is a bug, and hanging the caller with it hides which.
    struct timeval now;
    gettimeofday(&now, NULL);
    struct timespec until = { .tv_sec = now.tv_sec + 30, .tv_nsec = now.tv_usec * 1000 };
    pthread_mutex_lock(&boot.lock);
    while (!boot.ready) {
        if (pthread_cond_timedwait(&boot.done, &boot.lock, &until) != 0) break;
    }
    int result = boot.ready ? boot.result : -ETIMEDOUT;
    pthread_mutex_unlock(&boot.lock);
    return result;
}

int sbm_ish_read(char *buffer, int length, int timeout_ms) {
    if (buffer == NULL || length <= 0) return -EINVAL;

    pthread_mutex_lock(&output.lock);
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
