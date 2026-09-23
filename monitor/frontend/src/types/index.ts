export interface SystemMetrics {
  timestamp: string;
  // Last refresh of CLI-backed extended fields such as battery, sensors, and
  // disk SMART data. `timestamp` updates every poll, including cycles that
  // carry these readings forward.
  extended_updated_at?: string;
  server_name: string;
  cpu_usage: number;
  // Wire-compatible with Monitor's `CpuCoreTime { used, total }`. The array
  // index identifies the core because the wire format has no ID or label.
  cpu_cores?: { used: number; total: number; usage_percent: number | null }[];
  memory: MemoryMetrics;
  swap: SwapMetrics;
  disk: DiskMetrics;
  network: NetworkMetrics;
  temperature?: number;
  temps?: TempReading[];
  sys?: string;
  // Linux `/etc/os-release` identifiers. Older agents provide only `sys`
  // (the `PRETTY_NAME` value).
  os_id?: string;
  os_id_like?: string[];
  cpu_brand?: string;
  // Detail lists are optional for compatibility with older agents.
  gpus?: GpuMetrics[];
  disk_details?: DiskDetail[];
  ifaces?: IfaceMetrics[];
  // Already formatted by the collector, e.g. "up 3 days, 2:14".
  uptime?: string;
  conn?: ConnMetrics;
  // Cumulative sector counters since boot (not a rate) — see diskio_rate
  // for a live speed derived from this
  diskio?: DiskIoMetrics[];
  // Bytes/sec since the previous poll; empty on the agent's first cycle or
  // for a device with no prior sample yet
  diskio_rate?: DiskIoRate[];
  batteries?: BatteryMetrics[];
  sensors?: SensorMetrics[];
  disk_smart?: DiskSmartMetrics[];
  /// Output of the user's custom commands, in the order they run in.
  /// Refreshed on the extended cycle, like the fields above it.
  custom_cmds?: CustomCmdOutput[];
}

export interface TempReading {
  device: string;
  value: number;
}

export interface CustomCmdOutput {
  name: string;
  output: string;
}

/// A custom command as it is stored: a file in the agent's
/// `~/.config/server_box/custom_cmds`, the same set the app edits over SSH.
export interface CustomCmd {
  name: string;
  cmd: string;
}

export interface CustomCmdsView {
  commands: CustomCmd[];
  /// Whether this panel may change them — writing one arranges for code to
  /// run as the agent's user, so it needs the same grant as the shell. A hint
  /// for the UI; the agent re-checks it on the write.
  editable: boolean;
}

export type FieldSupport = 'supported' | 'not_implemented' | 'hardware_dependent'

/// Platform-only support level per ServerStatus field — depends on OS, not
/// on any sample. See sbm_parser::capabilities for the three-state meaning:
/// 'not_implemented' = this platform never collects it (hide unconditionally),
/// 'hardware_dependent' = collected when present, empty just means no such
/// hardware, 'supported' = always populated when the command succeeds.
export type Platform = 'linux' | 'bsd' | 'windows'

export interface Capabilities {
  cpu: FieldSupport
  cpu_brand: FieldSupport
  mem: FieldSupport
  swap: FieldSupport
  disks: FieldSupport
  net: FieldSupport
  temps: FieldSupport
  conn: FieldSupport
  uptime: FieldSupport
  sys: FieldSupport
  host: FieldSupport
  diskio: FieldSupport
  batteries: FieldSupport
  sensors: FieldSupport
  /** Vendor-neutral per-device GPU support. Absent on older agents. */
  gpu?: FieldSupport
  nvidia: FieldSupport
  amd: FieldSupport
  disk_smart: FieldSupport
  // Mechanically derived from the same system_type() capabilities() is
  // computed from — 'bsd' covers macOS, the only Bsd target this ships on
  platform: Platform
  // Absent on agents predating the feature; treat as all-off
  remote_access?: RemoteAccess
}

