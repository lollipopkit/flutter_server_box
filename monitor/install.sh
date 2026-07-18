#!/bin/sh
# (Un)Install script for ServerBoxMonitor

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root or use sudo"
    exit 1
fi


download() {
    # Check arch: amd64 or arm64
    arch=$(uname -m)
    case $arch in
        x86_64)
            arch=amd64
            ;;
        aarch64)
            arch=arm64
            ;;
        *)
            echo "Not support arch: $arch"
            exit 1
            ;;
    esac

    # Check curl
    if ! command -v curl >/dev/null 2>&1; then
        echo "Please install curl"
        exit 1
    fi

    # Generate download url
    newestTag=$(curl -s https://api.github.com/repos/lollipopkit/server_box_monitor/releases/latest | grep tag_name | cut -d '"' -f 4)
    # Remove 'v' at the start -> "0.1.0"
    newestTagLen=$(expr length "$newestTag")
    APPVER=$(expr substr "$newestTag" 2 "$newestTagLen")
    DOWNLOAD_URL="https://github.com/lollipopkit/server_box_monitor/releases/download/v${APPVER}/server_box_monitor_${APPVER}_linux_$arch.tar.gz"

    # Download binary
    echo "Download $DOWNLOAD_URL"

    curl -sL "$DOWNLOAD_URL" -o /tmp/server_box_monitor.tar.gz
    if [ ! -f /tmp/server_box_monitor.tar.gz ]; then
        echo "Download binary failed"
        exit 1
    fi
}


cleanup() {
    # Clean up
    echo "Cleaning up..."
    rm -f /tmp/server_box_monitor.tar.gz
    rm -rf /tmp/server_box_monitor
}


install_binary() {
    # Extract binary
    echo "Extracting binary..."
    tar -xf /tmp/server_box_monitor.tar.gz -C /tmp
    if [ ! -f /tmp/server_box_monitor ]; then
        echo "Extract binary failed"
        exit 1
    fi

    # Install binary
    echo "Installing binary..."
    mv /tmp/server_box_monitor /usr/local/bin/server_box_monitor
    if [ $? -ne 0 ]; then
        echo "Install binary failed"
        exit 1
    fi

    cleanup
}

install() {
    # If already installed, skip
    if [ -f /usr/local/bin/server_box_monitor ] && [ -f /etc/systemd/system/server_box_monitor.service ]; then
        echo "Already installed, use 'upgrade' or 'uninstall'."
        exit 0
    fi

    download

    install_binary

    # Check systemd
    if [ ! -d /etc/systemd ]; then
        echo "Distribution without systemd is not supported yet."
        exit 1
    fi

    # Install systemd service
    echo "Installing systemd service..."
    cat <<EOF > /etc/systemd/system/server_box_monitor.service
[Unit]
Description=Server Box Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/server_box_monitor serve
User=root
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Enable systemd service
    echo "Enabling systemd service..."
    systemctl enable server_box_monitor.service
    if [ $? -ne 0 ]; then
        echo "Enable systemd service failed"
        exit 1
    fi

    # Start systemd service
    echo "Starting systemd service..."
    systemctl start server_box_monitor.service
    if [ $? -ne 0 ]; then
        echo "Start systemd service failed"
        exit 1
    fi

    # Display systemd service status
    echo "Displaying systemd service status..."
    systemctl status server_box_monitor.service

    echo "Install success"
}


uninstall() {
    # Stop systemd service
    echo "Stopping systemd service..."
    systemctl stop server_box_monitor.service
    if [ $? -ne 0 ]; then
        echo "Stop systemd service failed"
        exit 1
    fi
    
    # Disable systemd service
    echo "Disabling systemd service..."
    systemctl disable server_box_monitor.service
    if [ $? -ne 0 ]; then
        echo "Disable systemd service failed"
        exit 1
    fi
    
    # Remove systemd service
    echo "Removing systemd service..."
    rm -f /etc/systemd/system/server_box_monitor.service
    
    # Remove binary
    echo "Removing binary..."
    rm -f /usr/local/bin/server_box_monitor
    
    echo "Uninstall success"
}


upgrade() {
    # Check if installed binary and service
    if [ ! -f /usr/local/bin/server_box_monitor ] || [ ! -f /etc/systemd/system/server_box_monitor.service ]; then
        echo "Not installed. It will be installed"
        read -p "Press enter to continue"
        install
        exit 0
    fi

    rm -f /usr/local/bin/server_box_monitor

    download

    install_binary

    # Restart systemd service
    echo "Restarting systemd service..."
    systemctl restart server_box_monitor.service
    if [ $? -ne 0 ]; then
        echo "Restart systemd service failed"
        exit 1
    fi

    echo "Upgrade success"
}


case $1 in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    upgrade)
        upgrade
        ;;
    *)
        echo "Usage: $0 [install|uninstall|upgrade]"
        exit 1
        ;;
esac
