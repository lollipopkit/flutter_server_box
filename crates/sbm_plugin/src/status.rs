//! What a status plugin answers with. PLUGINS.md section 9.
//!
//! A status plugin has no surface: it says which command to run and turns that
//! command's output into readings, and the app draws them the same way it draws
//! its own. So the answer is a fixed, small shape rather than a widget tree —
//! which is what lets this ship before the vocabulary in section 5 is settled,
//! and what keeps the worst outcome of a bad status plugin to a wrong number.
//!
//! Parsed here rather than in Dart for the reason the manifest is: one parser.
//! A plugin's output is not trusted, so the app should be handed something
//! already checked rather than a JSON blob to interpret.

use serde::{Deserialize, Serialize};

use crate::error::PluginError;
use crate::host::{InstanceId, PluginHost};
use crate::hostfn::exports;
use crate::manifest::Platform;

impl PluginHost {
    /// Asks a status plugin what to run on `platform`.
    ///
    /// Typed here rather than left to the caller for the reason the manifest
    /// is parsed here: one parser, and what comes back is not trusted. A
    /// caller assembling `{"platform":"linux"}` and reading `answer["cmd"]`
    /// would be a second one.
    ///
    /// The answer is what the install page shows and what the app is about to
    /// run — the same value, from the same call, so what the user was shown
    /// cannot differ from what happens for want of asking twice.
    pub fn status_cmd(&self, id: InstanceId, platform: Platform) -> Result<StatusCmd, PluginError> {
        let input = serde_json::json!({ "platform": platform.name() }).to_string();
        StatusCmd::parse(&self.call(id, exports::STATUS_CMD, input.as_bytes())?)
    }

    /// Hands a status plugin what its command printed.
    ///
    /// `text` is the command's stdout as it came back, not JSON: a plugin
    /// parses text, and making the caller quote it would be a second encoding
    /// for the same bytes.
    pub fn status_parse(&self, id: InstanceId, text: &str) -> Result<StatusResult, PluginError> {
        let input = serde_json::json!({ "text": text }).to_string();
        StatusResult::parse(&self.call(id, exports::PARSE, input.as_bytes())?)
    }
}

/// The command to run on the server, and how its output is delimited.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StatusCmd {
    /// A shell command, run on the server the same way a custom command is.
    pub cmd: String,
    /// Optional: how the plugin splits its own output into parts.
    ///
    /// The app does not read it — the separator between *commands* is the
    /// host's — but a plugin that runs several probes in one command needs
    /// somewhere to say what it used, and putting it here keeps that out of the
    /// command text.
    #[serde(default)]
    pub sep: Option<String>,
}

impl StatusCmd {
    pub fn parse(bytes: &[u8]) -> Result<Self, PluginError> {
        let cmd: StatusCmd = serde_json::from_slice(bytes)
            .map_err(|e| PluginError::BadAnswer(format!("statusCmd: {e}")))?;
        if cmd.cmd.trim().is_empty() {
            return Err(PluginError::BadAnswer("statusCmd: `cmd` is empty".into()));
        }
        Ok(cmd)
    }
}

/// How emphatic one reading is.
///
/// A name rather than a colour, so a status plugin's row looks like the app's
/// own in both themes and a plugin cannot ship an unreadable one.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Tone {
    #[default]
    Normal,
    Muted,
    Success,
    Warning,
    Danger,
}

/// One reading.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StatusItem {
    pub label: String,
    pub value: String,

    /// 0..1, drawn as a bar beside the value.
    ///
    /// Absent where the reading is not a proportion — a temperature, a count.
    /// A value outside the range is dropped rather than clamped: a bar at 100%
    /// because a plugin divided by the wrong thing is a wrong reading shown
    /// confidently.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub percent: Option<f64>,

    #[serde(default)]
    pub tone: Tone,
}

/// What `parse` answers with.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StatusResult {
    /// The card's heading. Falls back to the plugin's name when empty.
    #[serde(default)]
    pub title: String,

    pub items: Vec<StatusItem>,

    /// Shown under the readings, for what a row cannot say — "3 of 20 sensors
    /// unreadable".
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub note: Option<String>,
}

impl StatusResult {
    /// How many readings one plugin may contribute.
    ///
    /// A cap rather than a scroll: these rows go on the status page beside the
    /// app's own, and a plugin that answers a thousand of them would push
    /// everything else off the screen. [`StatusResult::note`] is where a plugin
    /// says it had more.
    pub const MAX_ITEMS: usize = 64;

    /// A label or value longer than this is a plugin that did not parse its
    /// input, not a reading.
    pub const MAX_TEXT: usize = 200;

    /// Reads and checks one plugin's answer.
    ///
    /// Trims rather than refuses wherever it can: a status plugin's whole cost
    /// of being wrong should be a missing row, not a card that will not draw.
    /// What is refused is a document that is not this shape at all.
    pub fn parse(bytes: &[u8]) -> Result<Self, PluginError> {
        let mut result: StatusResult = serde_json::from_slice(bytes)
            .map_err(|e| PluginError::BadAnswer(format!("parse: {e}")))?;

        result.title = trim(&result.title);
        result.note = result.note.as_deref().map(trim).filter(|s| !s.is_empty());
        result.items.truncate(Self::MAX_ITEMS);
        result.items.retain_mut(|item| {
            item.label = trim(&item.label);
            item.value = trim(&item.value);
            // A reading with nothing on either side of it is not one.
            if item.label.is_empty() && item.value.is_empty() {
                return false;
            }
            item.percent = item
                .percent
                .filter(|p| p.is_finite() && (0.0..=1.0).contains(p));
            true
        });
        Ok(result)
    }
}

