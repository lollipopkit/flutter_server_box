//! The snippet macro language: which `${…}` a saved script may contain, and
//! what a client does with them.
//!
//! A snippet is a command the operator wrote once and runs later. Two of its
//! macros are answered from the machine it runs on (`${host}`, `${user}` and
//! the rest) and the rest are instructions *to the client driving the
//! terminal* — a pause, an Enter, a control combination — because typing a
//! command in pieces is not something the far side can be asked for.
//!
//! So this module does not run anything and does not talk to a terminal. It
//! answers one question: given a script and the values the caller can supply,
//! what should the client type, in what order, and where should it wait? The
//! answer is a [`Step`] list, which is the whole of the interface: the panel
//! executes it against xterm.js and the app's Dart could execute the same list
//! against xterm.dart.
//!
//! Ported from the app's `SnippetX.runInTerm` (`lib/data/model/server/
//! snippet.dart`), which is the only implementation of these macros today.
//! `TODO(migration)`: that Dart method should read this module through FFI and
//! execute the steps, the way the panel does — until then there are two
//! implementations of one language, and the divergences below are the ones
//! worth knowing about:
//!
//! - **A placeholder the caller cannot answer is refused**, where the app
//!   substitutes an empty string. `${host}` expanding to nothing turns
//!   `ssh ${user}@${host}` into `ssh user@`, which is a *different command*
//!   rather than a smaller one. The app already refuses a whole snippet for
//!   this reason (`needsServer`) and then substitutes empty anyway, which is
//!   the inconsistency this module does not carry over.
//! - **An unrecognised placeholder is typed as it was written**, where the app
//!   lowercases it. `${PATH}` is an ordinary thing to write in a shell command,
//!   and the app would send `${path}`.
//! - **`${enter}` and `${sleep}` with no argument do what they say** — press
//!   Enter once, wait for no time — where the app throws a `RangeError` out of
//!   the terminal callback, slicing past the end of the match it holds.
//!
//! All three are asserted in the tests below rather than left to be found by
//! comparing the two clients.
//!
//! The guards against a script that cannot be executed are the caller's, not
//! this module's: a snippet is the operator's own text, and there is nothing
//! here that reaches a command line the operator did not write.

use std::fmt;

use serde::{Deserialize, Serialize};

/// The `${…}` names answered from the machine the terminal is on.
///
/// The same six the app has. They are answered from the *caller's* context —
/// a client sends what it knows — because the values are facts about the
/// session rather than about this process: the working directory a server's
/// shells start in is a property of the credential someone typed, not of the
/// agent parsing the script.
pub const SERVER_KEYS: [&str; 6] = ["host", "port", "user", "pwd", "id", "name"];

/// The longest `${sleep N}` this will produce.
///
/// A client waits real time between pieces, so this is the one macro that can
/// hold a session for an arbitrary period. The app awaits the delay and has no
/// bound, which is a footgun rather than a feature: `sleep 86400` is a typo
/// nine times in ten, and the tenth wants the shell's own `sleep`.
pub const MAX_SLEEP_SECONDS: u64 = 300;

/// The most Enters one `${enter N}` will produce.
///
/// The app loops `N` times with no bound, so a mistyped `${enter 999999999}`
/// fills a scrollback. Clamped rather than refused: the piece means "press
/// Enter a few times", and a client that presses it 64 times has done what it
/// asked for.
pub const MAX_ENTER: u32 = 64;

/// What a client can answer for a script's `${…}` macros.
///
/// Every field is optional because every caller knows a different subset. A
/// field that is `None` is *not* an empty string: a script that asks for one
/// is refused rather than run with a hole in it, which is [`PlanError::Unanswerable`].
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct SnippetContext {
    pub host: Option<String>,
    pub port: Option<String>,
    pub user: Option<String>,
    pub pwd: Option<String>,
    pub id: Option<String>,
    pub name: Option<String>,
}

impl SnippetContext {
    fn get(&self, key: &str) -> Option<&str> {
        match key {
            "host" => self.host.as_deref(),
            "port" => self.port.as_deref(),
            "user" => self.user.as_deref(),
            "pwd" => self.pwd.as_deref(),
            "id" => self.id.as_deref(),
            "name" => self.name.as_deref(),
            _ => None,
        }
    }
}

