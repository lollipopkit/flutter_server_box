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
  /// Whether `/api/v1/cron` answers this agent at all — its own field for the
  /// same reason, but reporting that the endpoint is *served* rather than that
  /// this caller may write to it. Reading the schedule needs only the panel
  /// login, so what the caller may change is `editable` in the response body.
  cron?: boolean
  /// Whether `/api/v1/containers` answers this agent at all. Reported the same
  /// way as `cron`, and for the same reason: listing containers runs the
  /// runtime as the agent's own user.
  containers?: boolean
  /// Whether `/api/v1/process` answers this agent at all. Reported the same way
  /// as `cron`: `ps` shows the agent's own user the table `top` would show it,
  /// and signalling a process is `editable` in the response body.
  process?: boolean
  /// Whether `/api/v1/services` answers this agent at all. Reported the same
  /// way as the two above: the listing commands run as the agent's own user,
  /// and acting on a unit is `editable` in the response body.
  services?: boolean
  /// Whether `/api/v1/users` answers this agent at all. Reported the same way:
  /// the catalog is read as the agent's own user, and writing an account is
  /// `editable` in the response body. Linux only in practice — the page draws
  /// the platform answer rather than being hidden, since an agent on a
  /// supported platform is the ordinary case and a hidden tab says nothing.
  users?: boolean
  /// Whether `/api/v1/desktop` answers this agent at all — a saved route list
  /// needs only the panel login.
  ///
  /// **Not whether a session may be opened**, which is `stream` and is checked
  /// again when the socket opens: a route list is a list, and what a route is
  /// worth is decided by the relay. An agent that predates this endpoint
  /// answers `full_access` and would 404 the request, which is why it is not
  /// reported as the wider grant.
  desktop?: boolean
  /// Whether `/api/v1/stream/ws` will relay a TCP connection from this agent,
  /// which is what opening a desktop session needs.
  ///
  /// The same grant as `full_access` — the relay dials as the agent's own user,
  /// so anyone who could open a shell could `ssh -L` from it — but its own
  /// field, because an agent older than the relay answers `full_access` and
  /// would still refuse the upgrade. Absent means no.
  stream?: boolean
  /// Whether `/api/v1/rdp/ws` answers this agent at all, which is what opening
  /// an RDP route needs.
  ///
  /// Its own field on the agent's side for the same reason as `stream`, and
  /// separate from it because the two endpoints are separate: `stream` relays
  /// bytes and understands nothing, while the RDP endpoint terminates the TLS
  /// session with the RDP server and hands the operator a plaintext stream. An
  /// agent may serve one and not the other. VNC needs `stream` alone.
  rdp?: boolean
}

/// One job in the account's crontab, with its schedule already expanded.
///
/// The expansion is done on the server, against the server's own clock: cron
/// matches an expression against the machine's wall time, so a client that
/// interpreted it in the viewer's timezone would name a time the job does not
/// run at.
export interface CronJobView {
  /// Index into the listing the client was given. This is what an edit
  /// addresses, and the agent re-reads the file at write time — an index that
  /// no longer names a job is refused rather than applied to whatever moved
  /// into its place.
  line_index: number
  schedule: string
  command: string
  /// Whether the job runs. A disabled job is a commented-out line on disk; the
  /// spelling is the agent's, which is why a client never writes the text back.
  enabled: boolean
  /// Whether the schedule is one this app reads. `false` means the fields
  /// below are empty, and the expression is shown as written.
  parsed: boolean
  is_reboot: boolean
  minutes: number[]
  hours: number[]
  days_of_month: number[]
  months: number[]
  days_of_week: number[]
  /// Whether the day fields actually narrow the schedule. A `*` there means
  /// "every", which is not the same as a list that happens to cover everything —
  /// cron's day-of-month/day-of-week rule is an OR, and an OR of two
  /// unrestricted fields is every day.
  day_of_month_restricted: boolean
  day_of_week_restricted: boolean
  /// The server's own wall clock, `YYYY-MM-DDTHH:MM`. Null when the schedule
  /// has no next run within the search window, or when the machine could not
  /// report its UTC offset (an old agent, or a `date` without `%z`) — in which
  /// case the schedule still lists and only the next run is unplaceable.
  next_run: string | null
}

