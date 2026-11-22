//! What an MCP token may do: its [`Scope`]s, and the [`CommandPolicy`] its
//! `run_command` is held to. The same model for every ServerBox MCP server:
//! the monitor stores it in its database, the app in its own file.
//!
//! Everything starts open — every scope and [`CommandMode::AllowAll`] with
//! no rules — and narrows where the operator asks. Effective reach is the
//! intersection of every layer that has a say.

use fl_pi_rules::{CommandRules, RuleVerdict};
use serde::{Deserialize, Serialize};

/// What an MCP client may do, split fine enough that a token can read without
/// writing, manage containers without touching services, or run everything
/// except `power`.
///
/// There is no scope for managing tokens or the account itself: a credential
/// that could mint credentials would outlive its own revocation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Scope {
    /// Readings and listings: status, metrics, capabilities, processes,
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
    /// Shutting down, rebooting or suspending the machine (`power`).
    Power,
    /// Changing the app's own preferences (`app_setting_set`). The app's only.
    Settings,
}

impl Scope {
    /// Every scope a monitor serves.
    pub const MONITOR: &'static [Scope] = &[
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

    /// Every scope the app serves: what it reaches on a server through a
    /// shell, and its own preferences.
    pub const APP: &'static [Scope] = &[
        Scope::Read,
        Scope::Exec,
        Scope::Process,
        Scope::Service,
        Scope::Container,
        Scope::Settings,
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
            Scope::Settings => "settings",
        }
    }

    /// [s] as one of [among]: a scope another server serves is no scope here.
    pub fn parse(among: &[Scope], s: &str) -> Option<Self> {
        among.iter().copied().find(|sc| sc.as_str() == s)
    }
}

/// How [`CommandPolicy`] treats commands that no rule names.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CommandMode {
    /// Every command runs unless a `deny` rule matches it.
    #[default]
    AllowAll,
    /// Only commands whose every part is covered by `allow` (and none by
    /// `deny`) may run.
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

/// Rules on `run_command`. Pattern syntax and matching are
/// [`fl_pi_rules`]'s, the Agent's own command rules.
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
    fn rules(&self) -> CommandRules {
        CommandRules {
            allow: self.allow.clone(),
            ask: Vec::new(),
            deny: self.deny.clone(),
        }
    }

    /// Why the policy cannot be stored, naming the list and the rule.
    pub fn validate(&self) -> Result<(), String> {
        self.rules().check()
    }

    /// Whether [command] may run under this policy, or why it was refused.
    pub fn evaluate(&self, command: &str) -> Result<(), String> {
        match self.rules().verdict(command) {
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

/// [command] under every layer in turn, each named in the refusal.
pub fn evaluate_layers(command: &str, layers: &[(&str, &CommandPolicy)]) -> Result<(), String> {
    for (layer, policy) in layers {
        policy.evaluate(command).map_err(|why| format!("refused by {layer}: {why}"))?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_scope_is_parsed_only_among_the_servers_own() {
        assert_eq!(Scope::parse(Scope::MONITOR, "power"), Some(Scope::Power));
        assert_eq!(Scope::parse(Scope::MONITOR, "settings"), None);
        assert_eq!(Scope::parse(Scope::APP, "settings"), Some(Scope::Settings));
        assert_eq!(Scope::parse(Scope::APP, "power"), None);
        for scope in Scope::MONITOR.iter().chain(Scope::APP) {
            let wire = serde_json::to_value(scope).unwrap();
            assert_eq!(wire, scope.as_str());
        }
    }

    #[test]
    fn the_first_layer_that_refuses_is_named() {
        let open = CommandPolicy::default();
        let strict = CommandPolicy { mode: CommandMode::Allowlist, allow: vec!["ls *".into()], deny: vec![] };
        let deny = CommandPolicy { deny: vec!["rm *".into()], ..Default::default() };
        assert!(evaluate_layers("ls /", &[("a", &open), ("b", &strict)]).is_ok());
        let why = evaluate_layers("rm -rf /", &[("global", &deny), ("token", &strict)]).unwrap_err();
        assert!(why.starts_with("refused by global: refused by deny rule"), "{why}");
        let why = evaluate_layers("cat /etc/passwd", &[("global", &open), ("token", &strict)]).unwrap_err();
        assert_eq!(why, "refused by token: not covered by allow rules");
    }
}
