# Multi-stage build for smaller final image
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install

COPY frontend/ ./
RUN npm run build

# Rust build stage
FROM rust:slim AS backend-builder

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy manifests
COPY Cargo.toml Cargo.lock ./
COPY migrations/ ./migrations/

# Copy source code
COPY src/ ./src/

# Build the application
RUN cargo build --release

# Final runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    sqlite3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd --create-home --shell /bin/bash app

WORKDIR /app

# Copy binary from builder stage
COPY --from=backend-builder /app/target/release/server_box_monitor .
COPY --from=frontend-builder /app/frontend/dist ./static/

# Copy configuration files
COPY .env.example .env
COPY migrations/ ./migrations/

# Change ownership to app user
RUN chown -R app:app /app

USER app

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3770/api/v1/health || exit 1

EXPOSE 3770

CMD ["./server_box_monitor"]