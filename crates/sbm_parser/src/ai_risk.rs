//! How much a shell command can be trusted, for the AI agent's review step.
//!
//! Ported from the app's `AskAiCommand.classifyRisk`
//! (`lib/data/model/ai/ask_ai_models.dart`). TODO(migration): the app's Dart copy
//! should read this one instead, so that one command text gets one verdict
//! whichever client is looking at it.
//!
//! The lists are an **allowlist with a blocklist in front of it**, and the
//! difference between its two negative answers matters. A command matching
//! nothing is [`CommandRisk::Unknown`] — nothing was established about it, which
//! is a reason not to run it unreviewed and not a claim that it writes anything.
//! `sleep 60` is the plainest example.
//!
//! Two things the app's version has and this one does not, both stated rather
//! than left to be rediscovered:
//!
//! - **No lookaround.** `regex` has none, and the app's one use of it is inside
//!   its read-only `sed` entry, where a negative lookahead is combined with a
//!   `\b` that follows `\s+`. That `\b` sits between whitespace and the next
//!   character, so it holds only when the next character is a word character —
//!   which no `sed` flag is. The entry therefore matches a `sed` whose first
//!   argument is a bare word and nothing else, so every real `sed` read was
//!   already answered `unknown` by the app. This module reaches that verdict
//!   from a rule instead: **`sed` is not on the read-only list in any form**,
//!   because its `e` flag and `e` command execute what they are given, its `-i`
//!   writes, and a rule that admits scripts has to parse `sed`. The one input
//!   where the two disagree is a `sed` whose first argument is a bare word
//!   (`sudo sed p`, which prints every line twice); the app calls it read-only
//!   and this calls it unknown.
//! - **No `unvettedHost`.** The app withholds along a second axis for a host
//!   nobody has accepted yet. There is no equivalent here: this agent's host is
//!   the one it runs on, accepted when it was installed.
//!
//! The verdicts below were not read off the Dart source — they are what the
//! Dart function prints, run as extracted verbatim, so a rearrangement of the
//! lists that only looks equivalent fails a test.

use regex::Regex;
use std::sync::LazyLock;

/// What the agent could establish about one command, from its text alone.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CommandRisk {
    /// Every segment is on the read-only list and nothing chains them.
    ReadOnly,
    /// Not a known mutation and not a known read.
    Unknown,
    /// A known change to a service, a package, a file or a container.
    Caution,
    /// A change that cannot be undone.
    Destructive,
}

impl CommandRisk {
    /// The name a client reads. A spelling here is what a panel draws and what a
    /// stored verdict is compared against.
    pub const fn as_str(self) -> &'static str {
        match self {
            CommandRisk::ReadOnly => "read_only",
            CommandRisk::Unknown => "unknown",
            CommandRisk::Caution => "caution",
            CommandRisk::Destructive => "destructive",
        }
    }

    /// Whether this may run without a person reading it first.
    ///
    /// Only [`CommandRisk::ReadOnly`], and only when the operator has switched
    /// unreviewed runs on — the caller asks both.
    pub const fn is_read_only(self) -> bool {
        matches!(self, CommandRisk::ReadOnly)
    }
}

/// The redirection a read-only command may use to silence an expected error,
/// removed before anything else is checked: `grep x /var/log/y 2>/dev/null` is a
/// read, and the general redirection rule would call it a write.
static DEV_NULL: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\b[012]?>>?\s*/dev/null\b").expect("valid pattern"));

static DESTRUCTIVE: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    compile(&[
        r"(^|[;&|]\s*)(sudo\s+)?rm\s",
        r"(^|[;&|]\s*)(sudo\s+)?(shred|wipefs|mkfs(\.[a-z0-9]+)?)\b",
        r"(^|[;&|]\s*)(sudo\s+)?dd\s+.*\bof=",
        r"\b(find|xargs)\b.*\b-delete\b",
        r"\b(find|xargs)\b.*\brm\b",
        r"\b(git\s+reset\s+--hard|git\s+clean\s+-[^\s]*f)\b",
        r"\b(docker|podman)\s+(system\s+)?prune\b",
        r"\bkubectl\s+delete\b",
        r"\b(drop|truncate)\s+(database|table)\b",
        r"\bdelete\s+from\b",
        r"(^|[;&|]\s*)(shutdown|reboot|poweroff|halt)\b",
        r"\b(remove-item|format-volume|clear-disk)\b",
        r"(^|[;&|]\s*)(del|rmdir)\s",
        r":\s*\(\s*\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:",
    ])
});

