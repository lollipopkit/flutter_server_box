# AriaNg (MIT) and aria2 (GPL-2.0-or-later) in one image, built on the machine
# by ServerBox Monitor (`build:` in compose.yaml).
#
# Written for ServerBox Monitor: no maintained image carries both on a current
# base (hurlenko/aria2-ariang is on Alpine 3.16, end of life, and fetches
# AriaNg without checking the certificate). aria2 and Caddy are Alpine's
# packages; AriaNg is its release archive, checked against the SHA-256 GitHub
# lists for the asset.
#
# - Caddy serves AriaNg on 8080 and passes /jsonrpc to aria2 (6800, loopback
#   only), so the browser reaches the RPC on the page's own address.
# - AriaNg's default RPC port is the page's port instead of 6800, so it
#   connects through the desk's window as well as on the published port.
# - BitTorrent and DHT listen on PEER_PORT (TCP and UDP), the port compose.yaml
#   publishes, so peers reach it.
# - Everything runs as the user compose.yaml names; nothing needs root.

ARG ALPINE_VERSION=3.24
FROM alpine:${ALPINE_VERSION}

ARG ARIANG_VERSION=1.3.15
ARG ARIANG_SHA256=d2317e441966ad31f1e342cb6a6cc1c51808fb0a10cf6e39cb30b0517b3e7823

RUN apk add --no-cache aria2 caddy

RUN wget -q -O /tmp/ariang.zip "https://github.com/mayswind/AriaNg/releases/download/${ARIANG_VERSION}/AriaNg-${ARIANG_VERSION}.zip" \
 && echo "${ARIANG_SHA256}  /tmp/ariang.zip" | sha256sum -c - \
 && mkdir -p /srv/ariang \
 && unzip -q /tmp/ariang.zip -d /srv/ariang \
 && rm /tmp/ariang.zip \
 && sed -i 's/rpcPort:"6800"/rpcPort:(location.port||(location.protocol==="https:"?"443":"80"))/' /srv/ariang/js/aria-ng-*.js \
 && grep -q 'rpcPort:(location.port' /srv/ariang/js/aria-ng-*.js

COPY <<"EOF" /etc/caddy/Caddyfile
{
	admin off
	auto_https off
	persist_config off
}

:8080 {
	encode gzip
	reverse_proxy /jsonrpc 127.0.0.1:6800
	root * /srv/ariang
	file_server
}
EOF

# The settings a new install starts with; /conf/aria2.conf is the admin's
# afterwards. The start script sets the download folder, the peer port and the
# RPC itself.
COPY <<"EOF" /etc/aria2/aria2.conf
continue=true
max-concurrent-downloads=5
max-connection-per-server=5
split=5
min-split-size=10M
file-allocation=none
disk-cache=32M
input-file=/conf/aria2.session
save-session=/conf/aria2.session
save-session-interval=60
bt-save-metadata=true
dht-file-path=/conf/dht.dat
dht-file-path6=/conf/dht6.dat
EOF

# The RPC secret goes into a 0600 copy of the settings, never on a command
# line (other users of the host see those).
COPY --chmod=755 <<"EOF" /usr/local/bin/start
#!/bin/sh
set -eu
conf=/conf/aria2.conf
[ -f "$conf" ] || cp /etc/aria2/aria2.conf "$conf"
touch /conf/aria2.session
run=$(mktemp)
chmod 600 "$run"
grep -v -E '^[[:space:]]*(dir|enable-rpc|rpc-listen-all|rpc-listen-port|rpc-secret|rpc-allow-origin-all|listen-port|dht-listen-port)[[:space:]]*=' "$conf" > "$run" || true
printf '%s\n' dir=/downloads enable-rpc=true rpc-listen-all=false rpc-listen-port=6800 "rpc-secret=${RPC_SECRET}" \
  "listen-port=${PEER_PORT}" "dht-listen-port=${PEER_PORT}" >> "$run"
caddy start --config /etc/caddy/Caddyfile --adapter caddyfile
exec aria2c --conf-path="$run"
EOF

# Caddy keeps its state under the home directory, which a user from compose.yaml
# may not have.
ENV XDG_DATA_HOME=/tmp/caddy XDG_CONFIG_HOME=/tmp/caddy
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/start"]