/// One thing a client does, in order.
///
/// The wire shape is this enum's own (`container.rs`'s `ContainerAction`
/// convention): `{"type":"text","text":"ls"}`,
/// `{"type":"combo","ctrl":true,"alt":false,"key":"a","rest":"d"}`,
/// `{"type":"sleep","seconds":2}`, `{"type":"enter","times":1}`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Step {
    /// Type this, exactly.
    Text { text: String },
    /// Send the first character with the modifier held, then type the rest.
    ///
    /// One step rather than two because the two belong to one keystroke in the
    /// script — `${ctrl+ad}` is Ctrl+A followed by `d` — and a client that
    /// inserted anything between them would be typing into a different state
    /// of the shell.
    Combo {
        ctrl: bool,
        alt: bool,
        key: char,
        rest: String,
    },
    /// Wait before the next step.
    Sleep { seconds: u64 },
    /// Press Enter this many times. Never 0: a step that does nothing is not a
    /// step.
    Enter { times: u32 },
}

/// Why a script cannot be turned into steps.
///
/// A stable code rather than a sentence, for the panel to phrase in the
/// viewer's language: `{"code":"unanswerable","key":"host"}`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "code", rename_all = "snake_case")]
pub enum PlanError {
    /// The script asks for `${key}` and the caller supplied no value for it.
    Unanswerable { key: String },
}

impl fmt::Display for PlanError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PlanError::Unanswerable { key } => {
                write!(f, "the caller cannot answer ${{{key}}}")
            }
        }
    }
}

impl std::error::Error for PlanError {}

/// The `${…}` names a script mentions, as written, deduplicated.
///
/// The vocabulary rather than an execution: a client uses it to say what a
/// script needs before offering to run it, which is a question about the script
/// and not about a terminal. Spelled as the operator wrote them, because `${HOST}`
/// and `${host}` are not the same name here — see [`server_keys`].
pub fn placeholders(script: &str) -> Vec<String> {
    let mut found: Vec<String> = Vec::new();
    for name in matches(script).into_iter().map(|m| m.name) {
        if !found.contains(&name) {
            found.push(name);
        }
    }
    found
}

/// Which of the six server values a script asks for, in the order they appear.
///
/// Case-sensitive, and that is the whole point: `${host}` is this macro and
/// `${HOST}` is a shell variable the operator wrote, so a client sending a
/// context for the second one would be sending it for nothing. The app's
/// substitution is literal too.
pub fn server_keys(script: &str) -> Vec<&'static str> {
    let mut found: Vec<&'static str> = Vec::new();
    for m in matches(script) {
        let Some(key) = SERVER_KEYS.iter().find(|key| **key == m.name) else {
            continue;
        };
        if !found.contains(key) {
            found.push(key);
        }
    }
    // The list is in the order they appear, which is the order a client shows.
    found
}

/// Whether a script names anything only a machine can answer.
///
/// The app's `needsServer`, and the question a client without a server context
/// asks before offering a snippet at all.
pub fn uses_server_context(script: &str) -> bool {
    !server_keys(script).is_empty()
}

/// Turns a script into what a client should type.
pub fn plan(script: &str, ctx: &SnippetContext) -> Result<Vec<Step>, PlanError> {
    let expanded = expand_server_keys(script, ctx)?;
    Ok(steps_of(&expanded))
}

/// Replaces the six server placeholders, refusing the first one the caller
/// cannot answer.
///
/// `${{…}}` and `${host` (no closing brace) are left alone: the macro is the
/// whole `${…}`, and half of one is text like any other.
fn expand_server_keys(script: &str, ctx: &SnippetContext) -> Result<String, PlanError> {
    let mut out = String::with_capacity(script.len());
    let mut cursor = 0;
    for m in matches(script) {
        // The spelling as written, so `${HOST}` is a shell variable someone
        // wrote rather than this macro — the app substitutes literally too.
        if !SERVER_KEYS.contains(&m.name.as_str()) {
            continue;
        }
        let Some(value) = ctx.get(&m.name) else {
            return Err(PlanError::Unanswerable { key: m.name.clone() });
        };
        out.push_str(&script[cursor..m.start]);
        // The value goes in verbatim, including any `${…}` inside it, which the
        // macro pass will then read. That is the app's behaviour, and the only
        // way a value stays opaque is to say so rather than to escape it.
        out.push_str(value);
        cursor = m.end;
    }
    out.push_str(&script[cursor..]);
    Ok(out)
}

