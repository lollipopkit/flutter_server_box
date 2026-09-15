use core::fmt;
use core::str::FromStr;
use core::time::Duration;
#[cfg(all(windows, feature = "dvc-com-plugin"))]
use std::path::PathBuf;
use std::sync::Arc;

use anyhow::Context as _;
use ironrdp_cfg::PropertySetExt as _;
use ironrdp_propertyset::PropertySet;
use url::Url;

// ── Extension registry ────────────────────────────────────────────────────────

type StaticChannelFn = Arc<dyn Fn(&mut ironrdp_connector::ClientConnector, &PropertySet) + Send + Sync>;
type DvcChannelFn = Arc<dyn Fn(&mut ironrdp_dvc::DrdynvcClient, &PropertySet) + Send + Sync>;

/// Private registry of user-supplied static and dynamic virtual channel factories.
///
/// Cloneable via `Arc`; the factory closures are shared across reconnects.
#[derive(Default)]
pub(crate) struct ExtensionRegistry {
    pub(crate) static_channels: Vec<StaticChannelFn>,
    pub(crate) dvc_channels: Vec<DvcChannelFn>,
}

impl Clone for ExtensionRegistry {
    fn clone(&self) -> Self {
        Self {
            static_channels: self.static_channels.clone(),
            dvc_channels: self.dvc_channels.clone(),
        }
    }
}

impl fmt::Debug for ExtensionRegistry {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ExtensionRegistry")
            .field("static_channels", &self.static_channels.len())
            .field("dvc_channels", &self.dvc_channels.len())
            .finish()
    }
}

// ── Public configuration types ────────────────────────────────────────────────

/// Fully resolved client configuration.
///
/// This is the typed surface consumed by [`crate::rdp::RdpClient`]. Build it with
/// [`ConfigBuilder`]; producing a `Config` from CLI arguments, `.rdp` files, or interactive
/// prompts is the consumer's responsibility (see `ironrdp-viewer` for a reference front-end).
///
/// The struct is opaque: fields are read-only via accessors so a built `Config` cannot drift into
/// an inconsistent state (e.g. mutating the connector without updating the originating
/// [`PropertySet`]).
#[derive(Clone)]
pub struct Config {
    pub(crate) connector: ironrdp_connector::Config,
    pub(crate) destination: Destination,
    pub(crate) tcp_destination: Option<Destination>,
    pub(crate) trusted_cert_sha256: Option<[u8; 32]>,
    pub(crate) transport: Transport,
    pub(crate) kerberos_config: Option<ironrdp_connector::credssp::KerberosConfig>,
    pub(crate) fake_events_interval: Option<Duration>,
    pub(crate) channels: ChannelConfig,

    /// DVC channel ↔ named-pipe proxy configuration.
    ///
    /// Each entry causes IronRDP to forward that DVC channel's traffic to/from the
    /// named pipe, allowing out-of-process DVC logic.
    #[cfg(feature = "dvc-pipe-proxy")]
    pub(crate) dvc_pipe_proxies: Vec<DvcProxyInfo>,

    /// Paths to DVC client plugin DLLs to load (Windows only).
    ///
    /// Each DLL is loaded via `LoadLibraryW` and its `VirtualChannelGetInstance` export is
    /// called to obtain DVC plugin COM objects.  Example: `C:\Windows\System32\webauthn.dll`.
    #[cfg(all(windows, feature = "dvc-com-plugin"))]
    pub(crate) dvc_plugins: Vec<PathBuf>,

    /// The merged PropertySet that produced this config, shared (read-only) with channel factories.
    ///
    /// Well-known secret properties are stripped when calling [`ConfigBuilder::build`].
    pub(crate) properties: PropertySet,

    pub(crate) extensions: ExtensionRegistry,
}

impl Config {
    /// Connector configuration handed to the RDP connection sequence.
    pub fn connector(&self) -> &ironrdp_connector::Config {
        &self.connector
    }

    /// Resolved RDP target (host + port).
    pub fn destination(&self) -> &Destination {
        &self.destination
    }

    /// Optional TCP endpoint used instead of the logical RDP destination.
    pub fn tcp_destination(&self) -> Option<&Destination> {
        self.tcp_destination.as_ref()
    }

    /// Selected transport (Direct, Gateway, or RDCleanPath).
    pub fn transport(&self) -> &Transport {
        &self.transport
    }

    /// Optional Kerberos/KDC proxy configuration.
    pub fn kerberos_config(&self) -> Option<&ironrdp_connector::credssp::KerberosConfig> {
        self.kerberos_config.as_ref()
    }

    /// Idle anti-lock fake-events interval, if enabled.
    pub fn fake_events_interval(&self) -> Option<Duration> {
        self.fake_events_interval
    }

    /// Channel/codec runtime toggles.
    pub fn channels(&self) -> &ChannelConfig {
        &self.channels
    }

    /// DVC named-pipe proxy mappings.
    #[cfg(feature = "dvc-pipe-proxy")]
    pub fn dvc_pipe_proxies(&self) -> &[DvcProxyInfo] {
        &self.dvc_pipe_proxies
    }

    /// DVC client plugin DLL paths (Windows only).
    #[cfg(all(windows, feature = "dvc-com-plugin"))]
    pub fn dvc_plugins(&self) -> &[PathBuf] {
        &self.dvc_plugins
    }

    /// Merged `.rdp` PropertySet that produced this config.
    pub fn properties(&self) -> &PropertySet {
        &self.properties
    }
}

impl fmt::Debug for Config {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut s = f.debug_struct("Config");
        s.field("connector", &self.connector);
        s.field("destination", &self.destination);
        s.field("tcp_destination", &self.tcp_destination);
        s.field("trusted_cert_sha256", &self.trusted_cert_sha256.as_ref().map(|_| "[redacted]"));
        s.field("transport", &self.transport);
        s.field("kerberos_config", &self.kerberos_config);
        s.field("fake_events_interval", &self.fake_events_interval);
        s.field("channels", &self.channels);
        #[cfg(feature = "dvc-pipe-proxy")]
        s.field("dvc_pipe_proxies", &self.dvc_pipe_proxies);
        #[cfg(all(windows, feature = "dvc-com-plugin"))]
        s.field("dvc_plugins", &self.dvc_plugins);
        s.field("extensions", &self.extensions);
        s.finish()
    }
}

/// Resolved clipboard backend selection.
///
/// Platform-specific details (e.g., which native clipboard backend to use) are handled
/// internally by the library when [`Enable`](ClipboardType::Enable) is selected.
#[cfg(feature = "clipboard")]
#[derive(Debug, Copy, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum ClipboardType {
    /// Enable clipboard redirection (use the best available backend).
    Enable,
    /// Disable clipboard redirection entirely.
    Disable,
    /// Use a stub clipboard backend (for testing or headless usage).
    // FIXME: the `Stub` concept arguably shouldn't live in ironrdp-client. Investigate whether it
    // can move out via the extension/backend API, so the stub backend stays in ironrdp-viewer as a
    // debugging tool. Note that other consumers (e.g. ironrdp-agent) may need their own custom
    // backend that is not integrated with the host system's clipboard either; the design should
    // accommodate plugging in arbitrary CliprdrBackendFactory implementations rather than baking
    // specific variants into the client.
    Stub,
}