/// Why a crontab could not be read, as its own word so the panel phrases it in
/// its own language. `null` alongside `available: false` means the machine said
/// something this agent does not classify, and `reason` is that text.
export type CronReason = 'not_installed' | 'unsupported_platform' | 'unreadable'

export interface CronView {
  /// Whether the crontab could be read at all. `false` is a state of the
  /// machine — no `crontab(1)`, a platform that has none — not a failure of the
  /// caller, so it is a field and the page has one shape to draw either way.
  available: boolean
  reason_kind: CronReason | null
  /// What the machine said, verbatim. Never translated: it is the only thing
  /// that distinguishes one failure from another.
  reason: string | null
  /// The account whose crontab this is, as the machine named it.
  user: string | null
  /// The agent machine's wall clock when it was read, `YYYY-MM-DDTHH:MM`.
  now: string | null
  jobs: CronJobView[]
  /// Comments, environment assignments and anything else that is not a job.
  /// Shown so a crontab another tool manages does not look like it lost them.
  preserved: string[]
  /// Whether this panel may change the schedule. A hint for the UI; the agent
  /// re-checks it on every write.
  editable: boolean
}

/// One change to one line.
///
/// An operation rather than a whole document: a client that round-tripped the
/// text would be the thing that decides how a disabled line is spelled, and a
/// client that got it slightly wrong would rewrite a file it does not own.
export type CronEdit =
  | { op: 'upsert'; line_index: number | null; schedule: string; command: string; enabled: boolean }
  | { op: 'remove'; line_index: number }
  | { op: 'set_enabled'; line_index: number; enabled: boolean }

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

/// What a single-use ticket authorises. One purpose per endpoint it can be
/// spent on, and the agent refuses a ticket at the wrong one — a ticket is
/// minted only when the endpoint it names is available to this caller.
export type WsTicketPurpose = 'terminal' | 'stream' | 'rdp'

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

/// A normalised container state, from either runtime's own words.
export type ContainerStatus =
  | 'running'
  | 'exited'
  | 'created'
  | 'paused'
  | 'restarting'
  | 'removing'
  | 'dead'
  | 'unknown'

/// Which runtime answered. Its name is also the command it is asked under.
export type ContainerType = 'docker' | 'podman'

/// One sample of a running container's resource use.
///
/// Every field is the runtime's own rendering of a quantity, kept as text
/// because both runtimes print two quantities in one field (`1.2MiB / 7.6GiB`)
/// and neither is a number this side can recompute. The pair is split so the
/// row can lay it out; nothing here is a sentence, so nothing here is
/// translated.
export interface ContainerStats {
  cpu: string | null
  /// Podman's average over the sample window. Docker reports none.
  cpu_avg: string | null
  mem: string | null
  net_down: string | null
  net_up: string | null
  disk_read: string | null
  disk_write: string | null
}

/// Which action, without which container.
export type ContainerActionKind =
  | 'start'
  | 'stop'
  | 'restart'
  | 'remove'
  | 'logs'
  | 'terminal'

export interface ContainerRow {
  id: string | null
  name: string | null
  image: string | null
  /// The compose project this container belongs to. Also what the list is
  /// grouped by.
  project: string | null
  working_dir: string | null
  /// Published ports condensed to `host→container`. Null when there are none.
  ports: string | null
  /// The runtime's own lifecycle text, verbatim.
  raw_status: string | null
  status: ContainerStatus
  /// Absent for a container that is not running, and for one the runtime did
  /// not answer for.
  stats: ContainerStats | null
  /// Which actions this container's state is offered under. Sent by the agent
  /// rather than derived here: whether an unrecognised state groups with a
  /// stopped one is a rule, and a second implementation of it would drift.
  actions: ContainerActionKind[]
}

