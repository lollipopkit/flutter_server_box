#!/bin/sh
# (Un)Install script for ServerBox Monitor
# Release source: this monorepo's GitHub Releases (tag `monitor-v*`), asset
# server-box-monitor_v<ver>_linux_<arch>.tar.gz, containing the server_box_monitor
# binary + frontend/dist + migrations + example config.
#
# The agent runs as an ordinary account by default. That matters beyond
# tidiness: with `remote_access.full_access` on (the default on Linux), a panel
# login opens a shell as whoever the agent runs as — as root that would be the
# whole machine. Pass --system for the old root-owned service.
#
# systemd and OpenRC both, because the second is what Alpine has and the binary
# is a static musl build that runs there perfectly well. They arrive at the
# same place by different means: a `systemctl --user` service, or a script in
# /etc/init.d with `command_user` set. What differs is who may install one —
# see the branch below, which is the only place the two really diverge.
set -u

REPO="lollipopkit/flutter_server_box"
SERVICE="server_box_monitor.service"
RC_SERVICE="server-box-monitor"
TMP_DIR="${TMPDIR:-/tmp}/server-box-monitor-install"
# TODO(migration residue; remove once no legacy users remain): bare binary location of legacy installs
LEGACY_BIN="/usr/local/bin/server_box_monitor"

MODE="user"
CMD=""
for arg in "$@"; do
    case "$arg" in
        --system) MODE="system" ;;
        --user) MODE="user" ;;
        install|uninstall|upgrade) CMD="$arg" ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [install|uninstall|upgrade] [--user|--system]"
            exit 1
            ;;
    esac
done

# Which init system will be asked to keep the agent running.
#
# `/run/systemd/system` rather than the presence of `systemctl`: a container
# image can carry the binary while something else is pid 1, and there the
# commands below fail in ways that read as a broken install.
detect_init() {
    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
        INIT="systemd"
    elif command -v rc-update >/dev/null 2>&1 &&
         command -v rc-service >/dev/null 2>&1 &&
         command -v openrc-run >/dev/null 2>&1; then
        INIT="openrc"
    else
        echo "No supported init system found."
        echo
        echo "  Looked for systemd (/run/systemd/system) and OpenRC"
        echo "  (rc-update, rc-service, openrc-run)."
        echo
        echo "  The agent itself is a static binary and runs anywhere; what"
        echo "  this script cannot do is arrange for it to be started. Run it"
        echo "  by hand with: server_box_monitor serve"
        exit 1
    fi
}

detect_init

# Where the service and its files go, and who may put them there.
#
# A function rather than the top level, because it refuses: asking for the
# usage text is not a reason to need root, and the OpenRC branch below needs
# it even for the default mode.
resolve_target() {
if [ "$INIT" = "systemd" ]; then
    if [ "$MODE" = "system" ] && [ -e /etc/NIXOS ]; then
        # /etc/systemd/system is a read-only symlink into the store here, so a
        # system service cannot be installed imperatively by anyone, root
        # included. Said before the attempt rather than after: the failure is
        # otherwise a bare "Read-only file system" from the unit write, which
        # reads as a broken installer rather than as the wrong tool.
        echo "NixOS keeps /etc/systemd/system in the read-only store, so a"
        echo "system service cannot be installed this way."
        echo
        echo "  Use the module in monitor/nix/module.nix instead:"
        echo "    imports = [ /path/to/monitor/nix/module.nix ];"
        echo "    services.server-box-monitor.enable = true;"
        echo
        echo "  Or drop --system: the user service works here unchanged."
        exit 1
    fi
    if [ "$MODE" = "system" ]; then
        APP_DIR="/opt/server-box-monitor"
        UNIT="/etc/systemd/system/$SERVICE"
        SYSTEMCTL="systemctl"
        RUN_USER="root"
        if [ "$(id -u)" -ne 0 ]; then
            echo "--system needs root; re-run with sudo."
            exit 1
        fi
    else
        APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/server-box-monitor"
        UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$SERVICE"
        SYSTEMCTL="systemctl --user"
        RUN_USER="$(id -un)"
        if [ "$(id -u)" -eq 0 ]; then
            # Silently installing a root service under `sudo` is how the agent
            # ends up owning the machine; make the choice explicit instead.
            echo "Running as root installs a user service for root, which is"
            echo "probably not what you want."
            echo
            echo "  Drop sudo to install for your own account, or pass --system"
            echo "  to deliberately install the system-wide, root-owned service."
            exit 1
        fi
    fi
else
    # OpenRC has no per-user services: every script lives in /etc/init.d and is
    # started by root. What it does have is `command_user`, so the account the
    # agent runs as is still a choice — which is the part that matters, since
    # `remote_access.full_access` turns a panel login into a shell as whoever
    # that is.
    #
    # So the two modes mean the same thing they mean under systemd, and only
    # the privilege needed to *install* them differs: here both need root,
    # which is the opposite of the rule above and is why it is spelled out.
    UNIT="/etc/init.d/$RC_SERVICE"
    if [ "$(id -u)" -ne 0 ]; then
        echo "OpenRC service scripts live in /etc/init.d, so installing one"
        echo "needs root — including the default, which runs the agent as an"
        echo "ordinary account rather than as root."
        echo
        echo "  Re-run with sudo (or doas) from your own account."
        exit 1
    fi
    if [ "$MODE" = "system" ]; then
        APP_DIR="/opt/server-box-monitor"
        RUN_USER="root"
    else
        # Whoever reached root from their own account. Running the script as
        # root outright leaves nothing to infer, and guessing here would pick
        # the account the agent runs as — not a thing to guess.
        RUN_USER="${SUDO_USER:-${DOAS_USER:-}}"
        if [ -z "$RUN_USER" ]; then
            echo "Cannot tell which account the agent should run as."
            echo
            echo "  Re-run as 'sudo $0 $CMD' from that account, or pass"
            echo "  --system to deliberately run the agent as root."
            exit 1
        fi
        RUN_HOME=$(eval echo "~$RUN_USER")
        APP_DIR="$RUN_HOME/.local/share/server-box-monitor"
    fi
fi
}

