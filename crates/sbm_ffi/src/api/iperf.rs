//! iperf (`sbm_parser::iperf`)
//!
//! The host and port rules the app's iperf page used to hold in Dart, and the
//! command it opens a terminal with. The agent builds the same command for its
//! terminal `target`, from the same functions.

use sbm_parser::iperf;

/// The canonical host for `iperf`, or `None` if it is not one.
#[flutter_rust_bridge::frb(sync)]
pub fn iperf_normalize_host(raw: String) -> Option<String> {
    iperf::normalize_host(&raw)
}

/// The port as a number, or `None` if it is not one.
#[flutter_rust_bridge::frb(sync)]
pub fn iperf_valid_port(raw: String) -> Option<u16> {
    iperf::valid_port(&raw)
}

/// `iperf -c <host> -p <port>`. The host is validated again here, so a caller
/// cannot reach a command line by skipping [`iperf_normalize_host`].
#[flutter_rust_bridge::frb(sync)]
pub fn iperf_client_command(host: String, port: u16) -> Result<String, String> {
    iperf::client_command(&host, port).map_err(|e| e.to_string())
}
