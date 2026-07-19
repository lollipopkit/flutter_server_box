#!/bin/sh
# (Un)Install script for ServerBox Monitor
# Release source: this monorepo's GitHub Releases (tag `monitor-v*`), asset
# server-box-monitor_v<ver>_linux_<arch>.tar.gz, containing the server_box_monitor
# binary + frontend/dist + migrations + example config.
set -u

REPO="lollipopkit/flutter_server_box"
APP_DIR="/opt/server-box-monitor"
SERVICE="server_box_monitor.service"
TMP_DIR="/tmp/server-box-monitor-install"
# TODO(migration residue; remove once no legacy users remain): bare binary location of legacy installs
LEGACY_BIN="/usr/local/bin/server_box_monitor"

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root or use sudo"
    exit 1
fi

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
    if [ -f "$LEGACY_BIN" ]; then
        echo "Removing legacy binary $LEGACY_BIN"
        rm -f "$LEGACY_BIN"
    fi

    cleanup
}

install_service() {
    if [ ! -d /etc/systemd ]; then
        echo "Distribution without systemd is not supported yet."
        exit 1
    fi

    cat <<EOF > "/etc/systemd/system/$SERVICE"
[Unit]
Description=ServerBox Monitor
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/server_box_monitor serve
User=root
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE" || { echo "Enable service failed"; exit 1; }
    systemctl restart "$SERVICE" || { echo "Start service failed"; exit 1; }
    systemctl --no-pager status "$SERVICE"
}

install() {
    if [ -f "$APP_DIR/server_box_monitor" ] && [ -f "/etc/systemd/system/$SERVICE" ]; then
        echo "Already installed, use 'upgrade' or 'uninstall'."
        exit 0
    fi

    download
    install_files
    install_service
    echo "Install success. Config: $APP_DIR/.env"
}

upgrade() {
    if [ ! -f "$APP_DIR/server_box_monitor" ] || [ ! -f "/etc/systemd/system/$SERVICE" ]; then
        echo "Not installed. Installing..."
        install
        exit 0
    fi

    download
    systemctl stop "$SERVICE"
    install_files
    systemctl restart "$SERVICE" || { echo "Restart service failed"; exit 1; }
    echo "Upgrade success"
}

uninstall() {
    if [ -f "/etc/systemd/system/$SERVICE" ]; then
        systemctl stop "$SERVICE" 2>/dev/null
        systemctl disable "$SERVICE" 2>/dev/null
        rm -f "/etc/systemd/system/$SERVICE"
        systemctl daemon-reload
    fi
    rm -f "$LEGACY_BIN"

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

case "${1:-}" in
    install) install ;;
    uninstall) uninstall ;;
    upgrade) upgrade ;;
    *)
        echo "Usage: $0 [install|uninstall|upgrade]"
        exit 1
        ;;
esac