/// One `${…}` occurrence, by byte offset.
struct RawMatch {
    start: usize,
    end: usize,
    name: String,
}

/// Every `${…}` in the text.
///
/// `${[^{}]+}` in the app, over bytes rather than characters because the
/// offsets slice the same string. A name is therefore whatever sits between the
/// braces; the app compares it lowercased for the macros and literally for the
/// server names, and so does this.
///
/// Occurrences cannot overlap by construction — the scan consumes up to the
/// closing brace and resumes after it — which is why the app's own overlap
/// guard has no input that reaches it, and is not carried over.
fn matches(text: &str) -> Vec<RawMatch> {
    let bytes = text.as_bytes();
    let mut out = Vec::new();
    let mut index = 0;
    while index + 1 < bytes.len() {
        if bytes[index] == b'$'
            && bytes[index + 1] == b'{'
            && let Some(close) = bytes[index + 2..].iter().position(|b| *b == b'}')
        {
            let name = &text[index + 2..index + 2 + close];
            if !name.is_empty() && !name.contains(['{', '}']) {
                out.push(RawMatch {
                    start: index,
                    end: index + 2 + close + 1,
                    name: name.to_string(),
                });
                index += 2 + close + 1;
                continue;
            }
        }
        index += 1;
    }
    out
}

/// Adds text to the end of a plan, joining it to the previous piece.
///
/// A macro that produces nothing — `${sleep abc}`, a combination with no `+` —
/// leaves the pieces either side of it adjacent, and adjacent pieces are one
/// piece: a client typing "a" and then "b" types `ab`. Keeping them apart would
/// make the plan a function of where the macros are rather than of what is
/// typed.
fn push_text(steps: &mut Vec<Step>, text: &str) {
    if text.is_empty() {
        return;
    }
    match steps.last_mut() {
        Some(Step::Text { text: previous }) => previous.push_str(text),
        _ => steps.push(Step::Text {
            text: text.to_string(),
        }),
    }
}

/// The macro pass: everything left after the server names were substituted.
fn steps_of(script: &str) -> Vec<Step> {
    let found = matches(script);
    if found.is_empty() {
        let mut steps = Vec::new();
        push_text(&mut steps, script);
        return steps;
    }

    let mut steps = Vec::new();
    let mut cursor = 0;
    for m in &found {
        push_text(&mut steps, &script[cursor..m.start]);
        cursor = m.end;
        // The name between the braces, lowercased: the macros are recognised
        // whatever case the operator spelled them in.
        let name = m.name.to_lowercase();

        if let Some(rest) = name.strip_prefix("sleep") {
            if let Some(seconds) = argument(rest).and_then(|n| n.parse::<u64>().ok()) {
                steps.push(Step::Sleep {
                    seconds: seconds.min(MAX_SLEEP_SECONDS),
                });
            }
            // An unreadable argument is the app's no-op rather than an error:
            // the macro is a pause, and a pause of nothing is what "no number"
            // means.
            continue;
        }
        if let Some(rest) = name.strip_prefix("enter") {
            let times = argument(rest)
                .and_then(|n| n.parse::<i64>().ok())
                .map(|n| n.clamp(0, i64::from(u32::MAX)) as u32)
                // The app's default when there is no number, and the same for
                // one that cannot be read at all.
                .unwrap_or(1);
            if times > 0 {
                steps.push(Step::Enter {
                    times: times.min(MAX_ENTER),
                });
            }
            continue;
        }
        if let Some((ctrl, rest)) = name
            .strip_prefix("ctrl")
            .map(|r| (true, r))
            .or_else(|| name.strip_prefix("alt").map(|r| (false, r)))
        {
            // `${ctrl+ad}` → Ctrl+A, then `d`. A combination with no `+` is the
            // app's early return: nothing is typed, and the placeholder is not
            // literal text either.
            if let Some(combo) = combo_of(ctrl, rest) {
                steps.push(combo);
            }
            continue;
        }
        // Anything else is text the operator wrote, typed as written — the
        // braces and the case included.
        push_text(&mut steps, &script[m.start..m.end]);
    }
    push_text(&mut steps, &script[cursor..]);
    steps
}

