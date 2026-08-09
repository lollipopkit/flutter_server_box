#!/bin/sh
# (Un)Install script for ServerBox Monitor
# Release source: this monorepo's GitHub Releases (tag `monitor-v*`), asset
# server-box-monitor_v<ver>_linux_<arch>.tar.gz, containing the server_box_monitor
# binary + frontend/dist + migrations + example config.
#
# Installs a *user* systemd service by default, so the agent runs as an
# ordinary account. That matters beyond tidiness: with
# `remote_access.passwordless_terminal` on (the default on Linux), a panel
# login opens a shell as whoever the agent runs as — as root that would be the
# whole machine. Pass --system for the old system-wide, root-owned service.
set -u

REPO="lollipopkit/flutter_server_box"
SERVICE="server_box_monitor.service"
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

if [ "$MODE" = "system" ]; then
    APP_DIR="/opt/server-box-monitor"
    UNIT_DIR="/etc/systemd/system"
    SYSTEMCTL="systemctl"
    if [ "$(id -u)" -ne 0 ]; then
        echo "--system needs root; re-run with sudo."
        exit 1
    fi
else
    APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/server-box-monitor"
    UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    SYSTEMCTL="systemctl --user"
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

UNIT="$UNIT_DIR/$SERVICE"

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
    url="https://github.com/${REPO}/releases/download/${tag}/server-box-monitor_v${ver}_linux_${arch}.tar.gz"

    echo "Downloading $url"
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    if ! curl -fsSL "$url" -o "$TMP_DIR/pkg.tar.gz"; then
        echo "Download failed"
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

    cleanup
}

install_service() {
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "Distribution without systemd is not supported yet."
        exit 1
    fi

    mkdir -p "$UNIT_DIR"
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

    $SYSTEMCTL daemon-reload
    $SYSTEMCTL enable "$SERVICE" || { echo "Enable service failed"; exit 1; }
    $SYSTEMCTL restart "$SERVICE" || { echo "Start service failed"; exit 1; }

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

    $SYSTEMCTL --no-pager status "$SERVICE"
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
        echo "This runs as root. If you enable remote_access.terminal_enabled,"
        echo "also set remote_access.passwordless_terminal = false, or a panel"
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
    $SYSTEMCTL stop "$SERVICE"
    install_files
    $SYSTEMCTL restart "$SERVICE" || { echo "Restart service failed"; exit 1; }
    echo "Upgrade success"
}

uninstall() {
    if [ -f "$UNIT" ]; then
        $SYSTEMCTL stop "$SERVICE" 2>/dev/null
        $SYSTEMCTL disable "$SERVICE" 2>/dev/null
        rm -f "$UNIT"
        $SYSTEMCTL daemon-reload
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
    install) install ;;
    uninstall) uninstall ;;
    upgrade) upgrade ;;
    *)
        echo "Usage: $0 [install|uninstall|upgrade] [--user|--system]"
        echo
        echo "  --user    (default) systemd --user service in $HOME, running as you"
        echo "  --system  system-wide service running as root; needs sudo"
        exit 1
        ;;
esac
