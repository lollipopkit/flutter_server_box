# 本地/compose 用:容器内完整构建(Alpine/musl)。
# CI 发布用 monitor/Dockerfile.ci(直接复用 workflow 编译好的 musl bin)。
# 两者的运行时阶段需保持一致。
# 构建上下文为 monorepo 根:docker build -f monitor/Dockerfile .
FROM node:24-alpine AS frontend-builder

# Layout mirrors the repo: the panel imports the app SDK beside it
# (/app/monitor/sdk/lkui from /app/monitor/frontend).
WORKDIR /app/monitor/frontend
COPY monitor/frontend/package*.json ./
RUN npm install

COPY monitor/frontend/ ./
# The desk's app bridge imports the protocol from the app SDK's source.
COPY monitor/sdk/lkui/src/ /app/monitor/sdk/lkui/src/
RUN npm run build

# Rust build stage
FROM rust:1-alpine AS backend-builder

RUN apk add --no-cache musl-dev

WORKDIR /app

# Copy manifests and shared parser crate
COPY monitor/Cargo.toml Cargo.lock ./
COPY crates/ ./crates/
# fl_lib's theme reader (`fl_theme`), from the submodule: the build context
# needs it checked out.
COPY packages/fl_lib/rust/theme/ ./fl_theme/
# fl_pi_llm's runtime (Agent mode's pi), from its submodule likewise.
COPY packages/fl_pi_llm/rust/ ./fl_pi_llm/
COPY monitor/migrations/ ./migrations/
COPY monitor/.sqlx/ ./.sqlx/

# Copy source code
COPY monitor/src/ ./src/
# `api::benchmark` embeds yabs with `include_str!("../../../assets/yabs.b64")`,
# relative to `src/api/`: in the repository that is the root's `assets/`, and
# with `src/` at `/app/src` here it is `/assets`.
COPY assets/yabs.b64 /assets/yabs.b64
# The theme store's catalog, embedded the same way (`api/desk_themes.rs`).
COPY assets/catalog/repos.toml /assets/catalog/repos.toml

# 独立构建 monitor(脱离 monorepo workspace),修正 crates/ 下各依赖的相对路径
#
# Every `../crates/` path, not one crate by name: naming sbm_parser alone left
# sbm_native pointing at /crates, and `cargo build` failed with "failed to
# load source for dependency `sbm_native`".
#
# That also puts this build outside everything the workspace Cargo.toml says:
# `monitor/Cargo.toml` becomes the root, so neither `[profile.release] strip`
# nor the `release-monitor` profile exists here. Until these were added the
# image carried an unstripped binary — the one build of this crate that did.
# Environment variables rather than a profile section, since the section would
# have to be written into a manifest the workspace also reads, where cargo
# ignores a non-root package's profiles with a warning.
RUN sed -i -e 's|path = "../crates/|path = "crates/|' \
           -e 's|path = "../packages/fl_lib/rust/theme"|path = "fl_theme"|' \
           -e 's|path = "../packages/fl_pi_llm/rust"|path = "fl_pi_llm"|' Cargo.toml \
    && CARGO_PROFILE_RELEASE_STRIP=true \
       CARGO_PROFILE_RELEASE_LTO=fat \
       CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 \
       cargo build --release

# Final runtime stage(与 Dockerfile.ci 保持一致)
FROM alpine:3.24

# ca-certificates for reqwest rustls; collection commands (uptime/ps/cat) and
# the healthcheck's wget come from busybox — no curl, avoiding its dependency chain
RUN apk add --no-cache ca-certificates

RUN adduser -D app

WORKDIR /app

# server.rs 从工作目录下的 frontend/dist 提供静态文件,路径必须一致
COPY --from=backend-builder /app/target/release/server_box_monitor .
COPY --from=frontend-builder /app/monitor/frontend/dist ./frontend/dist/

# Copy configuration files
COPY monitor/.env.example .env
COPY monitor/migrations/ ./migrations/

RUN chown -R app:app /app

USER app

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:3770/api/v1/health || exit 1

EXPOSE 3770

CMD ["./server_box_monitor"]
