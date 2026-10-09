//! An operator's rules for the commands an agent runs, in the shape Claude
//! Code's permission rules have: `allow`, `ask` and `deny` lists of command
//! patterns, `*` standing in for any text (spaces included). Checked deny,
//! then ask, then allow; the first list with a match decides, however
//! specific another list's rule is.
//!
//! A command is taken apart at `&&`, `||`, `;`, `|`, `|&`, `&` and line
//! breaks, wrappers that run their argument (`timeout 30`, `nice`, `nohup`,
//! `sudo`, …) are taken off, and each part is matched on its own: a deny or
//! ask rule matching any part decides, an allow rule must cover every part
//! (or the part be a read `command_risk` knows). A command allow rules
//! cannot see through — a substitution, a subshell, a write by redirection,
//! a quote left open — is never allowed by a rule; deny and ask rules still
//! look inside it.
//!
//! Rules match the text written, not the program run: `rm *` in `deny` does
//! not stop `/bin/rm` or `sh -c 'rm …'`. They state what to ask about and
//! what never to do, and are not a boundary around a program.

use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};

use crate::command_risk::{self, CommandRisk};

pub const MAX_RULES: usize = 256;
pub const MAX_RULE_LEN: usize = 512;

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CommandRules {
    #[serde(default)]
    pub allow: Vec<String>,
    #[serde(default)]
    pub ask: Vec<String>,
    #[serde(default)]
    pub deny: Vec<String>,
}

/// What the rules say about a command; the rule that said it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RuleVerdict {
    Deny(String),
    Ask(String),
    /// Every part is covered: by these rules, or as a known read.
    Allow(String),
    /// No rule speaks to it.
    None,
}

impl CommandRules {
    pub fn is_empty(&self) -> bool {
        self.allow.is_empty() && self.ask.is_empty() && self.deny.is_empty()
    }

    /// Why the rules cannot be stored, naming the list and the rule.
    pub fn check(&self) -> Result<(), String> {
        for (list, rules) in [("allow", &self.allow), ("ask", &self.ask), ("deny", &self.deny)] {
            if rules.len() > MAX_RULES {
                return Err(format!("{list}: at most {MAX_RULES} rules"));
            }
            for r in rules {
                let p = pattern_of(r);
                if p.is_empty() || r.len() > MAX_RULE_LEN || r.chars().any(char::is_control) {
                    return Err(format!("{list}: invalid rule `{r}`"));
                }
                // An allow rule that starts with a wildcard allows any
                // program: say so rather than store it.
                if list == "allow" && p.starts_with('*') {
                    return Err(format!("allow: `{r}` would allow any command; name the command first"));
                }
            }
        }
        Ok(())
    }

    /// What the rules say about [command].
    pub fn verdict(&self, command: &str) -> RuleVerdict {
        let wide = candidates(command);
        if let Some(r) = first_match(&self.deny, &wide) {
            return RuleVerdict::Deny(r);
        }
        if let Some(r) = first_match(&self.ask, &wide) {
            return RuleVerdict::Ask(r);
        }
        if self.allow.is_empty() || !allowable(command) {
            return RuleVerdict::None;
        }
        let Some(parts) = subcommands(command) else { return RuleVerdict::None };
        let mut by = None;
        for part in &parts {
            let p = strip_wrappers(part, false);
            match self.allow.iter().find(|r| matches(&pattern_of(r), &p)) {
                Some(r) => by = by.or_else(|| Some(r.clone())),
                // A known read needs no rule.
                None if command_risk::classify(&p) == CommandRisk::ReadOnly => {}
                None => return RuleVerdict::None,
            }
        }
        match by {
            Some(r) => RuleVerdict::Allow(r),
            None => RuleVerdict::None,
        }
    }
}

fn first_match(rules: &[String], candidates: &[String]) -> Option<String> {
    rules.iter().find(|r| {
        let p = pattern_of(r);
        candidates.iter().any(|c| matches(&p, c))
    }).cloned()
}