/// Channel and codec runtime toggles.
///
/// Each field is only present when the corresponding Cargo feature is enabled.
/// The defaults for all optional fields are `true` (enabled) when the feature is on.
// TODO: Also add flags for all the channels that are not behind Cargo feature flags.
// Examples: ECHO and Display Control virtual channels.
#[derive(Clone, Debug)]
pub struct ChannelConfig {
    /// Enable the RDPSND (audio) virtual channel.
    #[cfg(feature = "sound")]
    pub sound: bool,

    /// Clipboard redirection mode.
    #[cfg(feature = "clipboard")]
    pub clipboard: ClipboardType,

    /// Device-redirection (RDPDR) configuration.
    #[cfg(feature = "rdpdr")]
    pub rdpdr: RdpdrConfig,

    /// Enable QOI bitmap codec.
    ///
    /// When `false`, the QOI codec is removed from `connector.bitmap.codecs` before connecting
    /// even if the `qoi` feature is compiled in.
    #[cfg(feature = "qoi")]
    pub qoi: bool,

    /// Enable QOIZ (QOI with zlib) bitmap codec.
    #[cfg(feature = "qoiz")]
    pub qoiz: bool,
}

#[cfg_attr(
    not(any(feature = "sound", feature = "clipboard", feature = "qoi", feature = "qoiz")),
    expect(
        clippy::derivable_impls,
        reason = "fields setting non-default values are feature-gated; the impl is only trivially derivable in some feature combinations"
    )
)]
impl Default for ChannelConfig {
    fn default() -> Self {
        Self {
            #[cfg(feature = "sound")]
            sound: true,
            #[cfg(feature = "clipboard")]
            clipboard: ClipboardType::Enable,
            #[cfg(feature = "rdpdr")]
            rdpdr: RdpdrConfig::default(),
            #[cfg(feature = "qoi")]
            qoi: true,
            #[cfg(feature = "qoiz")]
            qoiz: true,
        }
    }
}

/// RDPDR (device redirection) runtime configuration.
#[cfg(feature = "rdpdr")]
#[derive(Clone, Debug)]
pub struct RdpdrConfig {
    /// Enable device redirection at all.
    pub enabled: bool,

    /// Enable smart-card redirection within RDPDR.
    #[cfg(feature = "smartcard")]
    pub smartcard: bool,
}

#[cfg(feature = "rdpdr")]
impl Default for RdpdrConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            #[cfg(feature = "smartcard")]
            smartcard: true,
        }
    }
}

/// Fully-resolved transport selection for an established RDP connection.
///
/// This is the form stored in [`Config`] and consumed by the connection code: every variant
/// carries all the data the transport needs, including any credentials. To *configure* a transport
/// on a [`ConfigBuilder`], use the granular [`TransportKind`] instead — it carries only the
/// addressing, leaving secrets to be supplied (or prompted for) separately.
#[derive(Clone, Debug, Default)]
pub enum Transport {
    /// Plain TCP → TLS direct connection to the RDP server.
    #[default]
    Direct,

    /// Connect via an RDS gateway (MS-TSGU / MSTSGU).
    ///
    /// The target RDP server is derived from [`Config::destination`]; the gateway
    /// only needs its own endpoint and credentials.
    ///
    /// NOTE: the destination port is currently not forwarded to the gateway.
    /// If `ironrdp-mstsgu` hardcodes port 3389, open a follow-up issue.
    #[cfg(feature = "gateway")]
    Gateway(GatewayConfig),

    /// Connect via an RDCleanPath proxy (WebSocket-based).
    RDCleanPath(RDCleanPathConfig),
}

/// Transport selection used to configure a [`ConfigBuilder`].
///
/// Only the *addressing* of the transport is provided here (the gateway endpoint, the RDCleanPath
/// URL). The associated secrets — gateway username/password and the RDCleanPath authentication
/// token — are supplied through their own dedicated `with_*` methods
/// ([`with_gateway_username`](ConfigBuilder::with_gateway_username),
/// [`with_gateway_password`](ConfigBuilder::with_gateway_password),
/// [`with_rdcleanpath_token`](ConfigBuilder::with_rdcleanpath_token)).
///
/// Decoupling addressing from secrets means the latter can be tracked as [`MissingField`]s and
/// resolved independently (e.g. prompted interactively) instead of having to be known up-front when
/// the transport is selected. The builder assembles the resolved [`Transport`] from this selection
/// and the collected credentials in [`build`](ConfigBuilder::build).
#[derive(Clone, Debug, Default)]
pub enum TransportKind {
    /// Plain TCP → TLS direct connection to the RDP server.
    #[default]
    Direct,

    /// Connect via an RDS gateway (MS-TSGU / MSTSGU).
    ///
    /// Gateway credentials are supplied separately via
    /// [`with_gateway_username`](ConfigBuilder::with_gateway_username) /
    /// [`with_gateway_password`](ConfigBuilder::with_gateway_password).
    #[cfg(feature = "gateway")]
    Gateway {
        /// Gateway endpoint address (e.g., `"rdg.contoso.com:443"`).
        endpoint: String,
    },

    /// Connect via an RDCleanPath proxy (WebSocket-based).
    ///
    /// The authentication token is supplied separately via
    /// [`with_rdcleanpath_token`](ConfigBuilder::with_rdcleanpath_token).
    RDCleanPath {
        /// RDCleanPath proxy URL.
        url: Url,
    },
}

/// Endpoint and credentials for a fully-resolved RDS gateway connection.
#[cfg(feature = "gateway")]
#[derive(Clone, Debug)]
pub struct GatewayConfig {
    /// Gateway endpoint address (e.g., `"rdg.contoso.com:443"`).
    pub endpoint: String,
    /// Gateway username.
    pub username: String,
    /// Gateway password.
    pub password: String,
}

// ── Destination ───────────────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Destination {
    name: String,
    port: u16,
}

