//! Tailscale status parsing FFI (`sbm_parser::tailscale`).

use sbm_parser::tailscale;

pub struct TailscalePeerItem {
    pub id: String,
    pub name: String,
    pub dns_name: Option<String>,
    pub ips: Vec<String>,
    pub os: Option<String>,
    pub online: bool,
}

pub struct TailscaleStatusItem {
    pub state: Option<String>,
    pub tailnet: Option<String>,
    pub magic_dns_enabled: bool,
    pub magic_dns_suffix: Option<String>,
    pub peers: Vec<TailscalePeerItem>,
}

/// Parses raw `tailscale status --json` output into structured peer metadata.
#[flutter_rust_bridge::frb(sync)]
pub fn tailscale_parse_status(raw: String) -> Result<TailscaleStatusItem, String> {
    let parsed = tailscale::parse_status_json(&raw)?;
    Ok(TailscaleStatusItem {
        state: parsed.state,
        tailnet: parsed.tailnet,
        magic_dns_enabled: parsed.magic_dns_enabled,
        magic_dns_suffix: parsed.magic_dns_suffix,
        peers: parsed
            .peers
            .into_iter()
            .map(|p| TailscalePeerItem {
                id: p.id,
                name: p.name,
                dns_name: p.dns_name,
                ips: p.ips,
                os: p.os,
                online: p.online,
            })
            .collect(),
    })
}