export interface ContainerImage {
  /// Always present: a runtime that names no repository has `<none>`.
  repository: string
  tag: string | null
  id: string | null
  digest: string | null
  size: string | null
  /// How many containers use this image. `null` is *unknown*, never zero:
  /// reading Docker's `N/A` as zero is how a prune comes to offer an image
  /// that is in use.
  containers: number | null
  /// The runtime's own creation text: absolute on current Docker, relative on
  /// older ones and on Podman.
  created_at: string | null
  /// Podman's creation time in Unix seconds.
  created: number | null
}

export interface ContainerDiskUsage {
  image_count: number | null
  /// Summed over every type the runtime reported — images, stopped containers,
  /// unused volumes, build cache — because that is what the prune actions
  /// between them reclaim.
  reclaimable_bytes: number | null
}

/// Which of the four things the panel asked for. One route for all of them.
export type ContainerPart = 'containers' | 'images' | 'usage' | 'logs'

/// Why the runtime could not answer, as its own word so the panel phrases it
/// in its own language. `null` alongside `available: false` means the machine
/// said something this agent does not classify, and `reason` is that text.
export type ContainerReason =
  | 'not_installed'
  | 'unsupported_platform'
  | 'permission_denied'
  | 'unreadable'

export interface ContainerRuntime {
  kind: ContainerType
  /// The *client's* version, or null when the machine did not report one: it
  /// is the client that reads the socket, so it is the client's version that
  /// decides how a stats row is shaped.
  version: string | null
}

export interface ContainerView {
  part: ContainerPart
  /// Whether the machine has a runtime this agent could talk to. `false` is a
  /// state of the machine, not a failure of the caller, so the page has one
  /// shape to draw either way.
  available: boolean
  reason_kind: ContainerReason | null
  /// What the machine said, verbatim. Never translated: it is the only thing
  /// that distinguishes one failure from another.
  reason: string | null
  runtime: ContainerRuntime | null
  /// Whether this panel may change anything. A hint for the UI; the agent
  /// re-checks it on every write.
  editable: boolean
  containers: ContainerRow[]
  images: ContainerImage[]
  usage: ContainerDiskUsage | null
  /// The container's log, for `part: 'logs'`.
  logs: string | null
}

/// One change to one container.
///
/// An action rather than a command line: the agent composes the command, so a
/// build that does not implement an action refuses it while deserializing
/// instead of reaching a shell.
export type ContainerAction =
  | { action: 'start'; id: string }
  | { action: 'stop'; id: string }
  | { action: 'restart'; id: string }
  | { action: 'remove'; id: string; force: boolean }
  | { action: 'prune_containers' }
  | { action: 'prune_volumes' }

/// What a change answered: the listing as it now stands, plus how the command
/// went.
export interface ContainerActionResult extends ContainerView {
  exit_code: number | null
  /// What the runtime printed, with the agent's own scaffolding dropped out of
  /// it. Empty when the action succeeded quietly.
  output: string
}

/// How the process table may be ordered. The set the agent answers — `sorts` in
/// the response — is a property of the columns the machine printed, so a mode
/// absent there is one this table cannot answer.
export type ProcessSortMode = 'cpu' | 'mem' | 'rss' | 'read' | 'write' | 'pid' | 'user' | 'name'

/// What may be sent to a process. Windows has the one stop there is, BSD none
/// at all — `signals` in the response is the list, and empty means no stop is
/// offered.
export type ProcessSignal = 'term' | 'kill'

/// What happened to a signal.
///
/// Told apart from the exit status because the caller's next move differs for
/// each: `denied` is a process this account does not own, which is what the
/// retry as root is for; `target_changed` is a table that has moved on.
export type ProcessKillOutcome = 'succeeded' | 'target_changed' | 'denied' | 'failed'

/// Which of the machine's columns carried a value, which is what the page
/// draws and what decides which orders are available.
export interface ProcessColumns {
  user: boolean
  cpu: boolean
  mem: boolean
  rss: boolean
  read: boolean
  write: boolean
  read_speed: boolean
  write_speed: boolean
}