/// A rule's pattern: `Bash(…)` and `run_command(…)` are taken off, a
/// trailing `:*` is ` *`, runs of spaces are one.
pub fn pattern_of(rule: &str) -> String {
    let mut r = rule.trim();
    for prefix in ["Bash(", "run_command("] {
        if let Some(inner) = r.strip_prefix(prefix).and_then(|x| x.strip_suffix(')')) {
            r = inner.trim();
        }
    }
    let r = match r.strip_suffix(":*") {
        Some(head) => format!("{head} *"),
        None => r.to_string(),
    };
    collapse(&r)
}

fn collapse(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Whether [pattern] matches all of [command]. `*` is any text; a trailing
/// ` *` that is the only wildcard also matches the bare command.
pub fn matches(pattern: &str, command: &str) -> bool {
    let command = collapse(command);
    let wildcards = pattern.matches('*').count();
    if wildcards == 1
        && let Some(head) = pattern.strip_suffix(" *")
        && command == head
    {
        return true;
    }
    let mut re = String::from("^");
    for (i, piece) in pattern.split('*').enumerate() {
        if i > 0 {
            re.push_str(".*");
        }
        re.push_str(&regex::escape(piece));
    }
    re.push('$');
    Regex::new(&re).is_ok_and(|r| r.is_match(&command))
}

static WRITE_REDIRECT: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(^|[^<0-9&])[0-9]?>>?\s*[^&\s]").unwrap());
static QUIET: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[012]?>>?\s*/dev/null\b").unwrap());

/// Whether allow rules may see this command as its parts: nothing runs that
/// the parts do not show, and nothing is written by redirection.
fn allowable(command: &str) -> bool {
    let quiet = QUIET.replace_all(command, "");
    let line = quiet.replace(">&", "");
    !(command.contains("$(") || command.contains('`') || command.contains("<(") || command.contains(">(") || WRITE_REDIRECT.is_match(&line))
}

/// The commands in [command], quotes respected; `None` when it cannot be
/// taken apart: a quote left open, a subshell, a group, an operator with
/// nothing after it.
pub fn subcommands(command: &str) -> Option<Vec<String>> {
    let mut out = Vec::new();
    let mut cur = String::new();
    let mut chars = command.chars().peekable();
    let mut quote: Option<char> = None;
    let mut pending_operator = false;
    while let Some(c) = chars.next() {
        if let Some(q) = quote {
            cur.push(c);
            if c == q {
                quote = None;
            } else if c == '\\'
                && q == '"'
                && let Some(n) = chars.next()
            {
                cur.push(n);
            }
            continue;
        }
        match c {
            '\'' | '"' => {
                quote = Some(c);
                cur.push(c);
            }
            '\\' => {
                cur.push(c);
                if let Some(n) = chars.next() {
                    cur.push(n);
                }
            }
            '(' | ')' | '{' | '}' => return None,
            ';' | '\n' | '\r' | '|' | '&' => {
                // `2>&1`, `>&2`: a redirection, not an operator.
                if c == '&' && (cur.ends_with('>') || cur.ends_with('<')) {
                    cur.push(c);
                    continue;
                }
                if matches!(c, '|' | '&') && chars.peek() == Some(&c) {
                    chars.next();
                }
                if c == '|' && chars.peek() == Some(&'&') {
                    chars.next();
                }
                let part = cur.trim().to_string();
                if part.is_empty() && matches!(c, '|' | '&') {
                    return None;
                }
                if !part.is_empty() {
                    out.push(part);
                }
                cur.clear();
                pending_operator = !matches!(c, ';' | '\n' | '\r');
                continue;
            }
            _ => cur.push(c),
        }
        if !c.is_whitespace() {
            pending_operator = false;
        }
    }
    if quote.is_some() || pending_operator {
        return None;
    }
    let part = cur.trim().to_string();
    if !part.is_empty() {
        out.push(part);
    }
    (!out.is_empty()).then_some(out)
}

/// Every text a deny or ask rule should be held against: the parts, the
/// parts of what is inside a substitution or subshell, without and with
/// their wrappers, and the whole line.
fn candidates(command: &str) -> Vec<String> {
    let mut out = vec![collapse(command)];
    // Taken apart at every operator and bracket, quotes ignored: more texts
    // to check, never fewer.
    static WIDE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"&&|\|\||\|&|[;|&\r\n(){}`]|\$\(").unwrap());
    for part in WIDE.split(command).chain(subcommands(command).unwrap_or_default().iter().map(String::as_str)) {
        let p = collapse(part);
        if p.is_empty() {
            continue;
        }
        let bare = strip_wrappers(&p, true);
        out.push(p);
        out.push(bare);
    }
    out.sort();
    out.dedup();
    out
}