impl Destination {
    pub fn new(addr: impl Into<String>) -> anyhow::Result<Self> {
        const RDP_DEFAULT_PORT: u16 = 3389;

        let addr = addr.into();

        if let Some(addr_split) = addr.rsplit_once(':') {
            if let Ok(sock_addr) = addr.parse::<core::net::SocketAddr>() {
                Ok(Self {
                    name: sock_addr.ip().to_string(),
                    port: sock_addr.port(),
                })
            } else if addr.parse::<core::net::Ipv6Addr>().is_ok() {
                Ok(Self {
                    name: addr,
                    port: RDP_DEFAULT_PORT,
                })
            } else {
                Ok(Self {
                    name: addr_split.0.to_owned(),
                    port: addr_split.1.parse().context("invalid port")?,
                })
            }
        } else {
            Ok(Self {
                name: addr,
                port: RDP_DEFAULT_PORT,
            })
        }
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn port(&self) -> u16 {
        self.port
    }

    /// Construct a `Destination` from already-validated components.
    ///
    /// Intended for front-ends that have already resolved the host and port from their own
    /// configuration sources (CLI flags, `.rdp` files, IPC schemas).
    pub fn from_parts(name: impl Into<String>, port: u16) -> Self {
        Self {
            name: name.into(),
            port,
        }
    }
}

impl fmt::Display for Destination {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // IPv6 addresses must be bracketed in host:port notation.
        if self.name.parse::<core::net::Ipv6Addr>().is_ok() {
            write!(f, "[{}]:{}", self.name, self.port)
        } else {
            write!(f, "{}:{}", self.name, self.port)
        }
    }
}

impl FromStr for Destination {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::new(s)
    }
}

impl From<Destination> for ironrdp_connector::ServerName {
    fn from(value: Destination) -> Self {
        Self::new(value.name)
    }
}

impl From<&Destination> for ironrdp_connector::ServerName {
    fn from(value: &Destination) -> Self {
        Self::new(&value.name)
    }
}

// ── RDCleanPath & DVC proxy ───────────────────────────────────────────────────

/// URL and authentication token for a fully-resolved RDCleanPath connection.
#[derive(Clone, Debug)]
pub struct RDCleanPathConfig {
    /// RDCleanPath proxy URL.
    pub url: Url,
    /// RDCleanPath authentication token (secret).
    pub auth_token: String,
}

/// Name-to-pipe mapping for a single DVC proxy channel.
#[derive(Clone, Debug)]
pub struct DvcProxyInfo {
    pub channel_name: String,
    pub pipe_name: String,
}

impl FromStr for DvcProxyInfo {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let (channel_name, pipe_name) = s
            .split_once('=')
            .context("missing '=' delimiter in DVC proxy specification")?;
        Ok(Self {
            channel_name: channel_name.to_owned(),
            pipe_name: pipe_name.to_owned(),
        })
    }
}

// ── ConfigBuilder ─────────────────────────────────────────────────────────────

const RDP_DEFAULT_PORT: u16 = 3389;
const DEFAULT_WIDTH: u16 = 1280;
const DEFAULT_HEIGHT: u16 = 720;

/// A configuration value that the consumer must supply before [`ConfigBuilder::build`] can succeed.
///
/// Query the outstanding ones with [`ConfigBuilder::missing`], resolve each (prompt the user, or
/// derive a value), set it via the matching `with_*` method, then build.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MissingField {
    /// Target server address (host[:port]).
    ServerAddress,
    /// RDP account user name.
    Username,
    /// RDP account password.
    Password,
    /// Gateway user name (only when a gateway transport is selected).
    GatewayUsername,
    /// Gateway password (only when a gateway transport is selected).
    GatewayPassword,
    /// RDCleanPath authentication token (only when an RDCleanPath transport is selected).
    RDCleanPathToken,
    /// Client build number (frontend-derived).
    ClientBuild,
    /// Client directory path (frontend-derived).
    ClientDir,
    /// Client platform (frontend-derived).
    Platform,
    /// Client computer name (frontend-derived).
    ClientName,
}

impl fmt::Display for MissingField {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            Self::ServerAddress => "server address",
            Self::Username => "username",
            Self::Password => "password",
            Self::GatewayUsername => "gateway username",
            Self::GatewayPassword => "gateway password",
            Self::RDCleanPathToken => "RDCleanPath token",
            Self::ClientBuild => "client build",
            Self::ClientDir => "client dir",
            Self::Platform => "platform",
            Self::ClientName => "client name",
        };
        f.write_str(s)
    }
}

/// Builder for [`Config`].
///
/// No defaults are created up-front for required values; they are tracked as unset until provided.
/// Truly optional settings receive sensible defaults inside [`build`](ConfigBuilder::build). Use
/// [`missing`](ConfigBuilder::missing) to discover which required fields still need a value.
///
/// # Duplicate-channel behaviour
///
/// * **Static channels** are keyed by the concrete processor `TypeId`; registering two factories
///   with the same concrete type silently shadows the earlier one via
///   [`ironrdp_connector::ClientConnector::attach_static_channel`].
/// * **DVC channels** are keyed by channel name; duplicate names follow
///   [`ironrdp_dvc::DrdynvcClient`]'s overwrite semantics.
///
/// # Custom-channel configuration keys
///
/// Factory closures registered with [`with_static_channel`](Self::with_static_channel) and
/// [`with_dvc`](Self::with_dvc) receive the merged [`PropertySet`], so a custom channel can read
/// its own settings (enabled/disabled, endpoints, flags) straight from the `.rdp` file. Which keys
/// to read is entirely up to the channel: there is no enforced naming scheme. By convention,
/// IronRDP's own extension keys use an `ironrdp_` prefix to avoid colliding with standard Microsoft
/// keys, and custom channels are encouraged (but not required) to namespace their keys similarly
/// (e.g. `mycorp_mychannel_enabled`). A channel may equally reuse a standard MS key when that fits,
/// or adopt a completely different pattern if warranted — these are only conventions.
#[derive(Default)]
pub struct ConfigBuilder {
    // Required (no default).
    destination: Option<Destination>,
    tcp_destination: Option<Destination>,
    trusted_cert_sha256: Option<[u8; 32]>,
    username: Option<String>,
    password: Option<String>,
    client_build: Option<u32>,
    client_dir: Option<String>,
    client_name: Option<String>,
    platform: Option<ironrdp_pdu::rdp::capability_sets::MajorPlatformType>,
    gateway_username: Option<String>,
    gateway_password: Option<String>,

    // Optional (defaulted at build time).
    domain: Option<String>,
    enable_tls: Option<bool>,
    enable_credssp: Option<bool>,
    keyboard_type: Option<ironrdp_pdu::gcc::KeyboardType>,
    keyboard_subtype: Option<u32>,
    keyboard_functional_keys_count: Option<u32>,
    ime_file_name: Option<String>,
    dig_product_id: Option<String>,
    desktop_width: Option<u16>,
    desktop_height: Option<u16>,
    desktop_scale_factor: Option<u32>,
    color_depth: Option<u32>,
    codecs: Vec<String>,
    autologon: Option<bool>,
    enable_server_pointer: Option<bool>,
    pointer_software_rendering: Option<bool>,
    enable_audio_playback: Option<bool>,
    compression_type: Option<ironrdp_pdu::rdp::client_info::CompressionType>,
    compression_enabled: Option<bool>,
    alternate_shell: Option<String>,
    work_dir: Option<String>,

