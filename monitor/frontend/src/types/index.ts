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
  /// Whether `/api/v1/benchmark` will start a run for this caller.
  ///
  /// Its own field for `stream`'s reason, and reported the same way: a
  /// benchmark is 10–20 minutes of fio, iperf3 and a downloaded Geekbench, and
  /// an agent older than the endpoint answers `full_access` and would 404 the
  /// request.
  ///
  /// `false` on a platform yabs does not run on, whatever the grant. Reading
  /// the history is not covered by this field — it needs only the panel login,
  /// like `cron` — so the page says which of the two it is drawing.
  /// Served, not grantable: the benchmark endpoint is in this agent's route
  /// table. Whether a run can happen on this machine, and whether this caller
  /// may start one, are the listing's own `supported` and `editable`.
  benchmark?: boolean
  /// Whether `/api/v1/ai` answers this agent at all.
  ///
  /// Its own field for `stream`'s reason — an agent older than the endpoint
  /// answers `full_access` and would 404 the request — and reported the way
  /// `benchmark` is, as served rather than as granted. A conversation is a
  /// record of what this agent was asked and what it answered, so reading one
  /// needs only the panel login; asking it for something is `full_access`, and
  /// the listing says so as `editable` rather than withholding the tab.
  ai?: boolean
  /// Whether `/api/v1/snippets` answers this agent at all — the library is
  /// saved here, and both reading it and saving it need only the panel login.
  ///
  /// Served, not grantable: a snippet executes nothing. `/snippets/plan`
  /// returns a description of what a client should type and types none of it,
  /// and a snippet becomes usable only through a terminal, which is a session
  /// with credentials of its own. Absent on agents predating the endpoint.
  snippets?: boolean
  /// Whether `/api/v1/pve` answers this agent at all.
  ///
  /// Served, not grantable: the cluster's resource listing needs only the panel
  /// login, and a caller who may not act on a guest can still read the list and
  /// be told why. Saving the cluster's credential and acting on a guest are
  /// `full_access`, said as `editable` in each response rather than by
  /// withholding the tab. Absent on agents predating the endpoint.
  pve?: boolean
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

/// One yabs run's options.
///
/// Every phase is a choice, and the defaults here are the agent's — which are
/// not yabs' own: Geekbench is off because it downloads a proprietary binary and
/// **publishes the machine's specs** to a public `browser.geekbench.com` page,
/// reduced iperf is on because seven locations both ways is tens of gigabytes of
/// egress, and the IP lookup is off because it is plaintext HTTP to a third
/// party. See `BenchOptions` in `sbm_parser::bench`.
export interface BenchOptions {
  /// fio: four block sizes, ~30s each. Writes a 2 GB test file (512 MB on ARM)
  /// into the working directory, and needs that much free or yabs skips it.
  disk: boolean
  network: boolean
  /// Three iperf locations instead of seven.
  reduced_network: boolean
  /// Geekbench. Off by default — see this type's note.
  cpu: boolean
  /// `'v4' | 'v5' | 'v6' | 'v7'` — the digit is yabs' flag.
  geekbench_version: string
  ip_info: boolean
  /// Use the binaries yabs ships rather than the host's own fio and iperf3,
  /// which means fetching them from raw.githubusercontent.com.
  prefer_precompiled_binaries: boolean
  /// Empty means the invoking account's home directory.
  work_dir: string
}

/// What a set of options is going to cost, as the agent computes it.
///
/// Shown before the run starts because all three are invisible at the moment the
/// decision is made: a disk test that takes three minutes is a surprise on a
/// page with a spinner, and an iperf run is tens of gigabytes on a plan paid for
/// by the gigabyte.
export interface BenchEstimate {
  /// Whole minutes, rounded up, and deliberately labelled "about".
  minutes: number
  traffic_bytes: number
  /// Free space the disk phase needs, or `null` when it is not running.
  required_free_bytes: number | null
  /// Whether the options ask for anything at all — everything off still
  /// collects the system information header.
  system_info_only: boolean
}

/// One run in the history.
export interface BenchRun {
  id: string
  started_at: string
  finished_at: string | null
  /// `'running' | 'completed' | 'failed' | 'cancelled'`.
  status: string
  /// What produced this result, as the options were recorded.
  options: Partial<BenchOptions>
  /// Where the run happens on the machine, stored rather than re-derived.
  run_dir: string
  exit_code: number | null
  /// Why a run that ended badly ended badly, as a stable code this page
  /// phrases. Empty when the run is going, and for every run that ended well.
  error: BenchRunErrorCode | ''
  /// Whether a result and a log are stored on this row, so opening it is worth
  /// a second request.
  has_result: boolean
}