/// Environment assignments a rule may look past when it allows: they change
/// how a command speaks, not what it does.
const SAFE_ENV: &[&str] = &["LANG", "LANGUAGE", "TZ", "NO_COLOR", "TERM", "COLUMNS", "LINES", "PAGER", "SYSTEMD_PAGER", "DEBIAN_FRONTEND"];

/// [part] without what only runs it: `sudo`, `timeout 30`, `time`, `nice
/// -n 5`, `nohup`, `stdbuf -oL`, `command`, `builtin`, `noglob`, a bare
/// `xargs`, and leading assignments ([any_env]: every one; otherwise only
/// [`SAFE_ENV`] and `LC_*`).
pub fn strip_wrappers(part: &str, any_env: bool) -> String {
    let mut words: Vec<&str> = part.split_whitespace().collect();
    while let Some(first) = words.first().copied() {
        let took = if let Some((name, _)) = first.split_once('=')
            && !name.is_empty()
            && name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_')
        {
            if any_env || SAFE_ENV.contains(&name) || name.starts_with("LC_") { 1 } else { 0 }
        } else {
            match first {
                "sudo" | "time" | "nohup" | "command" | "builtin" | "noglob" => {
                    // `command -v` looks a command up; it does not run one.
                    if first == "command" && words.get(1).is_some_and(|w| w.starts_with('-')) { 0 } else { 1 }
                }
                "xargs" if words.get(1).is_some_and(|w| !w.starts_with('-')) => 1,
                "timeout" => {
                    let mut n = 1;
                    while words.get(n).is_some_and(|w| w.starts_with('-')) {
                        n += 1;
                    }
                    if words.get(n).is_some_and(|w| w.chars().next().is_some_and(|c| c.is_ascii_digit())) { n + 1 } else { 0 }
                }
                "nice" => {
                    if words.get(1) == Some(&"-n") { 3 } else if words.get(1).is_some_and(|w| w.starts_with('-')) { 2 } else { 1 }
                }
                "stdbuf" => {
                    let mut n = 1;
                    while words.get(n).is_some_and(|w| w.starts_with('-')) {
                        n += 1;
                    }
                    n
                }
                _ => 0,
            }
        };
        if took == 0 || took > words.len() {
            break;
        }
        words.drain(..took);
    }
    words.join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rules(allow: &[&str], ask: &[&str], deny: &[&str]) -> CommandRules {
        let v = |l: &[&str]| l.iter().map(|s| s.to_string()).collect();
        CommandRules { allow: v(allow), ask: v(ask), deny: v(deny) }
    }

    #[test]
    fn patterns_match_as_claude_code_rules_do() {
        assert!(matches("npm run build", "npm run build"));
        assert!(!matches("npm run build", "npm run build --watch"));
        assert!(matches("npm run *", "npm run test --watch"));
        assert!(matches("npm run *", "npm run"));
        assert!(!matches("npm run *", "npm install"));
        assert!(matches("git log * main", "git log --oneline main"));
        assert!(!matches("git log * main", "git log main"));
        assert!(matches("ls *", "ls -la"));
        assert!(!matches("ls *", "lsof"));
        assert!(matches("ls*", "lsof"));
        assert!(!matches("* --help *", "npm --help"));
        assert_eq!(pattern_of("Bash(ls:*)"), "ls *");
        assert_eq!(pattern_of("run_command( systemctl   status * )"), "systemctl status *");
    }

    #[test]
    fn commands_are_taken_apart_and_wrappers_taken_off() {
        assert_eq!(subcommands("a && b || c; d | e |& f").unwrap(), ["a", "b", "c", "d", "e", "f"]);
        assert_eq!(subcommands("grep 'a;b' f 2>&1 | head").unwrap(), ["grep 'a;b' f 2>&1", "head"]);
        assert_eq!(subcommands("npm test &&"), None);
        assert_eq!(subcommands("(cd /tmp; ls)"), None);
        assert_eq!(subcommands("echo 'open"), None);
        assert_eq!(strip_wrappers("timeout 30 nice -n 5 npm test", false), "npm test");
        assert_eq!(strip_wrappers("sudo DEBIAN_FRONTEND=noninteractive apt-get install x", false), "apt-get install x");
        assert_eq!(strip_wrappers("FOO=1 rm x", false), "FOO=1 rm x");
        assert_eq!(strip_wrappers("FOO=1 rm x", true), "rm x");
        assert_eq!(strip_wrappers("command -v ls", false), "command -v ls");
    }

    #[test]
    fn deny_then_ask_then_allow() {
        let r = rules(&["aws *"], &["aws s3 rm *"], &["aws iam *"]);
        assert_eq!(r.verdict("aws iam list-users"), RuleVerdict::Deny("aws iam *".into()));
        assert_eq!(r.verdict("aws s3 rm s3://b/x"), RuleVerdict::Ask("aws s3 rm *".into()));
        assert_eq!(r.verdict("aws s3 ls"), RuleVerdict::Allow("aws *".into()));
        assert_eq!(r.verdict("gcloud x"), RuleVerdict::None);
    }

    #[test]
    fn deny_and_ask_look_into_every_part() {
        let r = rules(&[], &["git clean *"], &["rm *"]);
        assert_eq!(r.verdict("cd /tmp && git clean -f"), RuleVerdict::Ask("git clean *".into()));
        assert_eq!(r.verdict("echo \"$(git clean -f)\""), RuleVerdict::Ask("git clean *".into()));
        assert_eq!(r.verdict("FOO=bar rm -rf tmp/"), RuleVerdict::Deny("rm *".into()));
        assert_eq!(r.verdict("timeout 5 rm x"), RuleVerdict::Deny("rm *".into()));
        assert_eq!(r.verdict("sudo rm x"), RuleVerdict::Deny("rm *".into()));
    }

    #[test]
    fn allow_must_cover_every_part_it_can_see() {
        let r = rules(&["systemctl restart *"], &[], &[]);
        assert_eq!(r.verdict("systemctl restart nginx"), RuleVerdict::Allow("systemctl restart *".into()));
        // A known read beside it needs no rule.
        assert_eq!(r.verdict("systemctl restart nginx && systemctl status nginx"), RuleVerdict::Allow("systemctl restart *".into()));
        assert_eq!(r.verdict("systemctl restart nginx && touch /x"), RuleVerdict::None);
        assert_eq!(r.verdict("systemctl restart $(cat /x)"), RuleVerdict::None);
        assert_eq!(r.verdict("systemctl restart nginx > /etc/x"), RuleVerdict::None);
        assert_eq!(r.verdict("systemctl restart nginx 2>/dev/null"), RuleVerdict::Allow("systemctl restart *".into()));
        assert_eq!(r.verdict("FOO=1 systemctl restart nginx"), RuleVerdict::None);
        assert_eq!(r.verdict("ls"), RuleVerdict::None);
    }

    #[test]
    fn a_rule_that_allows_anything_is_refused() {
        assert!(rules(&["*"], &[], &[]).check().is_err());
        assert!(rules(&["* --version"], &[], &[]).check().is_err());
        assert!(rules(&[], &[], &["*"]).check().is_ok());
        assert!(rules(&[""], &[], &[]).check().is_err());
    }
}