/// One process, as the agent read it from the machine.
export interface ProcRow {
  user: string | null
  pid: number
  ppid: number | null
  cpu: number | null
  mem: number | null
  vsz: string | null
  rss: string | null
  tty: string | null
  stat: string | null
  nice: number | null
  threads: number | null
  start: string | null
  /// The identity a stop is checked against: a PID the kernel has since handed
  /// to something else is refused rather than signalled.
  start_id: string | null
  time: string | null
  elapsed_seconds: number | null
  read_bytes: number | null
  write_bytes: number | null
  /// Bytes a second since the previous reading. `null` where there is nothing
  /// to difference against, which is every first reading.
  read_speed: number | null
  write_speed: number | null
  /// The whole command line as printed.
  command: string
  process_name: string | null
  /// What to call this process where the command line does not fit. Sent by the
  /// agent rather than derived here: it is a rule, and a second implementation
  /// of it would drift.
  name: string
  /// `RSS` in KiB as a number — the column itself is a string because the two
  /// `ps` dialects print different things into it, and `-` is not zero.
  rss_kb: number | null
  /// Whether this row is `kthreadd` or one of its children. Hidden by default:
  /// they are not something a user acts on, and there are dozens.
  is_kernel_thread: boolean
  /// Whether this row may be signalled at all — a PID whose start identity the
  /// machine did not report cannot be checked before the signal.
  killable: boolean
}

/// Why the machine gave no table.
export type ProcessReason = 'did_not_finish' | 'too_large' | 'empty'

/// One reading of the process table.
export interface ProcessView {
  /// Whether the machine gave a table at all. `false` is a state of the
  /// machine, not a failure of the caller.
  available: boolean
  reason_kind: ProcessReason | null
  /// What the machine said, verbatim. Never translated: it is the only thing
  /// that distinguishes one failure from another.
  reason: string | null
  /// Whether this panel may signal a process. A hint for the UI; the agent
  /// re-checks it on the signal itself.
  editable: boolean
  procs: ProcRow[]
  /// Rows the agent's parser had to drop. The rest of the table is still here.
  issue: { failure: string; diagnostics: string } | null
  load: { one: number; five: number; fifteen: number } | null
  /// The instant this reading was taken, in Unix milliseconds. Older than the
  /// request when the agent answered with the reading it already had.
  sampled_at_millis: number
  columns: ProcessColumns
  /// The orders this table can answer, in the order the page draws them.
  sorts: ProcessSortMode[]
  /// What this answer is ordered by, after the agent's fallbacks.
  sort: ProcessSortMode | null
  ascending: boolean | null
  signals: ProcessSignal[]
}

/// One signal to one process.
///
/// The password travels as its own field rather than inside a command, for the
/// reason `/power`'s does: a password in a command line lands in the machine's
/// process list and in the agent's audit row. Omitted unless the first attempt
/// came back `denied`.
export interface ProcessSignalRequest {
  pid: number
  /// The identity the listing gave this PID. Without it the agent refuses
  /// rather than signalling whatever holds the number now.
  start_id: string | null
  signal: ProcessSignal
  password?: string
}

export interface ProcessSignalResult {
  outcome: ProcessKillOutcome
  exit_code: number | null
  stdout: string
  stderr: string
  /// `sudo` refused the password that was sent. The one outcome the caller can
  /// act on, which is why it is a field rather than a status code.
  sudo_rejected: boolean
}

/// Which of the known service managers a machine runs. `null` where the
/// detector found one this agent cannot list — `detected_name` is then what it
/// found instead, in the machine's own words.
export type ServiceManagerType = 'systemd' | 'procd' | 'openrc'

/// What the machine said about its own init, for a page that has to explain a
/// machine it cannot list.
export interface ServiceManagerView {
  type: ServiceManagerType | null
  /// What the machine called it: `systemd`, `procd`, `launchd`, `init`.
  detected_name: string
  /// `systemd (Debian GNU/Linux)`, or the OS name alone.
  description: string
}

export type ServiceUnitType = 'service' | 'socket' | 'mount' | 'timer'

/// Whose unit it is. systemd's `--user` scope is the only second one that
/// exists, which is why the page only draws it where `supports_user_scope`.
export type ServiceScope = 'system' | 'user'

export type ServiceState = 'running' | 'stopped' | 'failed' | 'starting' | 'stopping' | 'unknown'

export type ServiceAction = 'start' | 'stop' | 'restart' | 'enable' | 'disable'