/// The live state of the run that is going, as of the request that carried it.
///
/// Polled rather than pushed: the agent's own resident poller is what carries a
/// run to a terminal state, and this is the same state read for a page.
export interface BenchLive {
  id: string
  /// Whether this is an answer at all. **False means ask again** — an agent that
  /// hit its own timeout answers an empty body, and reading that as "the run is
  /// gone" fails a benchmark that is running perfectly well.
  answered: boolean
  /// The answer was too large to read in one piece, so the log below is not the
  /// whole of it.
  truncated: boolean
  /// Whether the launcher's process is still there. Needed beside `exit_code`:
  /// a run killed by the OOM killer leaves neither an exit file nor a process,
  /// and only the pair tells that apart from a run in its first second.
  alive: boolean
  dir_exists: boolean
  exit_code: number | null
  /// The end of the log — what the run has printed, which on a page is progress.
  log: string
  /// The run's process group, one process per line. Empty when the machine has
  /// no `ps` that took the flags.
  processes: string
  result_json: string | null
}

export interface BenchView {
  runs: BenchRun[]
  /// The run that is going, or absent when there is none.
  live?: BenchLive
  /// Whether this caller may start, stop or remove a run. A hint: every write
  /// re-checks the grant at the moment of use.
  editable: boolean
  /// Whether a benchmark can run on this machine at all.
  supported: boolean
}

/// One run in full: the row, plus the two large columns.
export interface BenchDetail extends BenchRun {
  /// yabs' `-w` output, verbatim **as a string**.
  ///
  /// Not parsed here on purpose: yabs assembles it with `+=` on a shell string,
  /// so a field it could not collect arrives as an empty slot and a distro name
  /// containing a quote produces a document no parser accepts. A result that
  /// will not parse is drawn as the text it is rather than as nothing.
  result_json: string | null
  log: string
}

/// Why a benchmark request was refused, as a stable code the page phrases.
///
/// One list, all of them about the request or about this machine rather than
/// about the run: a platform yabs does not run on, a working directory too long
/// to be a path, a run already going.
export type BenchRefusalCode =
  | 'already_running'
  | 'unsupported_platform'
  | 'work_dir_too_long'
  | 'no_home_directory'
  | 'asset_unreadable'
  | 'no_entropy'
  | 'script_not_writable'
  | 'start_failed'
  | 'history_unavailable'
  | 'no_such_run'
  | 'run_in_progress'

/// Why a run that ended badly ended badly, as a stable code the page phrases.
///
/// A second list rather than more [`BenchRefusalCode`]s: these describe a run
/// that is in the history rather than a request this page just made, and every
/// one of them is drawn beside a row rather than as an error over the page.
export type BenchRunErrorCode = 'launcher_failed' | 'nonzero_exit' | 'no_exit_code'

// ------------------------------------------------------------------- the Agent

/// What an item of a conversation is.
///
/// The wire spells these, and `turn::Item`'s builders are the only writers: a
/// message is what the user typed or the model answered, a `function_call` is a
/// proposal, a `function_output` is what came of one — the tool's envelope, or
/// this agent saying a person declined it — and a `notice` is the agent saying
/// why a turn stopped, which the model never sees.
export type AiItemKind = 'message' | 'function_call' | 'function_output' | 'notice'

/// What the classifier could establish about a command, from its text alone.
///
/// `sbm_parser::ai_risk::CommandRisk`'s own spellings. `unknown` is the
/// default: anything the classifier does not recognise is asked about.
export type AiRisk = 'read_only' | 'unknown' | 'caution' | 'destructive'

/// The phase a running turn is in. `idle` covers both "parked" and "over",
/// which are told apart by the items rather than here.
export type AiPhase = 'idle' | 'streaming' | 'executing'