/// Which remote-access paths this agent will actually accept, already
/// accounting for the transport check.
export interface RemoteAccess {
  terminal: boolean
  /// Whether a shell can be opened straight from this panel session, with no
  /// SSH credentials. Absent on agents predating the feature.
  full_access?: boolean
  /// Whether the agent's confined file API is available. Absent on agents
  /// predating remote file access.
  files?: boolean
  /// Whether `/api/v1/power` will shut this machine down. Absent on agents
  /// predating the endpoint, and granted by the same switch as `full_access` —
  /// but its own field, because an agent that predates the route answers
  /// `full_access` and would 404 the request.
  power?: boolean
}

export type PowerAction = 'shutdown' | 'reboot' | 'suspend'

/// What the machine did.
///
/// The action is destructive and one-shot, so the shapes worth telling apart
/// are: it ran (`exit_code` 0), sudo refused the password (`sudo_rejected`,
/// which is the one outcome the caller can do something about), and anything
/// else. A machine suspending under a command that then never returns is
/// normal, which is why a timeout is a field rather than an error.
export interface PowerResult {
  exit_code: number | null
  stdout: string
  stderr: string
  sudo_rejected: boolean
  truncated: boolean
  timed_out: boolean
}

export type WsTicketPurpose = 'terminal'

export interface WsTicketResponse {
  ticket: string
  expires_in: number
}

export interface ConnMetrics {
  max_conn: number;
  fail: number;
}

export interface DiskIoMetrics {
  dev: string;
  sectors_read: number;
  sectors_write: number;
  sectors_read_exact?: string;
  sectors_write_exact?: string;
}

export interface DiskIoRate {
  dev: string;
  read_bytes_per_sec: number;
  write_bytes_per_sec: number;
}

export interface BatteryMetrics {
  percent: number | null;
  status: 'charging' | 'discharging' | 'full' | 'unknown';
  name: string | null;
  cycle: number | null;
  tech: string | null;
}

export interface SensorMetrics {
  device: string;
  adapter: string;
  details: [string, string][];
}

export interface DiskSmartMetrics {
  device: string;
  healthy: boolean | null;
  temperature: number | null;
  model: string | null;
  serial: string | null;
  power_on_hours: number | null;
  power_cycle_count: number | null;
}

export interface GpuMetrics {
  id?: string;
  vendor?: string;
  name: string;
  usage_percent: number | null;
  temperature: number | null;
  power: string | null;
  memory_used: number | null;
  memory_total: number | null;
  memory_unit: string | null;
  fan_speed?: number | null;
  clock_speed?: number | null;
}

export interface DiskDetail {
  path: string;
  mount: string;
  fs_type?: string;
  used: number;
  total: number;
  usage_percent: number;
}

export interface IfaceMetrics {
  name: string;
  rx_bytes: number;
  tx_bytes: number;
  rx_bytes_exact?: string;
  tx_bytes_exact?: string;
}

export interface MemoryMetrics {
  total: number;
  used: number;
  free: number;
  usage_percent: number;
}

export interface SwapMetrics {
  total: number;
  used: number;
  usage_percent: number;
}

export interface DiskMetrics {
  total: number;
  used: number;
  free: number;
  usage_percent: number;
}

export interface NetworkMetrics {
  rx_bytes: number;
  tx_bytes: number;
  rx_bytes_exact?: string;
  tx_bytes_exact?: string;
}

export interface StatusResponse {
  name: string;
  cpu: string;
  memory: string;
  disk: string;
  network: string;
  temperature?: string;
  timestamp: string;
}

export interface HistoryPoint {
  timestamp: string;
  cpu: number;
  memory: number;
  disk: number;
  net_rx_speed: number;
  net_tx_speed: number;
  temperature?: number;
  diskio_read_speed: number;
  diskio_write_speed: number;
  battery_percent?: number;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
}