/// One unit, as the agent read it.
export interface ServiceUnit {
  /// What the page sends back to ask about this unit or to act on it. Derived
  /// by the agent so the listing and the two requests cannot spell it
  /// differently.
  key: string
  /// Without the type suffix: `sshd`, not `sshd.service`.
  name: string
  full_name: string
  type: ServiceUnitType
  scope: ServiceScope
  state: ServiceState
  description: string | null
  /// Startup registration. `null` where the manager cannot report it, which is
  /// not the same as "not registered".
  enabled: boolean | null
  /// The manager's own word for startup registration, which says more than
  /// `enabled` can: a `static` or `masked` unit cannot be enabled at all.
  /// Drawn verbatim rather than translated — it is the manager's vocabulary.
  unit_file_state: string | null
  /// The manager's finer state: `running`, `exited`, `dead`, `start-pre`.
  sub_state: string | null
  /// Why the last run ended, where the manager says: `exit-code`, `signal`,
  /// `timeout`.
  result: string | null
  /// The main process's exit status, present only where `result` is
  /// `exit-code`.
  exit_status: number | null
  memory_bytes: number | null
  /// When the unit entered its current state, in Unix milliseconds at the
  /// machine's own clock. See the agent's note on the clock shift.
  since_millis: number | null
  /// When a timer next fires, in Unix milliseconds.
  next_elapse_millis: number | null
  /// What may be done to it, derived by the agent from the state and the
  /// startup registration so that a page drawing its own set would be a second
  /// implementation of that rule.
  actions: ServiceAction[]
  /// `unit_file_state`, or `enabled`/`disabled` in the same words where the
  /// manager has no such state to report.
  startup: string | null
}

export type ServicePart = 'list' | 'logs' | 'definition' | 'status'

/// Why the machine gave no listing, as its own word so the page phrases it in
/// its own language. `null` alongside `available: false` means the machine
/// said something the agent does not classify, and `reason` is that text.
export type ServiceReason =
  | 'unsupported_manager'
  | 'unsupported_platform'
  | 'unreadable'
  | 'no_such_unit'
  | 'no_log'

/// A part of the listing that is missing while the rest of it is readable.
export type ServiceListingNotice = 'user_scope_unavailable' | 'details_unavailable'

export interface ServiceLogLine {
  /// The time as the manager printed it, already localised by `journalctl`.
  time: string | null
  text: string
}

export interface ServiceLog {
  lines: ServiceLogLine[]
  /// The log was read but not parsed — a format this agent does not know.
  /// Drawn as raw text rather than as an empty log.
  unreadable: boolean
}

/// One part of the machine's service state.
export interface ServiceView {
  part: ServicePart
  /// Whether this part could be read at all. `false` is a state of the machine
  /// — no manager this agent lists, no unit by that key — not a failure of the
  /// caller, so it is a field and the page has one shape to draw.
  available: boolean
  reason_kind: ServiceReason | null
  /// What the machine said, verbatim. Never translated: it is the only thing
  /// that distinguishes one failure from another.
  reason: string | null
  manager: ServiceManagerView | null
  /// Whether this panel may change a unit. A hint for the UI; the agent
  /// re-checks it on the action itself.
  editable: boolean
  /// Whether the machine has a second account scope at all.
  supports_user_scope: boolean
  units: ServiceUnit[]
  notice: ServiceListingNotice | null
  /// What the machine said about the notice, verbatim.
  detail: string | null
  /// The machine's own clock at the moment the listing was read.
  sampled_at_millis: number | null
  log: ServiceLog | null
  /// A unit's definition or the manager's own status, for `part: 'definition'`
  /// and `part: 'status'`.
  text: string | null
}

/// One action on one unit.
///
/// The password travels as its own field rather than inside a command, for the
/// reason `/power`'s does: a password in a command line lands in the machine's
/// process list and in the agent's audit row. Omitted until the first attempt
/// comes back `sudo_rejected`.
export interface ServiceActRequest {
  key: string
  action: ServiceAction
  password?: string
}