    transport: TransportKind,
    rdcleanpath_token: Option<String>,
    kerberos_config: Option<ironrdp_connector::credssp::KerberosConfig>,
    fake_events_interval: Option<Duration>,
    channels: ChannelConfig,
    #[cfg(feature = "dvc-pipe-proxy")]
    dvc_pipe_proxies: Vec<DvcProxyInfo>,
    #[cfg(all(windows, feature = "dvc-com-plugin"))]
    dvc_plugins: Vec<PathBuf>,
    properties: PropertySet,
    extensions: ExtensionRegistry,
}

impl ConfigBuilder {
    pub fn new() -> Self {
        Self::default()
    }

    #[must_use]
    pub fn with_destination(mut self, destination: Destination) -> Self {
        // Classify the host so the persisted `full address` follows TargetAddr's formatting rules
        // (notably, IPv6 addresses must be bracketed). A bare `TargetHost::Domain` would drop the
        // brackets and desynchronize the PropertySet from its own canonical formatting.
        let host = match destination.name.parse::<core::net::IpAddr>() {
            Ok(ip) => ironrdp_cfg::TargetHost::Ip(ip),
            Err(_) => ironrdp_cfg::TargetHost::Domain(destination.name.clone()),
        };
        self.properties
            .set_full_address(&ironrdp_cfg::TargetAddr { host, port: None });
        self.properties.set_server_port(destination.port);
        self.properties.clear_alternate_full_address();
        self.destination = Some(destination);
        self
    }

    /// Set a transport-only endpoint while keeping `destination` as the TLS
    /// server name and CredSSP target. This is used for SSH local tunnels.
    #[must_use]
    pub fn with_tcp_destination(mut self, destination: Destination) -> Self {
        self.tcp_destination = Some(destination);
        self
    }

    /// Allow an otherwise untrusted leaf certificate when its SHA-256 digest
    /// exactly matches this pin.
    #[must_use]
    pub fn with_trusted_cert_sha256(mut self, fingerprint: [u8; 32]) -> Self {
        self.trusted_cert_sha256 = Some(fingerprint);
        self
    }

    #[must_use]
    pub fn with_username(mut self, username: impl Into<String>) -> Self {
        let username = username.into();
        self.username = Some(username.clone());
        self.properties.set_username(username);
        self
    }

    /// Set the domain used by the RDP account credentials. Upserts the `domain` property.
    #[must_use]
    pub fn with_domain(mut self, domain: impl Into<String>) -> Self {
        let domain = domain.into();
        self.properties.set_domain(domain.clone());
        self.domain = Some(domain);
        self
    }

    #[must_use]
    pub fn with_password(mut self, password: impl Into<String>) -> Self {
        self.password = Some(password.into());
        self
    }

    #[must_use]
    pub fn with_gateway_username(mut self, username: impl Into<String>) -> Self {
        let username = username.into();
        self.gateway_username = Some(username.clone());
        self.properties.set_gateway_username(username);
        self
    }

    #[must_use]
    pub fn with_gateway_password(mut self, password: impl Into<String>) -> Self {
        self.gateway_password = Some(password.into());
        self
    }

    #[must_use]
    pub fn with_client_build(mut self, build: u32) -> Self {
        self.client_build = Some(build);
        self
    }

    #[must_use]
    pub fn with_client_dir(mut self, dir: impl Into<String>) -> Self {
        self.client_dir = Some(dir.into());
        self
    }

    #[must_use]
    pub fn with_client_name(mut self, name: impl Into<String>) -> Self {
        self.client_name = Some(name.into());
        self
    }

    #[must_use]
    pub fn with_platform(mut self, platform: ironrdp_pdu::rdp::capability_sets::MajorPlatformType) -> Self {
        self.platform = Some(platform);
        self
    }

    #[must_use]
    pub fn with_keyboard_type(mut self, ty: ironrdp_pdu::gcc::KeyboardType) -> Self {
        self.keyboard_type = Some(ty);
        self
    }

    #[must_use]
    pub fn with_keyboard_subtype(mut self, subtype: u32) -> Self {
        self.keyboard_subtype = Some(subtype);
        self
    }

    #[must_use]
    pub fn with_keyboard_functional_keys_count(mut self, count: u32) -> Self {
        self.keyboard_functional_keys_count = Some(count);
        self
    }

    #[must_use]
    pub fn with_ime_file_name(mut self, name: impl Into<String>) -> Self {
        self.ime_file_name = Some(name.into());
        self
    }

    #[must_use]
    pub fn with_dig_product_id(mut self, id: impl Into<String>) -> Self {
        self.dig_product_id = Some(id.into());
        self
    }

    #[must_use]
    pub fn with_color_depth(mut self, depth: u32) -> Self {
        self.color_depth = Some(depth);
        self.properties.set_color_depth(depth);
        self
    }

    /// Set the desktop width (in pixels) to request. Upserts the `desktopwidth` property.
    ///
    /// Together with [`with_desktop_height`](Self::with_desktop_height) this becomes the initial
    /// [`DesktopSize`](ironrdp_connector::DesktopSize) advertised to the server.
    #[must_use]
    pub fn with_desktop_width(mut self, width: u16) -> Self {
        self.desktop_width = Some(width);
        self.properties.set_desktop_width(width);
        self
    }

    /// Set the desktop height (in pixels) to request. Upserts the `desktopheight` property.
    ///
    /// Together with [`with_desktop_width`](Self::with_desktop_width) this becomes the initial
    /// [`DesktopSize`](ironrdp_connector::DesktopSize) advertised to the server.
    #[must_use]
    pub fn with_desktop_height(mut self, height: u16) -> Self {
        self.desktop_height = Some(height);
        self.properties.set_desktop_height(height);
        self
    }

    /// Set the desktop scale factor (percentage, typically 100–500) to request. Upserts the
    /// `desktopscalefactor` property.
    ///
    /// This becomes the `desktop_scale_factor` in the `TS_UD_CS_CORE` GCC structure.
    #[must_use]
    pub fn with_desktop_scale_factor(mut self, scale: u32) -> Self {
        self.desktop_scale_factor = Some(scale);
        self.properties.set_desktop_scale_factor(scale);
        self
    }

    /// Enable or disable TLS + Network Level Authentication (NLA) using CredSSP. Upserts the
    /// `enablecredsspsupport` property.
    ///
    /// NLA allows authentication to be performed before session establishment, considerably
    /// reducing the attack surface compared to the legacy TLS security protocol. When connecting to
    /// NLA-capable servers it is recommended to also disable plain TLS via
    /// [`with_tls(false)`](Self::with_tls).
    #[doc(alias("with_nla", "with_enable_credssp"))]
    #[must_use]
    pub fn with_credssp(mut self, enabled: bool) -> Self {
        self.enable_credssp = Some(enabled);
        self.properties.set_enable_credssp_support(enabled);
        self
    }

    /// Set the bitmap codecs (e.g. `["remotefx:on"]`). Not reflected in the PropertySet.
    #[must_use]
    pub fn with_codecs(mut self, codecs: Vec<String>) -> Self {
        self.codecs = codecs;
        self
    }