/// The inside of a `name argument` macro after the name: what follows the one
/// separating character.
fn argument(rest: &str) -> Option<&str> {
    let mut chars = rest.chars();
    chars.next()?;
    Some(chars.as_str())
}

/// The rest of a `ctrl+ad` name after the modifier: the first character with
/// the modifier held, then what follows it.
///
/// `ctrl` is whether Ctrl is the modifier; `alt+…` is the other.
fn combo_of(ctrl: bool, rest: &str) -> Option<Step> {
    let text = rest.strip_prefix('+')?;
    let mut chars = text.chars();
    let key = chars.next()?;
    Some(Step::Combo {
        ctrl,
        alt: !ctrl,
        key,
        rest: chars.as_str().to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ctx() -> SnippetContext {
        SnippetContext {
            host: Some("10.0.0.1".into()),
            port: Some("2222".into()),
            user: Some("box".into()),
            pwd: Some("/srv".into()),
            id: Some("srv1".into()),
            name: Some("Office".into()),
        }
    }

    fn text(value: &str) -> Step {
        Step::Text {
            text: value.to_string(),
        }
    }

    /// The app's cases, read off `SnippetX.runInTerm`: what each branch of its
    /// slicing produces for the same script.
    #[test]
    fn the_apps_slicing_is_reproduced() {
        // A fixed script is one piece.
        assert_eq!(plan("df -h", &ctx()).unwrap(), vec![text("df -h")]);

        // The server names are substituted before anything else.
        assert_eq!(
            plan("ssh ${user}@${host} -p ${port}", &ctx()).unwrap(),
            vec![text("ssh box@10.0.0.1 -p 2222")]
        );

        // Text before, between and after the macros.
        assert_eq!(
            plan("a${sleep 2}b${enter}c", &ctx()).unwrap(),
            vec![
                text("a"),
                Step::Sleep { seconds: 2 },
                text("b"),
                Step::Enter { times: 1 },
                text("c"),
            ]
        );

        // `${ctrl+ad}` is Ctrl+A then `d`; `${alt+x}` is Alt+X with nothing
        // after it.
        assert_eq!(
            plan("${ctrl+ad}${alt+x}", &ctx()).unwrap(),
            vec![
                Step::Combo {
                    ctrl: true,
                    alt: false,
                    key: 'a',
                    rest: "d".into(),
                },
                Step::Combo {
                    ctrl: false,
                    alt: true,
                    key: 'x',
                    rest: String::new(),
                },
            ]
        );

        // A macro is recognised whatever its case — the app lowercases the
        // match before looking at it.
        assert_eq!(
            plan("${SLEEP 1}${Enter 3}${CTRL+C}", &ctx()).unwrap(),
            vec![
                Step::Sleep { seconds: 1 },
                Step::Enter { times: 3 },
                Step::Combo {
                    ctrl: true,
                    alt: false,
                    key: 'c',
                    rest: String::new(),
                },
            ]
        );
    }

    /// The app reads the argument as the text after the name and one separator,
    /// so a missing separator is an argument that cannot be read.
    #[test]
    fn an_unreadable_argument_is_the_apps_default() {
        // No number at all: a pause of nothing, and one Enter.
        assert_eq!(
            plan("${sleep abc}x${enter abc}", &ctx()).unwrap(),
            vec![text("x"), Step::Enter { times: 1 }]
        );
        // No separator: the same.
        assert_eq!(
            plan("${sleep2}x${enter3}", &ctx()).unwrap(),
            vec![text("x"), Step::Enter { times: 1 }]
        );
        // A negative count presses nothing, as the app's loop does.
        assert_eq!(plan("${enter -1}x", &ctx()).unwrap(), vec![text("x")]);
        // A macro with no argument at all — the app throws a `RangeError` here,
        // slicing from one past the end of the match it already has. One Enter
        // is what `${enter}` says; a pause of nothing is what `${sleep}` says.
        assert_eq!(
            plan("${sleep}${enter}", &ctx()).unwrap(),
            vec![Step::Enter { times: 1 }]
        );
    }

    /// A combination with no `+`, or with nothing after it, types nothing —
    /// not the literal placeholder.
    #[test]
    fn a_broken_combination_types_nothing() {
        assert_eq!(plan("a${ctrl}b", &ctx()).unwrap(), vec![text("ab")]);
        assert_eq!(plan("a${ctrl+}b", &ctx()).unwrap(), vec![text("ab")]);
    }

    #[test]
    fn the_bounds_are_the_ones_a_client_can_execute() {
        assert_eq!(
            plan("${sleep 99999}", &ctx()).unwrap(),
            vec![Step::Sleep {
                seconds: MAX_SLEEP_SECONDS
            }]
        );
        assert_eq!(
            plan("${enter 999999999}", &ctx()).unwrap(),
            vec![Step::Enter { times: MAX_ENTER }]
        );
    }

    /// The two deliberate departures from the app.
    #[test]
    fn a_divergence_from_the_app_is_asserted_rather_than_inherited() {
        // The app types `echo ${path}` — it lowercases an unrecognised
        // placeholder before sending it, which rewrites a shell variable
        // someone wrote in their own command.
        assert_eq!(
            plan("echo ${PATH}", &ctx()).unwrap(),
            vec![text("echo ${PATH}")]
        );

        // The app substitutes an empty string for a value it does not have.
        let without_user = SnippetContext {
            user: None,
            ..ctx()
        };
        assert_eq!(
            plan("printf '%s' ${user}", &without_user),
            Err(PlanError::Unanswerable {
                key: "user".into()
            })
        );
    }

    #[test]
    fn the_vocabulary_is_readable_without_a_terminal() {
        // As written: these are the names a reader has to recognise, and the
        // six server ones are matched in the case they were typed.
        assert_eq!(
            placeholders("ssh ${user}@${host} ${sleep 2} ${USER}"),
            vec!["user", "host", "sleep 2", "USER"]
        );
        assert_eq!(
            server_keys("ssh ${user}@${host} ${USER} ${sleep 1}"),
            vec!["user", "host"]
        );
        assert!(uses_server_context("ssh ${user}@${host}"));
        assert!(!uses_server_context("${sleep 1}"));
        // A shell variable spelled in capitals is not the macro.
        assert!(!uses_server_context("echo ${HOST}"));
        // Half a placeholder, and one with braces inside, are text.
        assert!(placeholders("${host ${a{b}}").is_empty());
    }

    /// A substituted value is opaque, even when it contains a macro — the
    /// second pass reads it, which is what the app does too.
    #[test]
    fn a_value_is_inserted_before_the_macros_are_read() {
        let odd = SnippetContext {
            name: Some("a${sleep 2}b".into()),
            ..ctx()
        };
        assert_eq!(
            plan("${name}", &odd).unwrap(),
            vec![text("a"), Step::Sleep { seconds: 2 }, text("b")]
        );
    }

    #[test]
    fn an_empty_script_produces_nothing_to_type() {
        assert!(plan("", &ctx()).unwrap().is_empty());
    }

    /// The wire shape, which is what a client in another language reads: a
    /// tagged step, a context whose absent keys are the absent values, and a
    /// refusal that is a code rather than a sentence.
    #[test]
    fn the_wire_shape_is_what_a_client_reads() {
        let steps = plan("a${sleep 2}${ctrl+c}", &ctx()).unwrap();
        assert_eq!(
            serde_json::to_value(&steps).unwrap(),
            serde_json::json!([
                {"type": "text", "text": "a"},
                {"type": "sleep", "seconds": 2},
                {"type": "combo", "ctrl": true, "alt": false, "key": "c", "rest": ""},
            ])
        );

        // An omitted key is a value the caller cannot answer, which is the same
        // as sending `null` — not an empty string.
        let sent: SnippetContext = serde_json::from_value(serde_json::json!({
            "host": "10.0.0.1",
            "port": "22",
        }))
        .unwrap();
        assert_eq!(sent.host.as_deref(), Some("10.0.0.1"));
        assert_eq!(sent.user, None);

        assert_eq!(
            serde_json::to_value(plan("${user}", &sent).unwrap_err()).unwrap(),
            serde_json::json!({"code": "unanswerable", "key": "user"})
        );
    }
}