/// One item of a conversation, in order.
export interface AiItemView {
  ordinal: number
  created_at: string
  kind: AiItemKind
  /// `user` or `assistant` for a message, empty for every other kind.
  role: string
  content: string
  /// The model's own thinking, when the endpoint reported any. Kept beside the
  /// answer rather than mixed into it.
  reasoning: string
  /// The call an item is about: the proposal on a `function_call`, the answer
  /// on a `function_output`. `null` on a message and a notice.
  call_id: string | null
  tool: string | null
  /// The model's JSON **as the text it produced**, never a re-serialisation of
  /// the fields parsed out of it: the same bytes the tool was handed and the
  /// same bytes a reviewer reads. A page that draws one field parses for
  /// display; nothing it sends back is built from the parse.
  arguments: string | null
  /// What the classifier decided when the call was created — what the reviewer
  /// was shown, and what decided whether it ran unreviewed.
  risk: AiRisk | null
}

/// A conversation as the list draws it.
export interface AiConversationView {
  id: string
  title: string
  model: string
  created_at: string
  updated_at: string
  prompt_tokens: number
  completion_tokens: number
  /// A call nobody has answered yet — what the row shows instead of a status.
  awaiting_review: boolean
  /// A turn is running in this conversation right now.
  running: boolean
}

export interface AiListView {
  conversations: AiConversationView[]
  /// Whether this caller may send, approve, decline, rename, remove and save
  /// the settings. A hint: every action re-checks the grant at the moment of
  /// use, and `stop` is answered without it.
  editable: boolean
}

/// The text a running step has produced so far, which is not an item yet.
export interface AiLiveView {
  /// The ordinal this text will become an item with, so a page drops its
  /// provisional text exactly when the item supersedes it. `null` once the step
  /// has been stored — the text is an item now.
  step: number | null
  content: string
  reasoning: string
  phase: AiPhase
  /// Why the last turn ended badly, as a stable code this page phrases.
  error: AiStopCode | null
}

export interface AiDetailView {
  conversation: AiConversationView
  items: AiItemView[]
  /// What is streaming right now, if anything.
  live: AiLiveView | null
  /// The calls this conversation is waiting on. The same list the follow
  /// stream's `state` frame carries.
  waiting: string[]
  editable: boolean
}

/// One frame of the follow stream, as NDJSON.
///
/// `item` is what was stored after the caller's `?after=`; `delta` is text that
/// is not an item yet; `state` arrives when any of `running`/`phase`/`error`/
/// `waiting` changes, and once at the start; `ping` keeps a proxy from closing
/// an idle stream and carries nothing.
export type AiFollowFrame =
  | { type: 'item'; item: AiItemView }
  | { type: 'delta'; step: number; content: string; reasoning: string }
  | {
      type: 'state'
      running: boolean
      phase: AiPhase
      error: AiStopCode | null
      waiting: string[]
    }
  | { type: 'ping' }

/// The endpoint's own settings, which the page edits.
export interface AiSettingsView {
  /// An endpoint and a model — what a page checks before offering to send.
  configured: boolean
  base_url: string
  model: string
  /// Always `null`. The key is write-only: this field exists so a page
  /// round-tripping this view hands back a `null` that means "keep what is
  /// stored" rather than omitting a field it never saw.
  api_key: null
  /// Whether one is stored — the one bit that separates "leave this blank to
  /// keep it" from "there is none".
  api_key_set: boolean
  auto_run_safe_commands: boolean
  editable: boolean
}

/// The whole payload of a settings save. A replace: a field left out is
/// cleared, so the page always sends every one it drew.
export interface AiSettingsPayload {
  base_url: string
  model: string
  /// `null` keeps the stored key, `''` clears it, anything else replaces it.
  api_key: string | null
  auto_run_safe_commands: boolean
}

/// One action on the Agent endpoint, as the tagged object the route takes.
///
/// A tagged object rather than five routes, so an action this build does not
/// know is refused while it is being read rather than reaching a handler.
export type AiActionRequest =
  | { action: 'chat'; conversation?: string; message: string }
  | { action: 'approve'; conversation: string; call_id: string }
  | { action: 'decline'; conversation: string }
  | { action: 'stop'; conversation: string }
  | { action: 'rename'; conversation: string; title: string }

/// What an action did, from `POST /api/v1/ai/conversations`.
export interface AiActResponse {
  /// The conversation the action applied to. For a message that started one,
  /// the id it was created with.
  conversation: string
  /// Whether a turn is running now: a `stop` that found nothing, and an
  /// approval that answered the last call of a batch and resumed, both answer
  /// here.
  running: boolean
  /// What an approval ran, for a page that would rather say so than wait for
  /// the model to answer.
  result?: { ok: boolean; summary: string }
}

