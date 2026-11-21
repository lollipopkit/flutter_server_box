//! API tokens and MCP access policy (#1681): bearer credentials for MCP
//! clients, and the stored global ceiling (`mcp_policy`).
//!
//! Everything starts open — every [`Scope`] enabled and [`CommandMode::AllowAll`]
//! with no rules — and narrows where the operator asks, globally or on one
//! token. Effective reach is their intersection.
//!
//! The token itself is never here: a row holds its BLAKE3 digest, looked up on
//! every use.

use fl_pi_llm::permissions::rules::{CommandRules, RuleVerdict};
use serde::{Deserialize, Serialize};
use sqlx::{Row, SqlitePool};

use crate::utils::error::Result;

/// The prefix every API token starts with, so a credential pasted somewhere
/// says what it is — the same idea as `sbw_` on a watch token.
pub const PREFIX: &str = "sbt_";

/// Stored in `api_tokens.scopes` when a token holds every scope, including any
/// scope a newer build adds.
const ALL_MARKER: &str = "*";

/// What an MCP client may do, split fine enough that a token can read without
/// writing, manage containers without touching services, or run everything
/// except `power`.
///
/// There is no scope for managing these tokens or the account itself: a
/// credential that could mint credentials would outlive its own revocation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Scope {
    /// Machine readings and listings: status, metrics, capabilities, processes,
    /// services, containers, cron, tmux, firewall, storage, virt, stacks, users.
    Read,
    /// Reading files and directory listings (`fs_roots`, `fs_list`, `fs_stat`, `fs_read`).
    FsRead,
    /// Writing, creating, moving, chmodding and removing files (`fs_*`).
    FsWrite,
    /// Running shell commands (`run_command`), subject to [`CommandPolicy`].
    Exec,
    /// Signalling processes (`kill_process`).
    Process,
    /// Starting, stopping, restarting, enabling or disabling services (`service_action`).
    Service,
    /// Managing containers and images (`container_action`).
    Container,
    /// Editing scheduled tasks (`cron_edit`).
    Cron,
    /// Controlling virtual machines and LXC containers (`virt_power`).
    Virt,
    /// Controlling deployed web apps (`stack_action`).
    Stacks,
    /// Shutting down, rebooting or suspending this machine (`power`).
    Power,
}

impl Scope {
    pub const ALL: &'static [Scope] = &[
        Scope::Read,
        Scope::FsRead,
        Scope::FsWrite,
        Scope::Exec,
        Scope::Process,
        Scope::Service,
        Scope::Container,
        Scope::Cron,
        Scope::Virt,
        Scope::Stacks,
        Scope::Power,
    ];

    pub fn as_str(self) -> &'static str {
        match self {
            Scope::Read => "read",
            Scope::FsRead => "fs_read",
            Scope::FsWrite => "fs_write",
            Scope::Exec => "exec",
            Scope::Process => "process",
            Scope::Service => "service",
            Scope::Container => "container",
            Scope::Cron => "cron",
            Scope::Virt => "virt",
            Scope::Stacks => "stacks",
            Scope::Power => "power",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|sc| sc.as_str() == s)
    }
}

/// How [`CommandPolicy`] treats commands that no rule names.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CommandMode {
    /// Default: every command runs unless a `deny` (or `ask`) rule matches it.
    #[default]
    AllowAll,
    /// Only commands whose every part is covered by `allow` (and none by
    /// `deny` or `ask`) may run.
    Allowlist,
}

impl CommandMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::AllowAll => "allow_all",
            Self::Allowlist => "allowlist",
        }
    }

    pub fn parse(s: &str) -> Self {
        match s {
            "allowlist" => Self::Allowlist,
            _ => Self::AllowAll,
        }
    }
}

/// Rules on `run_command`, shared by `config.toml` (`[mcp.commands]`), the
/// stored global policy (`mcp_policy`), and each token (`api_tokens`).
///
/// Pattern syntax and matching come from [`fl_pi_llm::permissions::rules`].
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CommandPolicy {
    #[serde(default)]
    pub mode: CommandMode,
    #[serde(default)]
    pub allow: Vec<String>,
    #[serde(default)]
    pub deny: Vec<String>,
}

impl CommandPolicy {
    pub fn validate(&self) -> std::result::Result<(), String> {
        CommandRules {
            allow: self.allow.clone(),
            ask: Vec::new(),
            deny: self.deny.clone(),
        }
        .check()
    }