export interface ServiceActResult {
  /// Whether the manager's command exited zero. What the machine said about it
  /// is in `stderr`, and it is the only thing that distinguishes one failure
  /// from another.
  succeeded: boolean
  sudo_rejected: boolean
  exit_code: number | null
  stdout: string
  stderr: string
}

/// Whether an account can be logged into with a password.
///
/// `none` is an empty password field, which lets anyone in — a different thing
/// from `locked`, and the half that must not be drawn as the safe one.
export type UserPasswordState = 'set' | 'locked' | 'none'

/// Why the machine gave no catalog, as its own word so the page phrases it in
/// its own language. `null` alongside `available: false` means the machine said
/// something the agent does not classify, and `reason` is that text.
export type UserReason = 'unsupported_platform' | 'unreadable' | 'no_such_user'

/// One account, as the agent read it out of `/etc/passwd` and `/etc/group`.
export interface SystemUser {
  name: string
  uid: number
  gid: number
  /// The gecos field, whole: everything up to the first comma is conventionally
  /// the full name, and splitting it is a presentation decision.
  comment: string
  home: string
  shell: string
  primary_group: string | null
  /// Without the primary group, sorted. An empty list means it is in none.
  supplementary_groups: string[]
}

/// One account as the page draws it: the account, plus the flags the agent
/// derived so that no rule here is a second implementation of one.
export interface UserRow extends SystemUser {
  is_root: boolean
  /// Below the machine's own threshold, from [`UserView.uid_min`]. Not a
  /// constant: a distribution that sets 500 answers for itself.
  system: boolean
  /// The shell is `nologin` or `false`, so no password or key login. About the
  /// shell only — a locked password is `password_state` in the detail.
  login_disabled: boolean
  /// The account the agent itself runs as.
  agent_account: boolean
  /// Whether the agent would remove it: false for root and for its own account.
  /// Whether *this caller* may is `editable` in the response.
  deletable: boolean
}

/// What `/etc/shadow`, the account's `authorized_keys` and sudoers say.
///
/// Every field may be `null`, and `null` means "not readable from here" rather
/// than "absent": all three sources are root-only on a normal machine, and an
/// unprivileged session would otherwise report every account as having no
/// password and no keys.
export interface UserDetail {
  password_state: UserPasswordState | null
  /// Unix milliseconds. Shadow counts days, and the agent multiplies.
  password_changed_millis: number | null
  expires_millis: number | null
  /// Empty is the only thing that means never — an unreadable field is `null`
  /// above rather than `true` here.
  never_expires: boolean
  /// Distinct key types in file order. An empty list means the file was read
  /// and held none; `null` means it could not be read.
  ssh_key_types: string[] | null
  /// The right-hand side of the account's sudoers entry, e.g. `NOPASSWD: ALL`.
  sudo_rule: string | null
}

export type UserPart = 'list' | 'detail'

/// One part of the machine's accounts.
export interface UserView {
  part: UserPart
  /// Whether the accounts could be read. `false` is a state of the machine —
  /// not Linux, no readable catalog — not a failure of the caller, so it is a
  /// field and the page has one shape to draw.
  available: boolean
  reason_kind: UserReason | null
  /// What the machine said, verbatim. Never translated: it is the only thing
  /// that distinguishes one failure from another.
  reason: string | null
  /// Whether this panel may change an account. A hint for the UI; the agent
  /// re-checks it on the write itself.
  editable: boolean
  /// The account the agent runs as, and the one it will not remove. `null` when
  /// no catalog could be read.
  agent_account: string | null
  /// The uid below which this machine counts an account as a system one.
  uid_min: number | null
  users: UserRow[]
  /// The account a detail is about, echoed because a response is read beside a
  /// request that may be older.
  name: string | null
  detail: UserDetail | null
}

/// What a caller wants an account to be — the same fields for a new account and
/// for a change to one, because the two forms ask for the same things. An empty
/// `home` or `primary_group` is left alone (neither can be cleared); an empty
/// `comment` and an empty group list *are* the values and clear what was there.
export interface UserDraft {
  name: string
  comment: string
  home: string
  shell: string
  primary_group: string
  supplementary_groups: string[]
  /// Whether a new account gets a home directory.
  create_home: boolean
  /// Whether an existing home directory is moved when `home` changes.
  move_home: boolean
  /// A system account, with no aging and a uid below the machine's threshold.
  system: boolean
  /// The password to set, when the caller is setting one. Omitted or empty
  /// leaves the account's password alone. It travels inside the script the
  /// agent runs, never as a command-line argument.
  password?: string
}