detect_arch() {
    case "$(uname -m)" in
        x86_64) arch=amd64 ;;
        aarch64) arch=arm64 ;;
        *)
            echo "Unsupported arch: $(uname -m)"
            exit 1
            ;;
    esac
}

download() {
    # A package already on the machine, instead of one fetched from GitHub:
    # either the unpacked `server-box-monitor/` directory or the tarball. For
    # a server that cannot reach GitHub, and for exercising everything below
    # this line without a release to point at.
    if [ -n "${SBM_INSTALL_PKG:-}" ]; then
        rm -rf "$TMP_DIR"
        mkdir -p "$TMP_DIR"
        if [ -d "$SBM_INSTALL_PKG" ]; then
            cp -r "$SBM_INSTALL_PKG" "$TMP_DIR/server-box-monitor"
        elif [ -f "$SBM_INSTALL_PKG" ]; then
            tar -xzf "$SBM_INSTALL_PKG" -C "$TMP_DIR"
        else
            echo "SBM_INSTALL_PKG is neither a directory nor a file: $SBM_INSTALL_PKG"
            exit 1
        fi
        if [ ! -f "$TMP_DIR/server-box-monitor/server_box_monitor" ]; then
            echo "Unexpected package layout in $SBM_INSTALL_PKG"
            exit 1
        fi
        echo "Installing from $SBM_INSTALL_PKG"
        return
    fi

    detect_arch

    if ! command -v curl >/dev/null 2>&1; then
        echo "Please install curl"
        exit 1
    fi

    # Only monitor-v* tags; isolated from the app's v1.0.x releases
    tag=$(curl -s "https://api.github.com/repos/${REPO}/releases?per_page=100" \
        | grep -o '"tag_name": *"monitor-v[^"]*"' | head -n 1 | cut -d '"' -f 4)
    if [ -z "$tag" ]; then
        echo "Failed to find a monitor-v* release of ${REPO}"
        exit 1
    fi
    ver=${tag#monitor-v}
    asset="server-box-monitor_v${ver}_linux_${arch}.tar.gz"
    base_url="https://github.com/${REPO}/releases/download/${tag}"
    url="$base_url/$asset"

    echo "Downloading $url"
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    if ! curl -fsSL "$url" -o "$TMP_DIR/pkg.tar.gz"; then
        echo "Download failed"
        exit 1
    fi

    if ! command -v sha256sum >/dev/null 2>&1; then
        echo "Please install sha256sum (usually provided by coreutils)"
        exit 1
    fi
    if ! curl -fsSL "$base_url/SHA256SUMS" -o "$TMP_DIR/SHA256SUMS"; then
        echo "Checksum download failed"
        exit 1
    fi
    expected=$(awk -v asset="$asset" '$2 == asset || $2 == "*" asset { print $1; exit }' "$TMP_DIR/SHA256SUMS")
    if [ -z "$expected" ]; then
        echo "No checksum published for $asset"
        exit 1
    fi
    if ! printf '%s  %s\n' "$expected" "$TMP_DIR/pkg.tar.gz" | sha256sum -c -; then
        echo "Package checksum verification failed"
        exit 1
    fi

    tar -xzf "$TMP_DIR/pkg.tar.gz" -C "$TMP_DIR"
    if [ ! -f "$TMP_DIR/server-box-monitor/server_box_monitor" ]; then
        echo "Unexpected package layout"
        exit 1
    fi
}

cleanup() {
    rm -rf "$TMP_DIR"
}

# Overwrite program files, keep .env and the database
install_files() {
    pkg="$TMP_DIR/server-box-monitor"
    mkdir -p "$APP_DIR"
    rm -rf "$APP_DIR/frontend" "$APP_DIR/migrations"
    cp "$pkg/server_box_monitor" "$APP_DIR/"
    chmod 755 "$APP_DIR/server_box_monitor"
    cp -r "$pkg/frontend" "$APP_DIR/frontend"
    cp -r "$pkg/migrations" "$APP_DIR/migrations"
    cp "$pkg/config.example.toml" "$pkg/.env.example" "$APP_DIR/"

    if [ ! -f "$APP_DIR/.env" ]; then
        cp "$pkg/.env.example" "$APP_DIR/.env"
        # Generate a random JWT_SECRET to avoid deploying a weak default
        secret=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
        sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${secret}|" "$APP_DIR/.env"
        chmod 600 "$APP_DIR/.env"
    fi

    # Clean up the bare binary of legacy installs
    if [ "$MODE" = "system" ] && [ -f "$LEGACY_BIN" ]; then
        echo "Removing legacy binary $LEGACY_BIN"
        rm -f "$LEGACY_BIN"
    fi

    # OpenRC has no journal, so the agent's own log is the only record there
    # is; the run user has to be able to write it.
    [ "$INIT" = "openrc" ] && mkdir -p "$APP_DIR/log"

    # Only ever true where this script is root and the agent is not — which is
    # the OpenRC default. Under systemd's user mode these files are written by
    # their owner already. Here rather than beside the service script, because
    # `upgrade` replaces files without touching the service.
    if [ "$(id -u)" -eq 0 ] && [ "$RUN_USER" != "root" ]; then
        chown -R "$RUN_USER" "$APP_DIR"
    fi

    cleanup
}

# The six things this script asks of an init system, and nothing more.
svc_enable() {
    if [ "$INIT" = "systemd" ]; then
        $SYSTEMCTL enable "$SERVICE"
    else
        rc-update add "$RC_SERVICE" default
    fi
}

svc_disable() {
    if [ "$INIT" = "systemd" ]; then
        $SYSTEMCTL disable "$SERVICE" 2>/dev/null
    else
        rc-update del "$RC_SERVICE" default 2>/dev/null
    fi
}

svc_restart() {
    if [ "$INIT" = "systemd" ]; then
        $SYSTEMCTL restart "$SERVICE"
    else
        rc-service "$RC_SERVICE" restart
    fi
}

svc_stop() {
    if [ "$INIT" = "systemd" ]; then
        $SYSTEMCTL stop "$SERVICE" 2>/dev/null
    else
        rc-service "$RC_SERVICE" stop 2>/dev/null
    fi
}

svc_reload() {
    # OpenRC reads /etc/init.d on each command, so there is nothing to tell.
    [ "$INIT" = "systemd" ] && $SYSTEMCTL daemon-reload
    return 0
}

svc_status() {
    if [ "$INIT" = "systemd" ]; then
        $SYSTEMCTL --no-pager status "$SERVICE"
    else
        rc-service "$RC_SERVICE" status
    fi
}

write_openrc_script() {
    {
        echo "#!/sbin/openrc-run"
        echo
        echo "name=\"ServerBox Monitor\""
        echo "description=\"ServerBox Monitor agent\""
        echo
        echo "command=\"$APP_DIR/server_box_monitor\""
        echo "command_args=\"serve\""
        # The account only. `user:group` here would assume a group of the same
        # name exists, which is a Debian-ism rather than a rule — left off,
        # OpenRC uses the account's own primary group.
        echo "command_user=\"$RUN_USER\""
        echo "directory=\"$APP_DIR\""
        # The equivalent of systemd's Restart=always. Without a supervisor
        # OpenRC starts the agent once and never looks again.
        echo "supervisor=\"supervise-daemon\""
        echo "respawn_delay=3"
        # There is no journal to fall back on, so an agent that logs nowhere
        # logs nothing at all — including the remote-access summary and its
        # security warnings. Inside APP_DIR because the run user owns that and
        # may not own /var/log.
        echo "output_log=\"$APP_DIR/log/agent.log\""
        echo "error_log=\"$APP_DIR/log/agent.err\""
        echo
        # Same reason as the systemd unit's Environment=: the default filter
        # is ERROR only.
        echo "export RUST_LOG=info"
        echo
        echo "depend() {"
        echo "    need net"
        echo "}"
    } > "$UNIT"
    chmod 755 "$UNIT"

    mkdir -p "$APP_DIR/log"
    if [ "$RUN_USER" != "root" ]; then
        chown -R "$RUN_USER" "$APP_DIR"
    fi
}

install_service() {
    if [ "$INIT" = "openrc" ]; then
        write_openrc_script
        svc_enable || { echo "Enable service failed"; exit 1; }
        svc_restart || { echo "Start service failed"; exit 1; }
        svc_status
        return
    fi

    mkdir -p "$(dirname "$UNIT")"
    {
        echo "[Unit]"
        echo "Description=ServerBox Monitor"
        echo "After=network.target"
        echo
        echo "[Service]"
        echo "Type=simple"
        echo "WorkingDirectory=$APP_DIR"
        echo "ExecStart=$APP_DIR/server_box_monitor serve"
        # Without this the default filter is ERROR only, so nothing the agent
        # reports about itself at startup reaches the journal — including the
        # remote-access summary and its security warnings. docker-compose.yaml
        # already defaults to info.
        echo "Environment=RUST_LOG=info"
        # The agent collects by running ordinary tools — `sh` first, then
        # whatever the command manifest asks for: cat, df, uptime, lsblk.
        # A unit that sets no PATH gets systemd's compiled-in one, and that is
        # a per-distribution value: on most it is the FHS list below and this
        # line changes nothing, but NixOS builds systemd with its own store
        # path instead, so the service saw *only* systemd's own bin directory.
        # `sh` was then not on PATH at all and every cycle failed with
        # "Status script error: No such file or directory (os error 2)" —
        # measured on NixOS 25.11, where /bin/sh exists but /bin does not.
        #
        # The NixOS entry first and the rest unchanged: a directory that does
        # not exist costs nothing to have on PATH.
        echo "Environment=PATH=/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        if [ "$MODE" = "system" ]; then
            echo "User=root"
        fi
        echo "Restart=always"
        echo "RestartSec=3"
        echo
        echo "[Install]"
        if [ "$MODE" = "system" ]; then
            echo "WantedBy=multi-user.target"
        else
            echo "WantedBy=default.target"
        fi
    } > "$UNIT"

    svc_reload
    svc_enable || { echo "Enable service failed"; exit 1; }
    svc_restart || { echo "Start service failed"; exit 1; }

    if [ "$MODE" = "user" ]; then
        # Without lingering, a user service stops at logout — surprising for
        # something whose whole job is to keep watching the machine.
        if ! loginctl enable-linger "$(id -un)" 2>/dev/null; then
            echo
            echo "Note: could not enable lingering, so the service will stop"
            echo "when you log out. Run this once as root to fix that:"
            echo "  loginctl enable-linger $(id -un)"
        fi
    fi

    svc_status
}

installed() {
    [ -f "$APP_DIR/server_box_monitor" ] && [ -f "$UNIT" ]
}

install() {
    if installed; then
        echo "Already installed, use 'upgrade' or 'uninstall'."
        exit 0
    fi

    download
    install_files
    install_service
    echo "Install success ($MODE service). Config: $APP_DIR/.env"
    if [ "$MODE" = "system" ]; then
        echo
        echo "This runs as root. If you enable remote_access.terminal.enabled,"
        echo "also set remote_access.full_access = false, or a panel"
        echo "login becomes a root shell."
    fi
}

upgrade() {
    if ! installed; then
        echo "Not installed. Installing..."
        install
        exit 0
    fi

    download
    svc_stop
    install_files
    svc_restart || { echo "Restart service failed"; exit 1; }
    echo "Upgrade success"
}

uninstall() {
    if [ -f "$UNIT" ]; then
        svc_stop
        svc_disable
        rm -f "$UNIT"
        svc_reload
    fi
    [ "$MODE" = "system" ] && rm -f "$LEGACY_BIN"

    if [ -d "$APP_DIR" ]; then
        printf "Remove %s (including database and .env)? [y/N] " "$APP_DIR"
        read -r ans
        case "$ans" in
            y|Y) rm -rf "$APP_DIR" ;;
            *) echo "Kept $APP_DIR" ;;
        esac
    fi
    echo "Uninstall success"
}

case "$CMD" in
    install) resolve_target; install ;;
    uninstall) resolve_target; uninstall ;;
    upgrade) resolve_target; upgrade ;;
    *)
        echo "Usage: $0 [install|uninstall|upgrade] [--user|--system]"
        echo
        echo "  --user    (default) the agent runs as an ordinary account"
        echo "  --system  the agent runs as root"
        echo
        echo "Init system detected: $INIT"
        if [ "$INIT" = "systemd" ]; then
            echo "  --user installs a 'systemctl --user' service in \$HOME."
            echo "  Run it as yourself; --system needs sudo."
        else
            echo "  OpenRC has no user services, so both install a script in"
            echo "  /etc/init.d and both need root. --user is still the"
            echo "  default: the script sets command_user to the account you"
            echo "  sudo'd from, so the agent is not root either way."
        fi
        exit 1
        ;;
esac
