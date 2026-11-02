//! Command risk (`sbm_parser::command_risk`)
//!
//! What a shell command an AI agent proposes is worth: the reading the app's
//! Agent used to hold in Dart, the same one the monitor agent's Agent mode
//! runs, so both ask about the same commands.

use flutter_rust_bridge::frb;
pub use sbm_parser::command_risk::CommandRisk;

#[frb(mirror(CommandRisk))]
pub enum _CommandRisk {
    ReadOnly,
    Unknown,
    Caution,
    Destructive,
}

/// What [command] is worth: a known read, unrecognised, a change, or one
/// that loses something for good.
#[frb(sync)]
pub fn classify_command(command: String) -> CommandRisk {
    sbm_parser::command_risk::classify(&command)
}