    #[must_use]
    pub fn with_autologon(mut self, enabled: bool) -> Self {
        self.autologon = Some(enabled);
        self.properties.set_autologon(enabled);
        self
    }

    /// Enable or disable TLS + Graphical login (legacy security protocol; also called SSL). Upserts
    /// the `ironrdp_tls` property.
    ///
    /// When this security protocol is negotiated, the RDP server shows a graphical login screen and
    /// the full connection sequence is performed with all static channels joined and active. This
    /// exposes a wide attack surface (MITM, server-side and client-side takeover, file stealing) and
    /// is being phased out. Set this to `false` to effectively enforce usage of NLA/CredSSP on the
    /// client side (see [`with_credssp`](Self::with_credssp)).
    #[doc(alias("with_enable_tls"))]
    #[must_use]
    pub fn with_tls(mut self, enabled: bool) -> Self {
        self.enable_tls = Some(enabled);
        self.properties.set_enable_tls(enabled);
        self
    }

    #[must_use]
    pub fn with_server_pointer(mut self, enabled: bool) -> Self {
        self.enable_server_pointer = Some(enabled);
        self.properties.set_server_pointer(enabled);
        self
    }

    /// Enable or disable software pointer rendering. When enabled, the session composites the
    /// remote cursor directly into the decoded framebuffer (instead of emitting it as separate
    /// pointer events for a hardware/overlay cursor). Useful for headless clients that have no
    /// overlay of their own and want the cursor captured in the frame.
    #[must_use]
    pub fn with_pointer_software_rendering(mut self, enabled: bool) -> Self {
        self.pointer_software_rendering = Some(enabled);
        self
    }

    /// Enable or disable bulk compression support. Upserts the `compression` property.
    #[must_use]
    pub fn with_compression(mut self, enabled: bool) -> Self {
        self.compression_enabled = Some(enabled);
        self.properties.set_compression(enabled);
        self
    }

    /// Set the bulk compression type directly. Upserts the `ironrdp_compressionlevel` property,
    /// or clears it when `ty` is `None`.
    ///
    /// When set, the `INFO_COMPRESSION` flag is included in the Client Info PDU and the specified
    /// compression type is advertised. The server may then send compressed PDUs using any
    /// compression algorithm up to and including this level:
    ///
    /// - `None` — no compression (default)
    /// - `Some(K8)` — MPPC with 8 KB history (RDP 4.0)
    /// - `Some(K64)` — MPPC with 64 KB history (RDP 5.0)
    /// - `Some(Rdp6)` — NCRUSH (RDP 6.0)
    /// - `Some(Rdp61)` — XCRUSH (RDP 6.1)
    #[must_use]
    pub fn with_compression_type(mut self, ty: Option<ironrdp_pdu::rdp::client_info::CompressionType>) -> Self {
        self.compression_type = ty;
        if let Some(ty) = ty {
            self.properties.set_compression_level(level_from_compression_type(ty));
        } else {
            self.properties.clear_compression_level();
        }
        self
    }

    /// Set the bulk compression type from a level (0–3). Out-of-range levels are ignored.
    ///
    /// The level maps to a [`CompressionType`](ironrdp_pdu::rdp::client_info::CompressionType):
    /// `0` → `K8`, `1` → `K64`, `2` → `Rdp6`, `3` → `Rdp61`. See
    /// [`with_compression_type`](Self::with_compression_type) for the semantics of each level.
    #[must_use]
    pub fn with_compression_level(self, level: u32) -> Self {
        match compression_type_from_level(level) {
            Ok(ty) => self.with_compression_type(Some(ty)),
            Err(_) => self,
        }
    }

    /// Select the transport. Upserts the corresponding addressing properties
    /// (`ironrdp_rdcleanpathurl`, `gatewayhostname`/`gatewayusagemethod`), clearing the other
    /// transport's properties so the PropertySet stays consistent.
    ///
    /// Secrets are *not* set here: supply gateway credentials via
    /// [`with_gateway_username`](Self::with_gateway_username) /
    /// [`with_gateway_password`](Self::with_gateway_password) and the RDCleanPath token via
    /// [`with_rdcleanpath_token`](Self::with_rdcleanpath_token).
    #[must_use]
    pub fn with_transport(mut self, transport: TransportKind) -> Self {
        match &transport {
            TransportKind::Direct => {
                self.properties.clear_rdcleanpath();
                self.properties.clear_gateway();
            }
            TransportKind::RDCleanPath { url } => {
                self.properties.clear_gateway();
                self.properties.set_rdcleanpath_url(url.to_string());
            }
            #[cfg(feature = "gateway")]
            TransportKind::Gateway { endpoint } => {
                self.properties.clear_rdcleanpath();
                self.properties.set_gateway_hostname(endpoint.clone());
                self.properties
                    .set_gateway_usage_method(ironrdp_cfg::GatewayUsageMethod::UseAlways);
            }
        }
        self.transport = transport;
        self
    }

    /// Set the RDCleanPath authentication token (only meaningful with an RDCleanPath transport).
    ///
    /// The token is a secret: like the gateway password, it is *not* mirrored into the PropertySet,
    /// and [`build`](Self::build) strips any token loaded from a `.rdp` file before exposing
    /// [`Config::properties`].
    #[must_use]
    pub fn with_rdcleanpath_token(mut self, token: impl Into<String>) -> Self {
        self.rdcleanpath_token = Some(token.into());
        self
    }

    /// Set the kerberos config. Upserts the `kdcproxyurl` property (or clears it when the config
    /// has no KDC proxy URL); `hostname` is derived from the client name and not stored separately.
    #[must_use]
    pub fn with_kerberos_config(mut self, cfg: ironrdp_connector::credssp::KerberosConfig) -> Self {
        if let Some(url) = &cfg.kdc_proxy_url {
            self.properties.set_kdc_proxy_url(url.to_string());
        } else {
            self.properties.clear_kdc_proxy_url();
        }
        self.kerberos_config = Some(cfg);
        self
    }

    #[must_use]
    pub fn with_fake_events_interval(mut self, interval: Duration) -> Self {
        self.fake_events_interval = Some(interval);
        self.properties
            .set_fake_events_interval(u32::try_from(interval.as_secs() / 60).unwrap_or(u32::MAX));
        self
    }

    /// Enable or disable RDPSND (audio) playback.
    #[cfg(feature = "sound")]
    #[must_use]
    pub fn with_sound(mut self, enabled: bool) -> Self {
        self.channels.sound = enabled;
        self.properties.set_audio_mode(if enabled {
            ironrdp_cfg::AudioMode::RedirectToClient
        } else {
            ironrdp_cfg::AudioMode::Disabled
        });
        self
    }

    /// Set the CLIPRDR (clipboard) redirection mode.
    #[cfg(feature = "clipboard")]
    #[must_use]
    pub fn with_clipboard(mut self, mode: ClipboardType) -> Self {
        self.channels.clipboard = mode;
        self.properties
            .set_redirect_clipboard(matches!(mode, ClipboardType::Enable));
        self
    }