static MUTATING: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    compile(&[
        r"(^|[^<])>>?\s*[^&]",
        r"\|\s*(sudo\s+)?(sh|bash|zsh|fish|python\d*|perl|ruby|node|pwsh|powershell|cmd)\b",
        r"(^|[;&|]\s*)(eval|source)\b|(^|[;&|]\s*)\.\s+",
        r"\$\(|`",
        r"(^|[;&|]\s*)(sh|bash|zsh|fish)\s+-c\b",
        r"\bfind\b.*\s-exec(dir)?\b",
        r"\bawk\b.*\bsystem\s*\(",
        r"(^|[;&|]\s*)(sudo\s+)?(mv|cp|touch|mkdir|chmod|chown|ln)\s",
        r"(^|[;&|]\s*)(sudo\s+)?tee\b",
        r"\bsed\s+[^;&|]*\s-i([.\s]|$)",
        r"\b(systemctl|service)\s+(start|stop|restart|reload|enable|disable|mask|unmask)\b",
        r"(^|[;&|]\s*)(sudo\s+)?(kill|pkill|killall)\b",
        r"\b(apt|apt-get|dnf|yum|pacman|zypper|apk|brew)\s+(install|remove|erase|upgrade|update)\b",
        r"\b(docker|podman)\s+(start|stop|restart|rm|rmi|pull|push|build|run|exec)\b",
        r"\b(docker|podman)\s+compose\s+(up|down|restart|pull|build)\b",
        r"\bkubectl\s+(apply|create|edit|patch|replace|scale|rollout|set)\b",
        r"\bgit\s+(add|commit|push|pull|merge|rebase|checkout|switch|restore|tag)\b",
        r"\b(curl|wget)\b.*\s(-o|--output|-x\s+(post|put|patch|delete)|--request\s+(post|put|patch|delete))\b",
        r"\b(set-content|add-content|new-item|copy-item|move-item|rename-item|start-service|stop-service|restart-service)\b",
    ])
});

/// What a segment may start with and still be a read. `sed` is absent
/// deliberately — see the module note.
static READ_ONLY_STARTS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    compile(&[
        r"^(ls|pwd|whoami|id|groups|uname|hostname|uptime|date|cal)\b",
        r"^(cat|head|tail|less|more|grep|egrep|fgrep|rg|awk|cut|sort|uniq|wc|tr)\b",
        r"^(df|du|free|vmstat|iostat|mpstat|top|ps|pgrep|lsof|stat|file|readlink|realpath)\b",
        r"^(find|locate|which|whereis|type|command\s+-v)\b",
        r"^(ip|ss|netstat|ifconfig|route|ping|traceroute|tracepath|dig|nslookup|host)\b",
        r"^(journalctl|dmesg|systemctl\s+(status|show|is-active|is-enabled|list-)|service\s+[^\s]+\s+status)\b",
        r"^(docker|podman)\s+(ps|images|inspect|logs|stats|info|version)\b",
        r"^(docker|podman)\s+compose\s+(ps|logs|config|ls)\b",
        r"^kubectl\s+(get|describe|logs|api-resources|api-versions|cluster-info|version)\b",
        r"^git\s+(status|diff|log|show|branch|remote|rev-parse|ls-files|ls-tree)\b",
        r"^(get-[a-z0-9-]+|test-[a-z0-9-]+|select-[a-z0-9-]+|where-object|measure-object|compare-object|tasklist|systeminfo|dir|type)\b",
    ])
});

/// A leading `sudo`, or one or more leading assignments — `env FOO=1`.
static SUDO: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^sudo\s+").expect("valid pattern"));
static ENV_ASSIGNMENTS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(env\s+)?([a-z_][a-z0-9_]*=[^\s]+\s+)+").expect("valid pattern")
});
static CHAIN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"&&|\|\||[;\r\n]|&").expect("valid pattern"));
static JOB_CONTROL: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\d*>&\d+").expect("valid pattern"));

fn compile(patterns: &[&str]) -> Vec<Regex> {
    patterns
        .iter()
        .map(|p| Regex::new(p).unwrap_or_else(|e| panic!("invalid pattern {p:?}: {e}")))
        .collect()
}

/// What one command's text says about whether it changes the machine.
///
/// The verdict is about the text and not about the machine: it is what lets a
/// request run without a person reading it, so anything unrecognised is
/// [`CommandRisk::Unknown`] rather than being trusted by default.
pub fn classify(command: &str) -> CommandRisk {
    let mut normalized = command.trim().to_lowercase();
    if normalized.is_empty() {
        // Nothing to run, and nothing established about it. A caller that asked
        // is about to run something, so the answer refuses rather than permits.
        return CommandRisk::Caution;
    }
    normalized = DEV_NULL.replace_all(&normalized, "").into_owned();

    if DESTRUCTIVE.iter().any(|p| p.is_match(&normalized)) {
        return CommandRisk::Destructive;
    }

    // Before the chain rule: a mutation inside a chain is a change, not an
    // unknown. `uptime && systemctl restart nginx` is the caution it contains.
    if MUTATING.iter().any(|p| p.is_match(&normalized)) {
        return CommandRisk::Caution;
    }

    // Chained commands are not taken apart, so nothing can be established about
    // them — not even that they change anything. `ls && pwd` is as unanalysed
    // here as `ls && rm -rf /`, and only the first of those would be a lie to
    // call a system change. Job-control redirections go first: `2>&1` chains
    // nothing.
    let chain_candidate = JOB_CONTROL.replace_all(&normalized, "");
    if CHAIN.is_match(&chain_candidate) {
        return CommandRisk::Unknown;
    }

    let segments = normalized.split('|');
    if segments
        .into_iter()
        .all(|segment| !segment.trim().is_empty() && is_read_only_segment(segment))
    {
        return CommandRisk::ReadOnly;
    }
    CommandRisk::Unknown
}

