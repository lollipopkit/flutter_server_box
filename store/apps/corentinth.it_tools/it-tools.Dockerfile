# IT-Tools (GPL-3.0), its release's static build served by Caddy, built on the
# machine by ServerBox Monitor (`build:` in compose.yaml).
#
# Written for ServerBox Monitor: upstream's image (corentinth/it-tools) was
# last built in 2024 on nginx:stable-alpine of that time, an end-of-life
# Alpine. This serves the same release's dist/ (the release asset, checked
# against the SHA-256 written here, computed from the asset on 2026-10-17)
# with Alpine's Caddy, as upstream's nginx.conf does: every unknown path gets
# index.html, for the page's own routes.

ARG ALPINE_VERSION=3.24
FROM alpine:${ALPINE_VERSION}

ARG IT_TOOLS_VERSION=2024.10.22-7ca5933
ARG IT_TOOLS_SHA256=eef276d675db6053bdc65cd8482a566785561c70eed5035a0e05b0e627b0989d

RUN apk add --no-cache caddy

RUN wget -q -O /tmp/it-tools.zip "https://github.com/CorentinTh/it-tools/releases/download/v${IT_TOOLS_VERSION}/it-tools-${IT_TOOLS_VERSION}.zip" \
 && echo "${IT_TOOLS_SHA256}  /tmp/it-tools.zip" | sha256sum -c - \
 && unzip -q /tmp/it-tools.zip -d /tmp/it-tools \
 && mv /tmp/it-tools/dist /srv/it-tools \
 && rm -rf /tmp/it-tools /tmp/it-tools.zip

COPY <<"EOF" /etc/caddy/Caddyfile
{
	admin off
	auto_https off
	persist_config off
}

:8080 {
	encode gzip
	root * /srv/it-tools
	try_files {path} {path}/ /index.html
	file_server
}
EOF

# Caddy keeps its state under the home directory, which a user from compose.yaml
# may not have.
ENV XDG_DATA_HOME=/tmp/caddy XDG_CONFIG_HOME=/tmp/caddy
EXPOSE 8080
ENTRYPOINT ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