fn trim(s: &str) -> String {
    let s = s.trim();
    match s.char_indices().nth(StatusResult::MAX_TEXT) {
        Some((at, _)) => s[..at].to_string(),
        None => s.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(json: &str) -> StatusResult {
        StatusResult::parse(json.as_bytes()).expect("did not parse")
    }

    #[test]
    fn the_ordinary_answer() {
        let r = parse(
            r#"{"title":"ZFS","items":[
                 {"label":"tank","value":"1.2T / 3.6T","percent":0.33},
                 {"label":"health","value":"ONLINE","tone":"success"}
               ]}"#,
        );
        assert_eq!(r.title, "ZFS");
        assert_eq!(r.items.len(), 2);
        assert_eq!(r.items[0].percent, Some(0.33));
        assert_eq!(r.items[1].tone, Tone::Success);
        assert_eq!(r.items[0].tone, Tone::Normal, "tone defaults");
    }

    #[test]
    fn a_command_needs_something_to_run() {
        assert_eq!(
            StatusCmd::parse(br#"{"cmd":"zpool list -Hp"}"#).unwrap().cmd,
            "zpool list -Hp"
        );
        assert!(StatusCmd::parse(br#"{"cmd":"  "}"#).is_err());
        assert!(StatusCmd::parse(b"{}").is_err());
    }

    /// A bar at 100% because a plugin divided by the wrong thing is a wrong
    /// reading shown confidently. Dropped rather than clamped.
    #[test]
    fn a_percent_outside_the_range_is_dropped_not_clamped() {
        for bad in ["1.5", "-0.2", "null"] {
            let r = parse(&format!(r#"{{"items":[{{"label":"a","value":"b","percent":{bad}}}]}}"#));
            assert_eq!(r.items[0].percent, None, "{bad}");
        }
        let r = parse(r#"{"items":[{"label":"a","value":"b","percent":1}]}"#);
        assert_eq!(r.items[0].percent, Some(1.0), "the ends of the range are in it");
    }

    #[test]
    fn a_reading_with_nothing_on_either_side_is_not_one() {
        let r = parse(
            r#"{"items":[{"label":"","value":"  "},{"label":"a","value":""},{"label":"","value":"b"}]}"#,
        );
        assert_eq!(r.items.len(), 2, "only the empty one goes");
    }

    /// These rows go beside the app's own, and a plugin that answers a thousand
    /// would push everything else off the screen.
    #[test]
    fn too_many_readings_are_cut() {
        let items: Vec<String> = (0..200)
            .map(|i| format!(r#"{{"label":"l{i}","value":"v"}}"#))
            .collect();
        let r = parse(&format!(r#"{{"items":[{}]}}"#, items.join(",")));
        assert_eq!(r.items.len(), StatusResult::MAX_ITEMS);
    }

    #[test]
    fn a_label_that_is_really_a_dump_is_cut() {
        let long = "x".repeat(1000);
        let r = parse(&format!(r#"{{"items":[{{"label":"{long}","value":"v"}}]}}"#));
        assert_eq!(r.items[0].label.chars().count(), StatusResult::MAX_TEXT);
    }

    /// Cut by characters rather than bytes, or a label ending mid-sequence
    /// reaches the app as invalid text.
    #[test]
    fn cutting_does_not_split_a_character() {
        let long = "温".repeat(1000);
        let r = parse(&format!(r#"{{"items":[{{"label":"{long}","value":"v"}}]}}"#));
        assert_eq!(r.items[0].label.chars().count(), StatusResult::MAX_TEXT);
        assert!(r.items[0].label.chars().all(|c| c == '温'));
    }

    #[test]
    fn a_missing_title_and_note_are_allowed() {
        let r = parse(r#"{"items":[{"label":"a","value":"b"}]}"#);
        assert!(r.title.is_empty());
        assert_eq!(r.note, None);
    }

    #[test]
    fn a_blank_note_is_the_same_as_none() {
        assert_eq!(parse(r#"{"items":[],"note":"   "}"#).note, None);
        assert_eq!(parse(r#"{"items":[],"note":" 3 of 20 "}"#).note.as_deref(), Some("3 of 20"));
    }

    /// What is refused is a document that is not this shape at all — everything
    /// else is trimmed, so one bad row costs a row.
    #[test]
    fn something_that_is_not_this_shape_is_refused() {
        assert!(StatusResult::parse(b"[]").is_err());
        assert!(StatusResult::parse(b"{}").is_err(), "`items` is required");
        assert!(StatusResult::parse(br#"{"items":"nope"}"#).is_err());
        assert!(StatusResult::parse(b"not json").is_err());
    }

    #[test]
    fn an_unknown_tone_is_refused_rather_than_guessed() {
        assert!(StatusResult::parse(br#"{"items":[{"label":"a","value":"b","tone":"rainbow"}]}"#)
            .is_err());
    }
}
