# 本地/compose 用:容器内完整构建(Alpine/musl)。
# CI 发布用 monitor/Dockerfile.ci(直接复用 workflow 编译好的 musl bin)。
# 两者的运行时阶段需保持一致。
# 构建上下文为 monorepo 根:docker build -f monitor/Dockerfile .
FROM node:22-alpine AS frontend-builder

# Layout mirrors the repo so the panel's file:../../packages/webui link
# resolves (/app/packages/webui from /app/monitor/frontend)
WORKDIR /app/monitor/frontend
COPY packages/ /app/packages/
COPY monitor/frontend/package*.json ./
RUN npm install

COPY monitor/frontend/ ./
RUN npm run build

# Rust build stage
FROM rust:alpine AS backend-builder

RUN apk add --no-cache musl-dev

WORKDIR /app

# Copy manifests and shared parser crate
COPY monitor/Cargo.toml Cargo.lock ./
COPY crates/ ./crates/
COPY monitor/migrations/ ./migrations/
COPY monitor/.sqlx/ ./.sqlx/

# Copy source code
COPY monitor/src/ ./src/

# 独立构建 monitor(脱离 monorepo workspace),修正 sbm_parser 相对路径
RUN sed -i 's|path = "../crates/sbm_parser"|path = "crates/sbm_parser"|' Cargo.toml \
    && cargo build --release

# Final runtime stage(与 Dockerfile.ci 保持一致)
FROM alpine

# uptime/ps/cat 等采集命令由 busybox 提供;curl 用于 healthcheck
RUN apk add --no-cache ca-certificates curl

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
    CMD curl -f http://localhost:3770/api/v1/health || exit 1

EXPOSE 3770

CMD ["./server_box_monitor"]