    /// Enable or disable RDPDR (device redirection).
    #[cfg(feature = "rdpdr")]
    #[must_use]
    pub fn with_rdpdr(mut self, enabled: bool) -> Self {
        self.channels.rdpdr.enabled = enabled;
        self.properties.set_enable_rdpdr(enabled);
        self
    }

    /// Enable or disable smart-card redirection within RDPDR.
    #[cfg(feature = "smartcard")]
    #[must_use]
    pub fn with_smartcard(mut self, enabled: bool) -> Self {
        self.channels.rdpdr.smartcard = enabled;
        self.properties.set_enable_smartcard(enabled);
        self
    }

    /// Enable or disable QOI bitmap codec at runtime.
    #[cfg(feature = "qoi")]
    #[must_use]
    pub fn with_qoi(mut self, enabled: bool) -> Self {
        self.channels.qoi = enabled;
        self.properties.set_enable_qoi(enabled);
        self
    }

    /// Enable or disable QOIZ bitmap codec at runtime.
    #[cfg(feature = "qoiz")]
    #[must_use]
    pub fn with_qoiz(mut self, enabled: bool) -> Self {
        self.channels.qoiz = enabled;
        self.properties.set_enable_qoiz(enabled);
        self
    }

    // TODO: It can be useful to have a method for enabling or disabling all the extra channels at once.
    // Example: in tests, disable all + enable only the required channel.

    /// Add a DVC pipe proxy channel.
    #[cfg(feature = "dvc-pipe-proxy")]
    #[must_use]
    pub fn with_dvc_pipe_proxy(mut self, info: DvcProxyInfo) -> Self {
        self.dvc_pipe_proxies.push(info);
        self.properties
            .set_dvc_pipe_proxies(self.dvc_pipe_proxies.iter().map(|p| ironrdp_cfg::DvcPipeProxy {
                channel_name: p.channel_name.clone(),
                pipe_name: p.pipe_name.clone(),
            }));
        self
    }

    /// Add a DVC COM plugin DLL path (Windows only).
    #[cfg(all(windows, feature = "dvc-com-plugin"))]
    #[must_use]
    pub fn with_dvc_plugin(mut self, path: impl Into<PathBuf>) -> Self {
        self.dvc_plugins.push(path.into());
        self.properties
            .set_dvc_plugins(self.dvc_plugins.iter().map(PathBuf::as_path));
        self
    }

    /// Register a factory for a user-defined static virtual channel.
    ///
    /// `factory` is called once per connection attempt with the shared (read-only) [`PropertySet`],
    /// so the channel can parametrize itself from the standard frontend config. Return `None` to
    /// disable the channel. Duplicate processor types follow `attach_static_channel` overwrite semantics.
    #[must_use]
    pub fn with_static_channel<P, F>(mut self, factory: F) -> Self
    where
        F: Fn(&PropertySet) -> Option<P> + Send + Sync + 'static,
        P: ironrdp_svc::SvcClientProcessor + 'static,
    {
        let cb: StaticChannelFn = Arc::new(move |connector: &mut ironrdp_connector::ClientConnector, ps| {
            if let Some(processor) = factory(ps) {
                connector.attach_static_channel(processor);
            }
        });
        self.extensions.static_channels.push(cb);
        self
    }

    /// Register a factory for a user-defined dynamic virtual channel.
    ///
    /// `factory` is called once per connection attempt with the shared (read-only) [`PropertySet`],
    /// so the channel can parametrize itself from the standard frontend config. Return `None` to
    /// disable the channel. Duplicate channel names follow `DrdynvcClient` overwrite semantics.
    #[must_use]
    pub fn with_dvc<P, F>(mut self, factory: F) -> Self
    where
        F: Fn(&PropertySet) -> Option<P> + Send + Sync + 'static,
        P: ironrdp_dvc::DvcProcessor + 'static,
    {
        let cb: DvcChannelFn = Arc::new(move |drdynvc, ps| {
            if let Some(processor) = factory(ps) {
                drdynvc.attach_dynamic_channel(processor);
            }
        });
        self.extensions.dvc_channels.push(cb);
        self
    }

    /// List the required fields that still need a value before [`build`](Self::build) can succeed.
    ///
    /// Gateway credentials are only required when a gateway transport is selected.
    pub fn missing(&self) -> Vec<MissingField> {
        let mut missing = Vec::new();
        if self.destination.is_none() {
            missing.push(MissingField::ServerAddress);
        }
        if self.username.is_none() {
            missing.push(MissingField::Username);
        }
        if self.password.is_none() {
            missing.push(MissingField::Password);
        }
        #[cfg(feature = "gateway")]
        if matches!(self.transport, TransportKind::Gateway { .. }) {
            if self.gateway_username.is_none() {
                missing.push(MissingField::GatewayUsername);
            }
            if self.gateway_password.is_none() {
                missing.push(MissingField::GatewayPassword);
            }
        }
        if matches!(self.transport, TransportKind::RDCleanPath { .. }) && self.rdcleanpath_token.is_none() {
            missing.push(MissingField::RDCleanPathToken);
        }
        if self.client_build.is_none() {
            missing.push(MissingField::ClientBuild);
        }
        if self.client_dir.is_none() {
            missing.push(MissingField::ClientDir);
        }
        if self.platform.is_none() {
            missing.push(MissingField::Platform);
        }
        if self.client_name.is_none() {
            missing.push(MissingField::ClientName);
        }
        missing
    }