/// Why a request was refused, as a stable code this page phrases.
///
/// Every one of them is something the caller could have avoided, which is why
/// they are 400s; `no_such_conversation` and `no_such_call` are a state of the
/// agent rather than a mistake, and arrive 404.
export type AiRefusalCode =
  | 'invalid_base_url'
  | 'empty_message'
  | 'message_too_long'
  | 'invalid_title'
  | 'not_configured'
  | 'busy'
  | 'nothing_to_decline'
  | 'no_such_conversation'
  | 'no_such_call'

/// Why a turn stopped, as a code this page phrases in the viewer's language.
///
/// Two vocabularies in one, because both are drawn in the same place: `turn.rs`'s
/// own — `interrupted` for a stopped turn, `storage` for a write that failed,
/// `not_configured` for an endpoint removed under a running turn, `declined`
/// for one nobody would approve — and `openai::UpstreamError`'s names, which say
/// what the model's endpoint did.
///
/// `declined` and `interrupted` arrive as a notice item rather than as a live
/// error: the turn they end is over, and a notice is what a page draws for that.
export type AiStopCode =
  | 'interrupted'
  | 'storage'
  | 'not_configured'
  | 'unreachable'
  | 'auth'
  | 'not_found'
  | 'rejected'
  | 'rate_limited'
  | 'unavailable'
  | 'shape'
  | 'declined'

/// A script the operator saved to run again, with `${…}` macros filled in at
/// the moment it runs.
///
/// The library lives on the agent rather than in this browser: a snippet is a
/// record of what to run on *that* machine, and `localStorage` is lost with the
/// browser profile and invisible from a second one.
export interface Snippet {
  /// Minted by this client. The agent stores what it is sent and refuses a set
  /// with a missing or repeated id rather than inventing one — a rename must
  /// not be how a snippet changes identity.
  id: string
  name: string
  /// As written, `${…}` included. Expanded when it runs, never on save.
  script: string
  note: string
  tags: string[]
}

export interface SnippetsView {
  snippets: Snippet[]
}

/// One thing a terminal must be fed, in order.
///
/// The shape is `sbm_parser::snippet::Step`'s own, and it is the whole reason
/// the expansion lives on the agent: what `${ctrl+c}` means is one definition
/// in Rust, and both clients run the steps it returns rather than reading the
/// script themselves.
export type SnippetStep =
  /// Type this, exactly.
  | { type: 'text'; text: string }
  /// The first character with the modifier held, then `rest`.
  | { type: 'combo'; ctrl: boolean; alt: boolean; key: string; rest: string }
  | { type: 'sleep'; seconds: number }
  /// Press Enter this many times. Never 0.
  | { type: 'enter'; times: number }

export interface SnippetPlan {
  steps: SnippetStep[]
}

/// Why a script could not be expanded, as a stable code this page phrases.
///
/// `key` is the placeholder the caller could not answer — the code alone would
/// not say which, and the fix is to answer that one.
export interface SnippetPlanRefusal {
  error: 'unanswerable'
  key: string
}

/// Why a library could not be stored, as a stable code this page phrases.
///
/// `index` is a position in the set that was *sent*, which is the list the page
/// still has on screen.
export type SnippetRefusalCode =
  | 'invalidId'
  | 'duplicateId'
  | 'invalidName'
  | 'duplicateName'
  | 'invalidTag'
  | 'duplicateTag'

/// One resource in a Proxmox cluster, as `sbm_parser::pve` parsed it.
///
/// PVE's own names and its own units, passed through unchanged: `mem`,
/// `maxmem`, `disk` and `maxdisk` are bytes, and `cpu` is a 0.0–1.0 fraction
/// (of the node for a node, of one core for a guest) — a page that showed
/// `0.054` as a percentage would be off by a hundred. Which fields are present
/// follows `type`, so this is one interface with the optional ones named rather
/// than a union the page has to narrow at every read.
export interface PveResource {
  /// PVE's own discriminator, and what the row is drawn as.
  type: PveKind
  /// PVE's identity for the resource, e.g. `qemu/101` or `storage/pve/local`.
  id: string
  /// The node the resource belongs to. A guest runs on it; a storage is
  /// mounted on it.
  node: string
  /// PVE's own word: `online`/`offline` for a node, `running`/`stopped` for a
  /// guest, `available` for a storage, `ok` for an SDN zone.
  status: string
  uptime?: number
  mem?: number
  maxmem?: number
  cpu?: number
  maxcpu?: number
  disk?: number
  maxdisk?: number
  /// A guest's id. Absent on everything that is not a guest.
  vmid?: number
  /// A guest's name, empty for one that was never named — the page falls back
  /// to the vmid, which is the other thing an operator knows it by.
  name?: string
  /// A storage's name, which is also part of its `id`.
  storage?: string
  /// A storage's plugin, e.g. `dir` or `zfspool`.
  plugintype?: string
  /// A storage's content types, comma-separated and sorted by the agent.
  content?: string
  /// A storage's `shared` flag, as PVE's own 0/1.
  shared?: number
  /// An SDN zone's name.
  sdn?: string
}