export interface User {
  username: string;
  token: string;
}

export interface ApiError {
  error: string;
}

export interface MonitoringRule {
  name: string;
  monitor_type: string;
  threshold: string;
  matcher: string;
}

export interface DataRetentionConfig {
  metrics_days: number;
  alerts_days: number;
  cleanup_interval_hours: number;
  max_db_size_mb: number;
}

/// One notification channel. `config` is the channel's own free-form settings
/// — a webhook's url/method/headers, a bark key, an iOS token — and carries
/// keys this panel knows nothing about (`legacy_go_format`, a webhook's
/// `expected_http_status`), so an editor must send the loaded object back with
/// its edits applied rather than rebuild it from the fields it renders.
///
/// A `null` value means "set on the agent, not disclosed"; the key being
/// absent means it is not set at all. Sending the `null` back keeps the stored
/// value — which is only possible with `from_index`, the position the entry was
/// loaded from, so a rename or a reorder does not lose a credential.
export interface PushEntry {
  name: string;
  push_type: string;
  config: Record<string, unknown>;
  from_index: number | null;
}

export interface PushView extends PushEntry {
  /// False when the agent has no sender for `push_type` and therefore cannot
  /// know which of the entry's keys are credentials: `config` comes back empty
  /// and the channel can be removed but not edited here.
  editable: boolean;
}

export interface PushPayload {
  pushes: PushEntry[];
  /// "N/duration", e.g. "1/1m". null = the agent's default of one per minute.
  push_rate: string | null;
}

export interface PushListView extends PushPayload {
  pushes: PushView[];
  /// The channel types this agent can actually deliver through.
  push_types: string[];
  /// Whether a saved channel only reaches the rule engine on the next restart.
  applies_on_restart: boolean;
}

export interface PushTestResult {
  ok: boolean;
  error?: string;
}

/// Whitelisted, writable subset of config.toml — see monitor's settings-page
/// plan for why jwt_secret/database_url are deliberately excluded. The push
/// channels have their own endpoint, for the reason card order does.
export interface SettingsPayload {
  interval_seconds: number;
  extended_interval_secs: number | null;
  idle_pause_enabled: boolean;
  idle_pause_threshold_secs: number | null;
  rules: MonitoringRule[];
  data_retention: DataRetentionConfig | null;
  cors_allowed_origins: string[];
}

/// GET response: the payload plus which of its own field names take effect
/// immediately vs. require a monitor restart
export interface SettingsView extends SettingsPayload {
  live_fields: string[];
  /// What `data_retention` becomes when an editor switches it on. `null` there
  /// means no cleanup runs at all rather than "the defaults apply", so the
  /// values have to come from somewhere — and from the agent rather than from
  /// a copy in each editor.
  data_retention_defaults: DataRetentionConfig;
}

/// Home-grid card order — kept out of SettingsPayload; see the dedicated
/// GET/PUT /api/v1/card-order handlers for why
export interface CardOrderPayload {
  card_order: string[];
}

/// One entry in a directory the agent serves, as `/fs/list` and `/fs/stat`
/// answer. Mirrors `EntryView` in `monitor/src/api/fs.rs`, which the app's
/// `FileEntry` is also defined against — the three have to agree.
export interface FsEntry {
  name: string;
  /// Matches the app's `FileKind`.
  kind: 'file' | 'dir' | 'link' | 'other';
  /// Null where the platform did not say, which reads as "no size" rather
  /// than as zero.
  size: number | null;
  /// Seconds since the epoch, as SFTP reports them.
  modified: number | null;
  /// Permission bits only, so `chmod` can take the value back unchanged.
  mode: number | null;
  /// Where a link points, unresolved. Null for anything else.
  link_target: string | null;
}

/// The directories the operator opened up. Everything outside them is denied,
/// so this is the whole of what the panel can browse.
export interface FsRootsResponse {
  roots: string[];
}
