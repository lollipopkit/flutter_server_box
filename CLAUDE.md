# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ServerBox Monitor is a Rust-based server monitoring application rewritten from Go, featuring a modern React frontend. It monitors server status (CPU, memory, disk, network, temperature) and sends notifications via configurable push mechanisms (webhooks, iOS notifications) when thresholds are exceeded. This is part of the [ServerBox](https://github.com/lollipopkit/flutter_server_box) project ecosystem.

## Development Commands

### Building
```bash
# Build backend
cargo build

# Build for release
cargo build --release

# Build frontend
cd frontend && npm install && npm run build
```

### Running
```bash
# Run backend (listens on 0.0.0.0:3770 by default)
cargo run

# Run frontend dev server (separate terminal)
cd frontend && npm run dev

# Set up environment
cp .env.example .env
```

### Testing
```bash
# Run all backend tests
cargo test

# Run integration tests
cargo test --test integration_tests

# Run frontend tests
cd frontend && npm run test

# Run with coverage
cd frontend && npm run test:coverage
```

### Dependencies
```bash
# Backend dependencies
cargo update

# Frontend dependencies
cd frontend && npm install
```

### Database
```bash
# Run migrations (requires DATABASE_URL)
cargo sqlx migrate run

# Prepare SQL queries for offline compilation
cargo sqlx prepare
```

## Architecture

### Backend (Rust - `src/`)

- **`main.rs`**: Application entry point, coordinates monitoring loop and web server
- **`config.rs`**: Configuration management with .env support and TOML/JSON config files
- **`server.rs`**: ntex-based web server with API endpoints and JWT authentication
- **`monitoring.rs`**: System metrics collection using sysinfo crate
- **`rules.rs`**: Monitoring rule evaluation and threshold checking
- **`push.rs`**: Push notification system (webhook, iOS)
- **`auth.rs`**: JWT token generation and validation
- **`database.rs`**: SQLite database initialization and migrations
- **`error.rs`**: Centralized error types and handling

### Frontend (React - `frontend/src/`)

- **React 18** with TypeScript and TailwindCSS
- **`pages/`**: Main page components (Dashboard, Login)
- **`components/`**: Reusable UI components
- **`services/`**: API client with authentication
- **`hooks/`**: Custom React hooks
- **`types/`**: TypeScript type definitions

### Legacy Components (Transition Period)

- **`cmd/`, `model/`, `runner/`, `web/`**: Original Go implementation (being phased out)
- **`res/monitor.sh`**: Shell script for system metrics (used by both versions)

### Key Design Patterns

1. **Async-first architecture**: Uses tokio for async runtime with concurrent tasks
2. **Type-safe database**: sqlx with compile-time query verification
3. **JWT authentication**: Secure token-based API access
4. **Configuration-driven monitoring**: Rules and push configs in TOML/env files
5. **Rate limiting**: Built-in rate limiting for push notifications
6. **Separation of concerns**: Clean module boundaries between monitoring, API, and notifications

### Configuration

Uses environment variables (.env file) and TOML config files:
- **Environment**: Database URL, JWT secret, server host/port, TLS settings
- **TOML Config**: Monitoring rules, push notification settings, thresholds
- **Configuration file**: Defaults to `config.toml` (with JSON fallback support for `config.json`)

### Database Schema

SQLite database with migrations in `migrations/`:
- System metrics history
- User authentication
- Configuration storage

## Release and Deployment

### Docker
```bash
# Build with Docker
docker build -t server-box-monitor .

# Run with Docker
docker run -p 3770:3770 -v $(pwd)/data:/app/data server-box-monitor
```

### Installation
```bash
# Install as systemd service (uses install.sh from Go version)
sudo ./install.sh install

# Manual production deployment
cargo build --release
cd frontend && npm run build
./target/release/server_box_monitor
```

### Environment Variables

- `SBM_HOST`: Server host (default: 0.0.0.0)
- `SBM_PORT`: Server port (default: 3770)
- `SBM_TLS_CERT`: TLS certificate path
- `SBM_TLS_KEY`: TLS private key path
- `DATABASE_URL`: SQLite database URL
- `JWT_SECRET`: JWT signing secret
- `RUST_LOG`: Logging level

## Common Development Tasks

### Adding New API Endpoints
Add routes in `src/server.rs` following the existing ntex pattern with JWT middleware.

### Adding New Monitoring Metrics
Extend `src/monitoring.rs` and update the database schema with new migrations.

### Updating Frontend Components
Use existing patterns in `frontend/src/components/` with TypeScript and TailwindCSS.

### Fixing Database Issues
Ensure `DATABASE_URL` is set or run `cargo sqlx prepare` to update query cache for offline compilation.