export type PveKind = 'node' | 'qemu' | 'lxc' | 'storage' | 'sdn'

/// The two kinds of guest PVE manages, and the only two `/pve/control` acts on.
export type PveGuestKind = 'qemu' | 'lxc'

/// What may be asked of a guest. `shutdown` asks the guest's own OS to stop,
/// `stop` pulls the plug, `reboot` restarts and `start` boots.
export type PveAction = 'start' | 'stop' | 'shutdown' | 'reboot'

/// The cluster's resources, and whether this caller may act on them.
export interface PveResourcesView {
  /// PVE's own release string, when it gave one. Absent rather than an error:
  /// a label is not worth failing a listing over.
  release?: string
  /// Sorted by the agent, so two refreshes of one page show the same rows in
  /// the same places whatever order the cluster answered in.
  resources: PveResource[]
  editable: boolean
}

/// Which credential the agent dials the cluster with.
///
/// `password` is a ticket from `/access/ticket`, which is what PVE's own web UI
/// does and what an account with two-factor authentication cannot use from
/// here. `token` is `PVEAPIToken=…`, PVE's documented credential for
/// automation, and the way through an account that owes a second factor.
export type PveAuthKind = 'password' | 'token'

/// The cluster's stored configuration, as the agent reports it.
export interface PveSettingsView {
  /// Somewhere to send a request and an account to send it as. What the page
  /// checks before offering the listing.
  configured: boolean
  url: string
  auth: PveAuthKind
  /// The account, without the realm: `root` for `root@pam`.
  username: string
  /// The realm, e.g. `pam` or `pve`.
  realm: string
  /// The API token's id — the `automation` in `root@pam!automation`. Not a
  /// secret, and the part of a token credential a page has to show.
  token_id: string
  /// Always `null`. The credential is write-only: this field exists so that a
  /// page round-tripping this view hands back a `null` that means "keep what is
  /// stored" rather than omitting a field it never saw.
  secret: string | null
  /// Whether one is held. The one bit that separates "leave this blank to keep
  /// it" from "there is none".
  secret_set: boolean
  /// Accept a certificate this agent cannot verify. A PVE install answers on
  /// its own certificate unless the operator has done PKI for a machine they
  /// already trust, so this is on for most installs.
  ignore_cert: boolean
  /// Whether this caller may save.
  editable: boolean
}

/// The whole section, as a save sends it. A `PUT` replaces what it names, so
/// every field is here; `secret` is the exception the convention allows.
export interface PveSettingsPayload {
  url: string
  auth: PveAuthKind
  username: string
  realm: string
  token_id: string
  /// `null` keeps what is stored, `""` clears it, anything else replaces it —
  /// the same one-field rule the notification channels use.
  secret: string | null
  ignore_cert: boolean
}

/// One action on one guest.
export interface PveControlRequest {
  node: string
  kind: PveGuestKind
  vmid: number
  action: PveAction
}

export interface PveControlResult {
  /// PVE's task id for the change, when it gave one. A page may show it and
  /// nothing depends on it.
  upid?: string
}

/// Why a PVE request was refused, as a stable code this page phrases.
///
/// The first group is about the request or the stored configuration — the
/// caller can act on all of them. The second is what the cluster answered; they
/// are the agent's codes rather than its status, since a page's client logs the
/// operator out on a 401 and PVE answering one is the *agent's* credential
/// failing, not this session.
export type PveRefusalCode =
  | 'notConfigured'
  | 'invalidUrl'
  | 'missingUsername'
  | 'missingRealm'
  | 'missingTokenId'
  | 'invalidAuth'
  | 'invalidKind'
  | 'invalidAction'
  | 'invalidNode'
  | 'invalidVmid'
  | 'unreachable'
  | 'loginFailed'
  | 'needTfa'
  | 'forbidden'
  | 'invalidResponse'
  | 'upstream'