    /// Whether [command] may run under this policy, or why it was refused.
    pub fn evaluate(&self, command: &str) -> std::result::Result<(), String> {
        let rules = CommandRules {
            allow: self.allow.clone(),
            ask: Vec::new(),
            deny: self.deny.clone(),
        };
        match rules.verdict(command) {
            RuleVerdict::Deny(rule) => Err(format!("refused by deny rule `{rule}`")),
            RuleVerdict::Ask(rule) => Err(format!("refused by ask rule `{rule}`")),
            RuleVerdict::Allow(_) => Ok(()),
            RuleVerdict::None => match self.mode {
                CommandMode::AllowAll => Ok(()),
                CommandMode::Allowlist => Err("not covered by allow rules".into()),
            },
        }
    }
}

/// The global MCP ceiling stored in `mcp_policy`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct McpPolicy {
    pub scopes: Vec<Scope>,
    pub commands: CommandPolicy,
}

impl Default for McpPolicy {
    fn default() -> Self {
        Self {
            scopes: Scope::ALL.to_vec(),
            commands: CommandPolicy::default(),
        }
    }
}

/// A token's row, as the owner lists it or the bearer resolves it.
#[derive(Debug, Clone)]
pub struct Token {
    pub id: i64,
    pub name: String,
    pub scopes: Vec<Scope>,
    pub commands: CommandPolicy,
    pub created_at: String,
    pub expires_at: String,
    pub expired: bool,
    pub last_used_at: Option<String>,
    pub last_used_ip: Option<String>,
}

macro_rules! select_token {
    ($tail:literal) => {
        concat!(
            "SELECT id, name, scopes, command_mode, command_allow, command_deny, ",
            "created_at, expires_at, (expires_at <= CURRENT_TIMESTAMP) AS expired, last_used_at, last_used_ip ",
            "FROM api_tokens ",
            $tail
        )
    };
}

fn row_token(row: &sqlx::sqlite::SqliteRow) -> Token {
    let mode: String = row.get("command_mode");
    let allow: String = row.get("command_allow");
    let deny: String = row.get("command_deny");
    Token {
        id: row.get("id"),
        name: row.get("name"),
        scopes: parse_scopes(&row.get::<String, _>("scopes")),
        commands: CommandPolicy {
            mode: CommandMode::parse(&mode),
            allow: serde_json::from_str(&allow).unwrap_or_default(),
            deny: serde_json::from_str(&deny).unwrap_or_default(),
        },
        created_at: row.get("created_at"),
        expires_at: row.get("expires_at"),
        expired: row.get::<i64, _>("expired") != 0,
        last_used_at: row.get("last_used_at"),
        last_used_ip: row.get("last_used_ip"),
    }
}

/// Parses a `scopes` column: `*` means every known scope; unknown names are
/// dropped rather than refused so a retired scope does not break stored rows.
pub fn parse_scopes(raw: &str) -> Vec<Scope> {
    let trimmed = raw.trim();
    if trimmed == ALL_MARKER {
        return Scope::ALL.to_vec();
    }
    let mut out = Vec::new();
    for part in trimmed.split(',') {
        if let Some(s) = Scope::from_str(part.trim())
            && !out.contains(&s)
        {
            out.push(s);
        }
    }
    out
}

fn scopes_value(scopes: &[Scope]) -> String {
    if Scope::ALL.iter().all(|s| scopes.contains(s)) {
        return ALL_MARKER.to_string();
    }
    Scope::ALL
        .iter()
        .copied()
        .filter(|s| scopes.contains(s))
        .map(Scope::as_str)
        .collect::<Vec<_>>()
        .join(",")
}

fn disabled_scopes_value(enabled: &[Scope]) -> String {
    Scope::ALL
        .iter()
        .copied()
        .filter(|s| !enabled.contains(s))
        .map(Scope::as_str)
        .collect::<Vec<_>>()
        .join(",")
}

/// Reads the stored global MCP policy, or [`McpPolicy::default`] when untouched.
pub async fn load_policy(pool: &SqlitePool) -> Result<McpPolicy> {
    let row = sqlx::query_as::<_, (String, String, String, String)>(
        "SELECT disabled_scopes, command_mode, command_allow, command_deny FROM mcp_policy WHERE id = 1",
    )
    .fetch_optional(pool)
    .await?;
    Ok(match row {
        Some((disabled, mode, allow, deny)) => {
            let off: Vec<Scope> = disabled.split(',').filter_map(|s| Scope::from_str(s.trim())).collect();
            let scopes = Scope::ALL
                .iter()
                .copied()
                .filter(|s| !off.contains(s))
                .collect();
            McpPolicy {
                scopes,
                commands: CommandPolicy {
                    mode: CommandMode::parse(&mode),
                    allow: serde_json::from_str(&allow).unwrap_or_default(),
                    deny: serde_json::from_str(&deny).unwrap_or_default(),
                },
            }
        }
        None => McpPolicy::default(),
    })
}