export type UserAction = 'create' | 'edit' | 'delete'

/// One write, as the page describes it.
///
/// Two passwords may travel here and neither reaches a command line: the
/// account's own inside `draft`, and the `sudo` one as its own field — omitted
/// until the first attempt comes back `sudo_rejected`.
export interface UserActRequest {
  action: UserAction
  draft?: UserDraft
  /// Which account a change or a removal is about. The account as it is comes
  /// from a catalog the agent reads at the moment of the write.
  name?: string
  /// Whether a removal takes the home directory with it.
  remove_home?: boolean
  /// The `sudo` password, when the caller has one.
  password?: string
}

export interface UserActResult {
  succeeded: boolean
  sudo_rejected: boolean
  exit_code: number | null
  stdout: string
  stderr: string
}

/// Why a write was refused before it ran, as a stable code the page phrases.
/// A `UserError` case from the shared parser, or one of the endpoint's own:
/// `missingDraft`, `missingName`, `unsupportedPlatform`, `unreadable`,
/// `userExists`, `agentAccount`, `noSuchUser`.
export type UserRefusalCode =
  | 'invalidName'
  | 'lineBreak'
  | 'invalidPrimaryGroup'
  | 'invalidSupplementaryGroup'
  | 'passwordLineBreak'
  | 'renaming'
  | 'rootNotDeletable'
  | 'missingDraft'
  | 'missingName'
  | 'unsupportedPlatform'
  | 'unreadable'
  | 'userExists'
  | 'agentAccount'
  | 'noSuchUser'

/// Which protocol a saved route speaks.
///
/// The relay is a byte stream and does not translate between the two, so this
/// is what decides which client runs a session. Stored by name and never by
/// index: a `config.toml` outlives the build that wrote it.
export type DesktopProtocol = 'vnc' | 'rdp'

/// A protocol the agent offers, and the port a route of it is given when none
/// is named.
///
/// Sent by the agent rather than hard-coded here, so a protocol a later build
/// adds — or a default port it changes — reaches this panel without a change
/// of its own.
export interface DesktopProtocolView {
  id: DesktopProtocol
  default_port: number
}

/// One saved route to a desktop: a destination **the agent** can reach.
///
/// That is the whole reason it is stored on the agent rather than in this
/// browser: a desktop is usually reachable from the machine the agent runs on
/// and from nowhere the panel is, so the agent is the client's way in.
///
/// **No credential is in one.** The password a desktop asks for is typed in
/// this browser — the process that runs the session — and travels to the
/// desktop through the relay, so there is nothing here to withhold and the
/// listing is safe to read whole.
export interface DesktopTarget {
  /// Names the route and is its identity: unique across the set, which is why a
  /// route is edited by name rather than by position.
  name: string
  protocol: DesktopProtocol
  /// An address this agent can reach. `127.0.0.1` is the machine it runs on.
  host: string
  port: number
  username?: string | null
  /// The RDP domain, which Windows authentication may need. Kept for a VNC
  /// route too, so making one an RDP route cannot silently lose it.
  domain?: string | null
  /// Take the session view-only.
  view_only: boolean
  /// Whether the desktop may be shared with the sessions already on it.
  shared: boolean
}

/// The saved routes, and the protocols available for a new one.
export interface DesktopRoutesView {
  targets: DesktopTarget[]
  protocols: DesktopProtocolView[]
}

/// Why a route was refused before the file was written, as a stable code the
/// page phrases. One list, all of them about the request rather than about the
/// machine — a value too long to be a name, two routes answering to one name, a
/// host that is not one, a port no desktop listens on.
export type DesktopRefusalCode =
  | 'invalidName'
  | 'duplicateName'
  | 'invalidHost'
  | 'invalidPort'
  | 'invalidUsername'
  | 'invalidDomain'