    /// Build the [`Config`], filling optional settings with sensible defaults.
    ///
    /// Fails if any required field is unset; inspect [`missing`](Self::missing) beforehand to resolve them.
    #[expect(
        clippy::missing_panics_doc,
        reason = "a panic here would be a bug (secrets are guaranteed present by missing()), not documented behavior"
    )]
    pub fn build(self) -> anyhow::Result<Config> {
        use ironrdp_pdu::rdp::capability_sets::client_codecs_capabilities;
        use ironrdp_pdu::rdp::client_info::{PerformanceFlags, TimezoneInfo};

        let missing = self.missing();
        if !missing.is_empty() {
            anyhow::bail!(
                "missing required configuration: {}",
                missing
                    .iter()
                    .map(MissingField::to_string)
                    .collect::<Vec<_>>()
                    .join(", ")
            );
        }

        let codecs: Vec<&str> = self.codecs.iter().map(String::as_str).collect();
        let codecs = client_codecs_capabilities(&codecs).map_err(|help| anyhow::anyhow!("{help}"))?;
        let color_depth = self.color_depth.unwrap_or(32);
        if color_depth != 16 && color_depth != 32 {
            anyhow::bail!("invalid color depth: only 16 and 32 bit color depths are supported");
        }
        let bitmap = ironrdp_connector::BitmapConfig {
            color_depth,
            lossy_compression: true,
            codecs,
        };

        // Resolve the granular transport selection into the bundled form, folding in the separately
        // tracked secrets (gateway credentials, RDCleanPath token).
        #[expect(
            clippy::unwrap_used,
            reason = "the transport secrets are guaranteed present by the missing() check above"
        )]
        let transport = match self.transport {
            TransportKind::Direct => Transport::Direct,
            #[cfg(feature = "gateway")]
            TransportKind::Gateway { endpoint } => Transport::Gateway(GatewayConfig {
                endpoint,
                username: self.gateway_username.unwrap(),
                password: self.gateway_password.unwrap(),
            }),
            TransportKind::RDCleanPath { url } => Transport::RDCleanPath(RDCleanPathConfig {
                url,
                auth_token: self.rdcleanpath_token.unwrap(),
            }),
        };

        let client_name = self.client_name.unwrap_or_default();
        let kerberos_config = self
            .kerberos_config
            .or_else(|| kerberos_config_from_properties(&self.properties, &client_name));

        // Bulk compression is enabled by default. We default to MPPC 64K (RDP5) rather than the
        // richer XCRUSH (RDP6.1) because it is the most universally supported and lowest-state
        // codec, and FastPath decompression is the only fully wired path.
        // FIXME: bump the default to RDP6.1 (XCRUSH) once slow-path bulk decompression is wired
        // (see ironrdp-session x224 path); until then a stateful codec risks silent corruption.
        let compression_type = if self.compression_enabled.unwrap_or(true) {
            Some(
                self.compression_type
                    .unwrap_or(ironrdp_pdu::rdp::client_info::CompressionType::K64),
            )
        } else {
            None
        };

        let connector = ironrdp_connector::Config {
            credentials: ironrdp_connector::Credentials::UsernamePassword {
                username: self.username.unwrap_or_default(),
                password: self.password.unwrap_or_default(),
            },
            domain: self.domain,
            enable_tls: self.enable_tls.unwrap_or(true),
            enable_credssp: self.enable_credssp.unwrap_or(true),
            keyboard_type: self
                .keyboard_type
                .unwrap_or(ironrdp_pdu::gcc::KeyboardType::IbmEnhanced),
            keyboard_subtype: self.keyboard_subtype.unwrap_or(0),
            keyboard_layout: 0,
            keyboard_functional_keys_count: self.keyboard_functional_keys_count.unwrap_or(12),
            ime_file_name: self.ime_file_name.unwrap_or_default(),
            dig_product_id: self.dig_product_id.unwrap_or_default(),
            desktop_size: ironrdp_connector::DesktopSize {
                width: self.desktop_width.unwrap_or(DEFAULT_WIDTH),
                height: self.desktop_height.unwrap_or(DEFAULT_HEIGHT),
            },
            desktop_scale_factor: self.desktop_scale_factor.unwrap_or(0),
            bitmap: Some(bitmap),
            client_build: self.client_build.unwrap_or_default(),
            client_name,
            client_dir: self.client_dir.unwrap_or_default(),
            platform: self
                .platform
                .unwrap_or(ironrdp_pdu::rdp::capability_sets::MajorPlatformType::UNSPECIFIED),
            hardware_id: None,
            license_cache: None,
            enable_server_pointer: self.enable_server_pointer.unwrap_or(true),
            autologon: self.autologon.unwrap_or(false),
            enable_audio_playback: self.enable_audio_playback.unwrap_or(true),
            request_data: None,
            pointer_software_rendering: self.pointer_software_rendering.unwrap_or(false),
            multitransport_flags: None,
            compression_type,
            performance_flags: PerformanceFlags::default(),
            timezone_info: TimezoneInfo::default(),
            alternate_shell: self.alternate_shell.unwrap_or_default(),
            work_dir: self.work_dir.unwrap_or_default(),
        };

        // To avoid easily leaking secrets, strip any known secret property before returning the resulting Config.
        let mut properties = self.properties;
        let detected_secrets = properties
            .iter()
            .filter(|(key, _)| ironrdp_cfg::is_secret_key(key))
            .map(|(key, _)| key.clone().into_owned())
            .collect::<Vec<_>>();
        detected_secrets.into_iter().for_each(|key| {
            properties.remove(&key);
        });

        Ok(Config {
            connector,
            destination: self.destination.context("server address is required")?,
            tcp_destination: self.tcp_destination,
            trusted_cert_sha256: self.trusted_cert_sha256,
            transport,
            kerberos_config,
            fake_events_interval: self.fake_events_interval,
            channels: self.channels,
            #[cfg(feature = "dvc-pipe-proxy")]
            dvc_pipe_proxies: self.dvc_pipe_proxies,
            #[cfg(all(windows, feature = "dvc-com-plugin"))]
            dvc_plugins: self.dvc_plugins,
            properties,
            extensions: self.extensions,
        })
    }

    /// Build a [`Config`] from a `.rdp` [`PropertySet`], leaving anything not expressible as a
    /// property unset (query [`missing`](Self::missing) to resolve the rest).
    pub fn from_property_set(ps: &PropertySet) -> anyhow::Result<Self> {
        ConfigBuilder::new().with_property_set(ps)
    }

    /// Overlay a `.rdp` [`PropertySet`] on top of the current builder.
    ///
    /// Only properties present in `ps` set values, so this can be layered:
    /// `explicit setters → PropertySet → more setters`, last writer wins. Resolution rules:
    /// `full address` beats `alternate full address`, an embedded port beats `server port`, and
    /// transport precedence is RDCleanPath > Gateway > Direct.
    pub fn with_property_set(mut self, ps: &PropertySet) -> anyhow::Result<Self> {
        #[cfg(feature = "gateway")]
        use ironrdp_cfg::GatewayUsageMethod;
        use ironrdp_cfg::{AudioMode, TargetHost};

        self.properties.merge(ps);

        let target = ps.full_address().context("invalid 'full address'")?.or(ps
            .alternate_full_address()
            .context("invalid 'alternate full address'")?);
        if let Some(target) = target {
            let port = target
                .port
                .or(ps.server_port().context("invalid 'server port'")?)
                .unwrap_or(RDP_DEFAULT_PORT);
            let name = match target.host {
                TargetHost::Ip(ip) => ip.to_string(),
                TargetHost::Domain(host) => host,
            };
            self.destination = Some(Destination::from_parts(name, port));
        }

        if let Some(username) = ps.username() {
            self.username = Some(username.to_owned());
        }
        if let Some(password) = ps.clear_text_password() {
            self.password = Some(password.to_owned());
        }
        if let Some(domain) = ps.domain() {
            self.domain = Some(domain.to_owned());
        }
        if let Some(enable_credssp) = ps.enable_credssp_support() {
            self.enable_credssp = Some(enable_credssp);
        }
        if let Some(enable_tls) = ps.enable_tls() {
            self.enable_tls = Some(enable_tls);
        }
        if let Some(server_pointer) = ps.server_pointer() {
            self.enable_server_pointer = Some(server_pointer);
        }
        if let Some(autologon) = ps.autologon() {
            self.autologon = Some(autologon);
        }
        if let Some(scale) = ps.desktop_scale_factor().ok().flatten() {
            self.desktop_scale_factor = Some(scale);
        }
        if let Some(width) = ps.desktop_width().ok().flatten() {
            self.desktop_width = Some(width);
        }
        if let Some(height) = ps.desktop_height().ok().flatten() {
            self.desktop_height = Some(height);
        }
        if let Some(shell) = ps.alternate_shell() {
            self.alternate_shell = Some(shell.to_owned());
        }
        if let Some(dir) = ps.shell_working_directory() {
            self.work_dir = Some(dir.to_owned());
        }
        if let Some(minutes) = ps.fake_events_interval() {
            self.fake_events_interval = Some(Duration::from_secs(u64::from(minutes) * 60));
        }
        if let Some(level) = ps.compression_level() {
            self.compression_type = Some(compression_type_from_level(level)?);
        }
        if let Some(enabled) = ps.compression() {
            self.compression_enabled = Some(enabled);
        }
        if let Some(depth) = ps.color_depth() {
            self.color_depth = Some(depth);
        }
        match ps.audio_mode() {
            Ok(Some(AudioMode::PlayOnServer | AudioMode::Disabled)) => self.enable_audio_playback = Some(false),
            Ok(Some(AudioMode::RedirectToClient)) => self.enable_audio_playback = Some(true),
            _ => {}
        }

        // Transport: RDCleanPath > Gateway > Direct.
        if let Some((url, token)) = ps.rdcleanpath_url().zip(ps.rdcleanpath_token()) {
            let url = Url::parse(url).context("invalid 'ironrdp_rdcleanpathurl'")?;
            self.transport = TransportKind::RDCleanPath { url };
            self.rdcleanpath_token = Some(token.to_owned());
        } else {
            #[cfg(feature = "gateway")]
            {
                let gateway_usage = ps
                    .gateway_usage_method()
                    .context("invalid Gateway usage method")?
                    .unwrap_or_default();

                let gateway_hostname = ps.gateway_hostname();

                let select_gateway_transport = match gateway_usage {
                    // Explicit gateway use.
                    GatewayUsageMethod::UseAlways => true,

                    // Approximation of Windows "try direct, then gateway" behavior.
                    GatewayUsageMethod::Detect => gateway_hostname.is_some(),

                    // IronRDP does not currently resolve MSTSC/client/GPO default gateway policy.
                    GatewayUsageMethod::UseDefaultSettings => false,

                    // Explicit no-gateway modes.
                    GatewayUsageMethod::Direct | GatewayUsageMethod::DirectBypassLocal => false,
                };

                if select_gateway_transport {
                    let endpoint = gateway_hostname.context("missing Gateway hostname")?;

                    self.transport = TransportKind::Gateway {
                        endpoint: endpoint.to_owned(),
                    };

                    if let Some(user) = ps.gateway_username() {
                        self.gateway_username = Some(user.to_owned());
                    }

                    if let Some(pass) = ps.gateway_password() {
                        self.gateway_password = Some(pass.to_owned());
                    }
                }
            }
        }

        if let Some(redirect) = ps.redirect_clipboard() {
            #[cfg(feature = "clipboard")]
            {
                self.channels.clipboard = if redirect {
                    ClipboardType::Enable
                } else {
                    ClipboardType::Disable
                };
            }
            let _ = redirect;
        }
        #[cfg(feature = "sound")]
        if matches!(ps.audio_mode(), Ok(Some(AudioMode::Disabled))) {
            self.channels.sound = false;
        }
        #[cfg(feature = "rdpdr")]
        if let Some(enabled) = ps.enable_rdpdr() {
            self.channels.rdpdr.enabled = enabled;
        }
        #[cfg(feature = "smartcard")]
        if let Some(enabled) = ps.enable_smartcard() {
            self.channels.rdpdr.smartcard = enabled;
        }
        #[cfg(feature = "qoi")]
        if let Some(enabled) = ps.enable_qoi() {
            self.channels.qoi = enabled;
        }
        #[cfg(feature = "qoiz")]
        if let Some(enabled) = ps.enable_qoiz() {
            self.channels.qoiz = enabled;
        }

        #[cfg(feature = "dvc-pipe-proxy")]
        for (idx, proxy) in ps.dvc_pipe_proxies().enumerate() {
            let proxy = proxy.with_context(|| format!("invalid DVC pipe proxy spec at idx {idx}"))?;
            self.dvc_pipe_proxies.push(DvcProxyInfo {
                channel_name: proxy.channel_name,
                pipe_name: proxy.pipe_name,
            });
        }

        #[cfg(all(windows, feature = "dvc-com-plugin"))]
        self.dvc_plugins.extend(ps.dvc_plugins());

        Ok(self)
    }
}