/// Replaces the stored global MCP policy.
pub async fn store_policy(pool: &SqlitePool, policy: &McpPolicy) -> Result<()> {
    sqlx::query(
        "INSERT INTO mcp_policy (id, disabled_scopes, command_mode, command_allow, command_deny, updated_at) \
         VALUES (1, ?, ?, ?, ?, CURRENT_TIMESTAMP) \
         ON CONFLICT(id) DO UPDATE SET \
           disabled_scopes = excluded.disabled_scopes, \
           command_mode = excluded.command_mode, \
           command_allow = excluded.command_allow, \
           command_deny = excluded.command_deny, \
           updated_at = CURRENT_TIMESTAMP",
    )
    .bind(disabled_scopes_value(&policy.scopes))
    .bind(policy.commands.mode.as_str())
    .bind(serde_json::to_string(&policy.commands.allow).expect("vec serializes"))
    .bind(serde_json::to_string(&policy.commands.deny).expect("vec serializes"))
    .execute(pool)
    .await?;
    Ok(())
}

/// Stores a token's hash and its per-token policy.
pub async fn create(
    pool: &SqlitePool,
    name: &str,
    token_hash: &str,
    scopes: &[Scope],
    commands: &CommandPolicy,
    expires_at: &str,
) -> Result<i64> {
    let done = sqlx::query(
        "INSERT INTO api_tokens (name, token_hash, scopes, command_mode, command_allow, command_deny, expires_at) \
         VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(name)
    .bind(token_hash)
    .bind(scopes_value(scopes))
    .bind(commands.mode.as_str())
    .bind(serde_json::to_string(&commands.allow).expect("vec serializes"))
    .bind(serde_json::to_string(&commands.deny).expect("vec serializes"))
    .bind(expires_at)
    .execute(pool)
    .await?;
    Ok(done.last_insert_rowid())
}

/// Updates an existing token's name, scopes and command rules.
pub async fn update(
    pool: &SqlitePool,
    id: i64,
    name: &str,
    scopes: &[Scope],
    commands: &CommandPolicy,
) -> Result<bool> {
    let done = sqlx::query(
        "UPDATE api_tokens SET name = ?, scopes = ?, command_mode = ?, command_allow = ?, command_deny = ? \
         WHERE id = ?",
    )
    .bind(name)
    .bind(scopes_value(scopes))
    .bind(commands.mode.as_str())
    .bind(serde_json::to_string(&commands.allow).expect("vec serializes"))
    .bind(serde_json::to_string(&commands.deny).expect("vec serializes"))
    .bind(id)
    .execute(pool)
    .await?;
    Ok(done.rows_affected() == 1)
}

/// The token a hash stands for, if it exists and has not expired.
pub async fn find(pool: &SqlitePool, token_hash: &str) -> Result<Option<Token>> {
    let row = sqlx::query(select_token!("WHERE token_hash = ? AND expires_at > CURRENT_TIMESTAMP"))
        .bind(token_hash)
        .fetch_optional(pool)
        .await?;
    Ok(row.as_ref().map(row_token))
}

/// Every token, used, unused or expired.
pub async fn list(pool: &SqlitePool) -> Result<Vec<Token>> {
    let rows = sqlx::query(select_token!("ORDER BY id")).fetch_all(pool).await?;
    Ok(rows.iter().map(row_token).collect())
}

/// One token by id.
pub async fn get(pool: &SqlitePool, id: i64) -> Result<Option<Token>> {
    let row = sqlx::query(select_token!("WHERE id = ?"))
        .bind(id)
        .fetch_optional(pool)
        .await?;
    Ok(row.as_ref().map(row_token))
}

/// How stale `last_used_at` may be before a use rewrites it.
const USE_INTERVAL_SECS: i64 = 60;

/// Records a use at most once per [`USE_INTERVAL_SECS`].
pub async fn record_use(pool: &SqlitePool, id: i64, ip: Option<&str>) -> Result<()> {
    sqlx::query(
        "UPDATE api_tokens SET last_used_at = CURRENT_TIMESTAMP, last_used_ip = ? \
         WHERE id = ? AND (last_used_at IS NULL OR last_used_at < datetime('now', ?))",
    )
    .bind(ip)
    .bind(id)
    .bind(format!("-{USE_INTERVAL_SECS} seconds"))
    .execute(pool)
    .await?;
    Ok(())
}

/// Deletes a token.
pub async fn revoke(pool: &SqlitePool, id: i64) -> Result<bool> {
    let done = sqlx::query("DELETE FROM api_tokens WHERE id = ?")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(done.rows_affected() == 1)
}

/// BLAKE3 hex digest of a token.
pub fn hash(token: &str) -> String {
    blake3::hash(token.as_bytes()).to_hex().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    async fn pool() -> SqlitePool {
        let pool = SqlitePool::connect("sqlite::memory:").await.unwrap();
        sqlx::migrate!("./migrations").run(&pool).await.unwrap();
        pool
    }

    #[test]
    fn scopes_round_trip_and_wildcard_expands() {
        assert_eq!(parse_scopes("*"), Scope::ALL);
        assert_eq!(scopes_value(Scope::ALL), "*");
        assert_eq!(parse_scopes("read,exec"), vec![Scope::Read, Scope::Exec]);
        assert_eq!(parse_scopes("read,retired"), vec![Scope::Read]);
        assert!(parse_scopes("").is_empty());
    }

    #[test]
    fn command_policy_defaults_open_and_respects_rules() {
        let mut p = CommandPolicy::default();
        assert!(p.evaluate("echo hi > /tmp/x && uname -a").is_ok());
        p.deny.push("rm -rf *".into());
        assert!(p.evaluate("echo hi && sudo /bin/rm -rf /tmp/x").is_err());
        assert!(p.evaluate("ls -la").is_ok());

        p.mode = CommandMode::Allowlist;
        p.allow.push("ls *".into());
        assert!(p.evaluate("ls -la").is_ok());
        assert!(p.evaluate("df -h").is_err());
    }

    #[tokio::test]
    async fn policy_and_tokens_persist_update_and_expire() {
        let pool = pool().await;
        assert_eq!(load_policy(&pool).await.unwrap(), McpPolicy::default());

        let narrowed = McpPolicy {
            scopes: vec![Scope::Read, Scope::Exec],
            commands: CommandPolicy {
                mode: CommandMode::AllowAll,
                allow: Vec::new(),
                deny: vec!["reboot*".into()],
            },
        };
        store_policy(&pool, &narrowed).await.unwrap();
        assert_eq!(load_policy(&pool).await.unwrap(), narrowed);

        let digest = hash("sbt_example");
        let id = create(
            &pool,
            "ci",
            &digest,
            Scope::ALL,
            &CommandPolicy::default(),
            "9999-12-31 00:00:00",
        )
        .await
        .unwrap();
        create(
            &pool,
            "old",
            &hash("sbt_old"),
            &[Scope::Read],
            &CommandPolicy::default(),
            "2001-01-01 00:00:00",
        )
        .await
        .unwrap();

        let found = find(&pool, &digest).await.unwrap().expect("there");
        assert_eq!(found.name, "ci");
        assert_eq!(found.scopes, Scope::ALL);
        assert!(!found.expired);
        assert!(find(&pool, &hash("sbt_old")).await.unwrap().is_none());

        let custom_cmds = CommandPolicy {
            mode: CommandMode::Allowlist,
            allow: vec!["git status".into()],
            deny: Vec::new(),
        };
        assert!(update(&pool, id, "ci-ro", &[Scope::Read, Scope::Exec], &custom_cmds).await.unwrap());
        let updated = get(&pool, id).await.unwrap().unwrap();
        assert_eq!(updated.name, "ci-ro");
        assert_eq!(updated.scopes, vec![Scope::Read, Scope::Exec]);
        assert_eq!(updated.commands, custom_cmds);

        record_use(&pool, found.id, Some("127.0.0.1")).await.unwrap();
        let all = list(&pool).await.unwrap();
        assert_eq!(all[0].last_used_ip.as_deref(), Some("127.0.0.1"));
        assert!(!all[0].expired);
        assert!(all[1].expired);

        assert!(revoke(&pool, found.id).await.unwrap());
        assert!(!revoke(&pool, found.id).await.unwrap());
    }
}