fn is_read_only_segment(segment: &str) -> bool {
    let segment = segment.trim();
    let segment = SUDO.replace(segment, "");
    let segment = ENV_ASSIGNMENTS.replace(&segment, "");
    READ_ONLY_STARTS.iter().any(|p| p.is_match(&segment))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The app's own cases, plus the ones this port had to decide. Every expected
    /// value is what the Dart function printed when run as extracted verbatim
    /// (`dart run` over a copy of `classifyRisk` with the enum spelled as a
    /// string), not a reading of its source.
    const DART_VERDICTS: &[(&str, CommandRisk)] = &[
        ("systemctl status nginx", CommandRisk::ReadOnly),
        ("docker ps --format json | head", CommandRisk::ReadOnly),
        ("sudo journalctl -u sshd -n 100", CommandRisk::ReadOnly),
        ("grep box /var/log/syslog 2>/dev/null", CommandRisk::ReadOnly),
        ("df -h | grep /dev", CommandRisk::ReadOnly),
        ("systemctl restart nginx", CommandRisk::Caution),
        ("apt install nginx", CommandRisk::Caution),
        ("echo enabled > /etc/example.conf", CommandRisk::Caution),
        ("cat /tmp/install.sh | sh", CommandRisk::Caution),
        (
            r"find /tmp -type f -exec chmod 600 {} \;",
            CommandRisk::Caution,
        ),
        (r"echo $(systemctl restart nginx)", CommandRisk::Caution),
        ("uptime && systemctl restart nginx", CommandRisk::Caution),
        ("ls -la /etc > /tmp/listing", CommandRisk::Caution),
        // `sed -i` and `sed -e p -i` are the mutating list's own sed entry; the
        // read-only list never speaks for sed in either implementation.
        ("sed -e p -i file", CommandRisk::Caution),
        ("sleep 60", CommandRisk::Unknown),
        ("uptime && whoami", CommandRisk::Unknown),
        ("df -h | sleep 1", CommandRisk::Unknown),
        ("sed -i 's/a/b/' /etc/hosts", CommandRisk::Unknown),
        ("sed -i.bak 's/a/b/' /etc/hosts", CommandRisk::Unknown),
        (r"sed -n '1,20p' /etc/hosts", CommandRisk::Unknown),
        ("sudo rm -rf /var/lib/example", CommandRisk::Destructive),
        ("git reset --hard HEAD~1", CommandRisk::Destructive),
        ("docker system prune -af", CommandRisk::Destructive),
        // Empty and whitespace-only: the app answers caution here.
        ("", CommandRisk::Caution),
        ("   ", CommandRisk::Caution),
    ];

    #[test]
    fn every_command_the_app_was_run_against_gets_the_same_verdict() {
        for (command, expected) in DART_VERDICTS {
            assert_eq!(
                classify(command),
                *expected,
                "command: {command:?} (as_str: {})",
                expected.as_str()
            );
        }
    }

    /// The app answers `read_only` for a `sed` whose first argument is a bare
    /// word, which the `\b` following `\s+` in its read-only entry allows. This
    /// port does not, so the one input is asserted rather than left to be found
    /// by a differential run and read as a bug.
    #[test]
    fn a_sed_read_is_never_read_only_here() {
        assert_eq!(classify("sudo sed p"), CommandRisk::Unknown);
        assert_eq!(classify("sed p /etc/hosts"), CommandRisk::Unknown);
        // The reason it is not on the list: `e` runs what it is given, and the
        // substitution it is given carries nothing on the lists above.
        assert_eq!(classify("sed s/a/touch x/e /etc/hosts"), CommandRisk::Unknown);
    }

    #[test]
    fn the_names_are_the_wire_spellings() {
        assert_eq!(CommandRisk::ReadOnly.as_str(), "read_only");
        assert_eq!(CommandRisk::Unknown.as_str(), "unknown");
        assert_eq!(CommandRisk::Caution.as_str(), "caution");
        assert_eq!(CommandRisk::Destructive.as_str(), "destructive");
    }

    #[test]
    fn only_a_read_may_run_unreviewed() {
        assert!(CommandRisk::ReadOnly.is_read_only());
        assert!(!CommandRisk::Unknown.is_read_only());
        assert!(!CommandRisk::Caution.is_read_only());
        assert!(!CommandRisk::Destructive.is_read_only());
    }
}