/// Map a bulk-compression level (0–3) to the corresponding [`CompressionType`].
///
/// 0 = MPPC 8K (RDP4), 1 = MPPC 64K (RDP5), 2 = NCRUSH (RDP6), 3 = XCRUSH (RDP6.1).
///
/// [`CompressionType`]: ironrdp_pdu::rdp::client_info::CompressionType
fn compression_type_from_level(level: u32) -> anyhow::Result<ironrdp_pdu::rdp::client_info::CompressionType> {
    use ironrdp_pdu::rdp::client_info::CompressionType;

    match level {
        0 => Ok(CompressionType::K8),
        1 => Ok(CompressionType::K64),
        2 => Ok(CompressionType::Rdp6),
        3 => Ok(CompressionType::Rdp61),
        _ => anyhow::bail!("invalid compression level: valid values are 0, 1, 2, 3"),
    }
}

fn level_from_compression_type(ty: ironrdp_pdu::rdp::client_info::CompressionType) -> u32 {
    use ironrdp_pdu::rdp::client_info::CompressionType;

    match ty {
        CompressionType::K8 => 0,
        CompressionType::K64 => 1,
        CompressionType::Rdp6 => 2,
        CompressionType::Rdp61 => 3,
    }
}

/// Derive a Kerberos/KDC-proxy config from `kdcproxyurl`/`kdcproxyname`, using `client_name` as the
/// SPN hostname. Returns `None` if no KDC proxy is configured or the URL is invalid.
fn kerberos_config_from_properties(
    ps: &PropertySet,
    client_name: &str,
) -> Option<ironrdp_connector::credssp::KerberosConfig> {
    use ironrdp_cfg::PropertySetExt as _;

    let kdc_proxy_url = ps.kdc_proxy_url().map(str::to_owned).or_else(|| {
        ps.kdc_proxy_name().map(|name| {
            if name.starts_with("http://") || name.starts_with("https://") {
                name.to_owned()
            } else {
                format!("https://{name}/KdcProxy")
            }
        })
    })?;

    Url::parse(&kdc_proxy_url)
        .ok()
        .map(|url| ironrdp_connector::credssp::KerberosConfig {
            kdc_proxy_url: Some(url),
            hostname: client_name.to_owned(),
        })
}
