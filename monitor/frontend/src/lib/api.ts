import type {
  AgentUser,
  CardOrderPayload,
  Capabilities,
  CustomCmd,
  CustomCmdsView,
  FsEntry,
  FsRootsResponse,
  HistoryPoint,
  LoginRequest,
  LoginResponse,
  PushEntry,
  PushListView,
  PushPayload,
  PushTestResult,
  Role,
  SettingsPayload,
  SettingsView,
  StatusResponse,
  SystemMetrics,
  BenchDetail,
  BenchEstimate,
  BenchOptions,
  BenchRun,
  BenchView,
  ContainerAction,
  ContainerActionResult,
  ContainerPart,
  ContainerView,
  CronEdit,
  CronView,
  PowerAction,
  PowerResult,
  ProcessSignalRequest,
  ProcessSignalResult,
  ProcessSortMode,
  ProcessView,
  ServiceActRequest,
  ServiceActResult,
  ServicePart,
  ServiceView,
  WsTicketPurpose,
  WsTicketResponse,
  UserActRequest,
  UserActResult,
  UserPart,
  UserView,
  Snippet,
  SnippetPlan,
  SnippetsView,
  Desktop,
  BackupView,
  BmcCertInfo,
  BmcIntent,
  BmcList,
  BmcStatus,
  BmcTargetInput,
  PveConfigInput,
  PveConfigView,
  VirtConsoleAnswer,
  VirtConsoleKind,
  VirtError,
  VirtGuestDetail,
  VirtHistoryWindow,
  VirtLoad,
  VirtSnapDiff,
  VirtSnapshotOp,
  VirtSnapshots,
  VirtStats,
  VirtPowerAction,
  DesktopsView,
} from '../types'
import { isSecureAgentUrl } from './agentUrl'
import { servers, type ServerEntry } from './servers.svelte'

const TIMEOUT_MS = 10_000

/// For the machine-management endpoints, which run a command and answer when
/// it ends: the agent bounds that itself (`[remote_access.exec] timeout`,
/// a minute by default), so this only has to outlast it.
const MACHINE_TIMEOUT_MS = 120_000

export class ApiError extends Error {
  /// HTTP status, when the request got far enough to have one. Absent for a
  /// failure to reach the agent at all — a distinction callers that retry
  /// need, since "refused" and "unreachable" deserve opposite responses.
  readonly status?: number

  /// The agent's stable error code, where the endpoint gives one (the account
  /// and role endpoints: `reauth`, `last_admin`, ...). Absent for the older
  /// endpoints, whose `error` is the message itself.
  readonly code?: string

  /// The error body as the agent sent it, for a refusal that names more than
  /// a code (`/snippets`' `index`, `/snippets/plan`'s `key`).
  readonly body?: Record<string, unknown>

  constructor(message: string, status?: number, code?: string, body?: Record<string, unknown>) {
    super(message)
    this.status = status
    this.code = code
    this.body = body
  }
}

/// An error response as an `ApiError`.
///
/// Two shapes: the older endpoints answer `{"error": "<message>"}`, the
/// account and role ones `{"error": "<code>", "message": "..."}`. A body with
/// a `message` is the second, and its `error` is the code.
async function errorFrom(res: Response, fallback: string): Promise<ApiError> {
  try {
    const body = (await res.json()) as { error?: string; message?: string } & Record<string, unknown>
    if (body.message) return new ApiError(body.message, res.status, body.error, body)
    if (body.error) return new ApiError(body.error, res.status, undefined, body)
  } catch {
    // Non-JSON error body: keep the fallback message
  }
  return new ApiError(fallback, res.status)
}

function requestSignal(signal?: AbortSignal, timeoutMs = TIMEOUT_MS): AbortSignal {
  const timeout = AbortSignal.timeout(timeoutMs)
  return signal ? AbortSignal.any([signal, timeout]) : timeout
}

function requireSecureUrl(url: string) {
  if (!isSecureAgentUrl(url)) {
    throw new ApiError('Remote monitor agents require HTTPS; HTTP is allowed only on loopback.')
  }
}

async function request<T>(
  path: string,
  init: RequestInit = {},
  fallback = 'Request failed',
  signal?: AbortSignal,
  timeoutMs = TIMEOUT_MS,
): Promise<T> {
  const server = servers.current ? { ...servers.current } : undefined
  requireSecureUrl(server?.url ?? '')
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (server?.token) headers.Authorization = `Bearer ${server.token}`

  let res: Response
  try {
    res = await fetch(`${server?.url ?? ''}/api/v1${path}`, {
      ...init,
      headers,
      signal: requestSignal(signal, timeoutMs),
    })
  } catch {
    throw new ApiError(fallback)
  }

  if (res.status === 401 && path !== '/login') {
    // Expired/invalid token: drop this server's session, App falls back to login
    if (server) servers.logout(server.id, server)
    throw new ApiError('Session expired', 401)
  }
  if (!res.ok) throw await errorFrom(res, fallback)
  // `204 No Content` (a password changed, an account deleted) has no body to
  // parse.
  if (res.status === 204) return undefined as T
  return res.json() as Promise<T>
}

/// A request that carries bytes rather than JSON.
///
/// Separate from `request` for two reasons: the body is a stream in one
/// direction or the other and never `res.json()`, and `TIMEOUT_MS` is wrong
/// for it — ten seconds is generous for a status poll and nothing at all for a
/// file. Bounded by the caller's own `signal` instead, which is also what a
/// cancel button pulls.
async function fsBytes(
  path: string,
  init: RequestInit,
  fallback: string,
  signal?: AbortSignal,
): Promise<Response> {
  const server = servers.current ? { ...servers.current } : undefined
  requireSecureUrl(server?.url ?? '')
  const headers: Record<string, string> = { ...(init.headers as Record<string, string> | undefined) }
  if (server?.token) headers.Authorization = `Bearer ${server.token}`

  let res: Response
  try {
    res = await fetch(`${server?.url ?? ''}/api/v1${path}`, { ...init, headers, signal })
  } catch {
    throw new ApiError(fallback)
  }
  if (res.status === 401) {
    if (server) servers.logout(server.id, server)
    throw new ApiError('Session expired', 401)
  }
  if (!res.ok) throw await errorFrom(res, fallback)
  return res
}

/// Fetches capabilities for an explicit server entry (rather than
/// `servers.current`) — used by the sidebar to show every authenticated
/// entry's OS icon, not just the currently selected one.
export async function getCapabilitiesFor(entry: ServerEntry, signal?: AbortSignal): Promise<Capabilities> {
  if (!entry.token) throw new ApiError('Not authenticated')
  requireSecureUrl(entry.url)
  const res = await fetch(`${entry.url}/api/v1/capabilities`, {
    headers: { Authorization: `Bearer ${entry.token}` },
    signal: requestSignal(signal),
  })
  if (!res.ok) throw new ApiError('Failed to fetch capabilities')
  return res.json() as Promise<Capabilities>
}

/// Fetches status, including the agent-reported `name`, for an explicit server
/// entry — used by the sidebar/settings header so the displayed name always
/// reflects `config.toml`, never a locally cached copy.
export async function getStatusFor(entry: ServerEntry, signal?: AbortSignal): Promise<StatusResponse> {
  if (!entry.token) throw new ApiError('Not authenticated')
  requireSecureUrl(entry.url)
  const res = await fetch(`${entry.url}/api/v1/status`, {
    headers: { Authorization: `Bearer ${entry.token}` },
    signal: requestSignal(signal),
  })
  if (!res.ok) throw new ApiError('Failed to fetch status')
  return res.json() as Promise<StatusResponse>
}

/// Unauthenticated reachability probe for a candidate URL (add/edit server
/// form), independent of `servers.current` because the entry may not be saved.
export async function testConnection(url: string): Promise<boolean> {
  try {
    requireSecureUrl(url)
    const res = await fetch(`${url}/api/v1/health`, { signal: requestSignal() })
    return res.ok
  } catch {
    return false
  }
}

/// Logs into an explicit URL from the add/edit form.
export async function loginTo(url: string, credentials: LoginRequest): Promise<LoginResponse> {
  requireSecureUrl(url)
  let res: Response
  try {
    res = await fetch(`${url}/api/v1/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(credentials),
      signal: requestSignal(),
    })
  } catch {
    throw new ApiError('Login failed')
  }
  if (!res.ok) {
    let message = 'Login failed'
    try {
      const body = (await res.json()) as { error?: string }
      if (body.error) message = body.error
    } catch {
      // Non-JSON error body: keep the fallback message
    }
    throw new ApiError(message, res.status)
  }
  return res.json() as Promise<LoginResponse>
}

export const api = {
  login: (credentials: LoginRequest) =>
    request<LoginResponse>(
      '/login',
      { method: 'POST', body: JSON.stringify(credentials) },
      'Login failed',
    ),
  getStatus: (signal?: AbortSignal) =>
    request<StatusResponse>('/status', {}, 'Failed to fetch status', signal),
  getMetrics: (signal?: AbortSignal) =>
    request<SystemMetrics>('/metrics', {}, 'Failed to fetch metrics', signal),
  getHistory: (minutes: number, signal?: AbortSignal) =>
    request<HistoryPoint[]>(
      `/metrics/history?minutes=${minutes}`,
      {},
      'Failed to fetch history',
      signal,
    ),
  // Capabilities are platform-specific, so callers fetch them once per server.
  getCapabilities: () => request<Capabilities>('/capabilities', {}, 'Failed to fetch capabilities'),
  /// One reading of the machine's process table (the `shell` grant).
  ///
  /// The order is asked of the agent rather than applied here: which orders a
  /// table can answer depends on the columns this machine printed, and the
  /// response says both. `ascending` is omitted unless the user chose one.
  getProcess: (sort?: ProcessSortMode, ascending?: boolean) =>
    request<ProcessView>(
      `/process?${new URLSearchParams({
        ...(sort ? { sort } : {}),
        ...(ascending === undefined ? {} : { ascending: String(ascending) }),
      })}`,
      {},
      'Failed to fetch the process list',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Sends one signal. The agent checks the PID's start identity first, and
  /// retries as root with `password` for another account's process.
  signalProcess: (payload: ProcessSignalRequest) =>
    request<ProcessSignalResult>(
      '/process',
      { method: 'POST', body: JSON.stringify(payload) },
      'Failed to reach the machine',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The machine's service units, or one unit's log, definition or status
  /// (the `shell` grant). A unit is named by the key its listing gave it.
  getServices: (part: ServicePart = 'list', key?: string) =>
    request<ServiceView>(
      `/services?${new URLSearchParams({ part, ...(key ? { key } : {}) })}`,
      {},
      'Failed to fetch the services',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// One action on one unit. The agent resolves the key against a fresh
  /// listing and decides itself whether it needs root.
  actService: (payload: ServiceActRequest) =>
    request<ServiceActResult>(
      '/services',
      { method: 'POST', body: JSON.stringify(payload) },
      'Failed to reach the machine',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The account's crontab, expanded on the agent against its own clock (the
  /// `shell` grant).
  getCron: () =>
    request<CronView>('/cron', {}, 'Failed to fetch the schedule', undefined, MACHINE_TIMEOUT_MS),
  /// One change; answers with the schedule as it now stands. The file is
  /// re-read at the moment of the write, so only `line_index` can be stale,
  /// and one that no longer names a job is refused (400) rather than applied
  /// to whatever moved into its place. A refusal arrives as
  /// `ApiError.message`, holding the rule's own name (`scheduleEmpty`, ...).
  editCron: (edit: CronEdit) =>
    request<CronView>(
      '/cron',
      { method: 'PUT', body: JSON.stringify(edit) },
      'Failed to save the schedule',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The runtime's containers, images or disk usage — one at a time (the
  /// `shell` grant). `part: 'logs'` names a container: a log belongs to one,
  /// and the agent refuses the request rather than guessing which.
  getContainers: (part: ContainerPart, id?: string) =>
    request<ContainerView>(
      `/containers?part=${part}${id ? `&id=${encodeURIComponent(id)}` : ''}`,
      {},
      'Failed to fetch the containers',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// One change, answered in one round trip with the refreshed listing and
  /// `exit_code`/`output`, what the runtime said about the change.
  actContainer: (action: ContainerAction) =>
    request<ContainerActionResult>(
      '/containers',
      { method: 'POST', body: JSON.stringify(action) },
      'Failed to change the container',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The benchmark runs this agent has started, and the live state of the one
  /// going (the `shell` grant). `live.answered === false` means the machine
  /// did not answer in time: ask again, and read nothing into `dir_exists`
  /// until it is true. The agent polls the run for this request, which can
  /// take a while on a machine under load, hence the long timeout.
  getBenchmark: (signal?: AbortSignal) =>
    request<BenchView>('/benchmark', {}, 'Failed to fetch the benchmark runs', signal, MACHINE_TIMEOUT_MS),
  /// One run in full, including yabs' `result_json` and the stored log.
  getBenchmarkRun: (id: string, signal?: AbortSignal) =>
    request<BenchDetail>(
      `/benchmark?run=${encodeURIComponent(id)}`,
      {},
      'Failed to fetch the run',
      signal,
      MACHINE_TIMEOUT_MS,
    ),
  /// What a set of options would cost, asked of the agent so this page never
  /// re-derives the formula. Changes nothing.
  ///
  /// The agent answers `{estimate: {...}, system_info_only}`; flattened here
  /// into the one object the page draws from.
  estimateBenchmark: async (options: BenchOptions): Promise<BenchEstimate> => {
    const { estimate, system_info_only } = await request<{
      estimate: Omit<BenchEstimate, 'system_info_only'>
      system_info_only: boolean
    }>(
      '/benchmark',
      { method: 'POST', body: JSON.stringify({ action: 'estimate', options }) },
      'Failed to estimate the run',
      undefined,
      MACHINE_TIMEOUT_MS,
    )
    return { ...estimate, system_info_only }
  },
  /// Starts a run. The agent writes the script, records the row and waits for
  /// the launcher to confirm before it answers.
  startBenchmark: (options: BenchOptions) =>
    request<{ run: BenchRun }>(
      '/benchmark',
      { method: 'POST', body: JSON.stringify({ action: 'start', options }) },
      'Failed to start the run',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Stops the run that is going; a sleep sits between the TERM and the KILL.
  cancelBenchmark: () =>
    request<{ cancelled: boolean }>(
      '/benchmark',
      { method: 'POST', body: JSON.stringify({ action: 'cancel' }) },
      'Failed to stop the run',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Forgets one finished run and cleans up after it on the machine. One that
  /// is still going is refused (`run_in_progress`): removing the record would
  /// lose the only handle on a live process.
  removeBenchmark: (id: string) =>
    request<unknown>(
      `/benchmark?run=${encodeURIComponent(id)}`,
      { method: 'DELETE' },
      'Failed to remove the run',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The machine's accounts, or one account's own records (the `shell`
  /// grant). Not `/users`, which is this agent's own accounts.
  getSystemUsers: (part: UserPart = 'list', name?: string) =>
    request<UserView>(
      `/system-users?${new URLSearchParams({ part, ...(name ? { name } : {}) })}`,
      {},
      'Failed to fetch the accounts',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Creates, changes or removes one account. The agent resolves the account
  /// against a listing it reads for the request, and runs the change as root;
  /// a refusal before that arrives as `ApiError.message`, holding its code.
  actSystemUser: (payload: UserActRequest) =>
    request<UserActResult>(
      '/system-users',
      { method: 'POST', body: JSON.stringify(payload) },
      'Failed to reach the machine',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The snippet library saved on the agent (the `shell` grant).
  getSnippets: () => request<SnippetsView>('/snippets', {}, 'Failed to fetch the snippets'),
  /// Replaces the whole library, in the order given. A refusal arrives with
  /// its code as `ApiError.message` and the row as `body.index`.
  updateSnippets: (snippets: Snippet[]) =>
    request<SnippetsView>(
      '/snippets',
      { method: 'PUT', body: JSON.stringify({ snippets }) },
      'Failed to save the snippets',
    ),
  /// What a script types, expanded by the agent. Runs nothing. The panel has
  /// no server values to offer, so the context is empty and a script naming
  /// one is refused with `body.key`.
  planSnippet: (script: string) =>
    request<SnippetPlan>(
      '/snippets/plan',
      { method: 'POST', body: JSON.stringify({ script, context: {} }) },
      'Failed to expand the snippet',
    ),
  /// The desktop routes saved on the agent (the `connect` grant).
  getBmc: () => request<BmcList>('/bmc', {}, 'Failed to list the BMCs'),
  /// Replaces the whole set. A refusal arrives with its code as
  /// `ApiError.message` and the row as `body.index`.
  updateBmc: (targets: BmcTargetInput[]) =>
    request<BmcList>('/bmc', { method: 'PUT', body: JSON.stringify({ targets }) }, 'Failed to save the BMCs'),
  probeBmc: (url: string) =>
    request<BmcCertInfo>(
      '/bmc/probe',
      { method: 'POST', body: JSON.stringify({ url }) },
      'Failed to read the certificate',
    ),
  /// An upstream failure arrives as `ApiError` with `body.failure`.
  bmcStatus: (id: string) =>
    request<BmcStatus>(`/bmc/${encodeURIComponent(id)}`, {}, 'Failed to reach the BMC'),
  bmcPower: (id: string, intent: BmcIntent) =>
    request<{ outcome: { kind: 'done' | 'accepted' } }>(
      `/bmc/${encodeURIComponent(id)}/power`,
      { method: 'POST', body: JSON.stringify({ intent }) },
      'Failed to reach the BMC',
    ),
  /// The host and its guests. `password` is the operator's sudo password
  /// for a libvirt that refuses the agent's account: sent for this request,
  /// never stored. A host's failure is `error` in a 200, not an `ApiError`.
  loadVirt: (password?: string) =>
    request<VirtLoad>(
      '/virt',
      { method: 'POST', body: JSON.stringify({ password: password ?? null }) },
      'Failed to read the virtualization host',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Returns once the host has finished it (a PVE task stopped).
  virtPower: (guest: string, action: VirtPowerAction, password?: string) =>
    request<{ error: VirtError | null }>(
      '/virt/power',
      { method: 'POST', body: JSON.stringify({ guest, action, password: password ?? null }) },
      'Failed to reach the virtualization host',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtDetail: (guest: string, password?: string) =>
    request<{ detail: VirtGuestDetail | null; error: VirtError | null }>(
      '/virt/detail',
      { method: 'POST', body: JSON.stringify({ guest, password: password ?? null }) },
      'Failed to read the guest',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// `history: null` where the host keeps none (libvirt).
  virtHistory: (guest: string, window: VirtHistoryWindow) =>
    request<{ history: VirtStats[] | null; error: VirtError | null }>(
      '/virt/history',
      { method: 'POST', body: JSON.stringify({ guest, window }) },
      'Failed to read the guest\'s history',
    ),
  /// Resolves the console and mints the ticket its websocket opens with.
  virtConsole: (guest: string, kind: VirtConsoleKind, password?: string) =>
    request<VirtConsoleAnswer>(
      '/virt/console',
      { method: 'POST', body: JSON.stringify({ guest, kind, password: password ?? null }) },
      'Failed to open the console',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtSnapshots: (guest: string, password?: string) =>
    request<VirtSnapshots>(
      '/virt/snapshots',
      { method: 'POST', body: JSON.stringify({ guest, password: password ?? null }) },
      'Failed to read the snapshots',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Returns once the host has finished it.
  virtSnapshot: (guest: string, op: VirtSnapshotOp, password?: string) =>
    request<{ error: VirtError | null }>(
      '/virt/snapshot',
      { method: 'POST', body: JSON.stringify({ guest, ...op, password: password ?? null }) },
      'Failed to reach the virtualization host',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtSnapshotDiff: (guest: string, name: string, password?: string) =>
    request<{ diff: VirtSnapDiff[] | null; error: VirtError | null }>(
      '/virt/snapshot/diff',
      { method: 'POST', body: JSON.stringify({ guest, name, password: password ?? null }) },
      'Failed to compare the snapshot',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  getPve: () => request<PveConfigView>('/virt/pve', {}, 'Failed to read the Proxmox VE settings'),
  /// A refusal arrives with its code as `ApiError.message`.
  setPve: (config: PveConfigInput) =>
    request<PveConfigView>('/virt/pve', { method: 'PUT', body: JSON.stringify(config) }, 'Failed to save the Proxmox VE settings'),
  removePve: () => request<PveConfigView>('/virt/pve', { method: 'DELETE' }, 'Failed to remove the Proxmox VE settings'),
  pinPve: (fingerprint: string) =>
    request<{ error: VirtError | null }>(
      '/virt/pve/cert',
      { method: 'POST', body: JSON.stringify({ fingerprint }) },
      'Failed to trust the certificate',
    ),
  pveTfa: (code: string) =>
    request<{ error: VirtError | null }>(
      '/virt/pve/tfa',
      { method: 'POST', body: JSON.stringify({ code }) },
      'Failed to send the code',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  getBackups: () => request<BackupView>('/backup', {}, 'Failed to list the backups'),
  /// The blob's bytes, as stored. The panel has no key for what is in them.
  downloadBackup: async (name: string): Promise<Blob> => {
    const res = await fsBytes(
      `/backup/blob?name=${encodeURIComponent(name)}`,
      {},
      'Failed to download the backup',
    )
    return res.blob()
  },
  uploadBackup: async (name: string, body: Blob): Promise<void> => {
    await fsBytes(
      `/backup/blob?name=${encodeURIComponent(name)}`,
      { method: 'PUT', body, headers: { 'Content-Type': 'application/octet-stream' } },
      'Failed to store the backup',
    )
  },
  deleteBackup: async (name: string): Promise<void> => {
    await fsBytes(
      `/backup/blob?name=${encodeURIComponent(name)}`,
      { method: 'DELETE' },
      'Failed to remove the backup',
    )
  },
  getDesktops: () => request<DesktopsView>('/desktops', {}, 'Failed to fetch the desktops'),
  /// Replaces the whole set, in order. A refusal arrives with its code as
  /// `ApiError.message` and the row as `body.index`.
  updateDesktops: (desktops: Desktop[]) =>
    request<DesktopsView>(
      '/desktops',
      { method: 'PUT', body: JSON.stringify({ desktops }) },
      'Failed to save the desktops',
    ),
  /// Shuts the machine down, reboots or suspends it. The password is for
  /// `sudo -S` and travels as its own field, never inside a command.
  power: (action: PowerAction, password?: string) =>
    request<PowerResult>(
      '/power',
      { method: 'POST', body: JSON.stringify({ action, password: password || null }) },
      'Failed to reach the machine',
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  getSettings: () => request<SettingsView>('/settings', {}, 'Failed to fetch settings'),
  updateSettings: (payload: SettingsPayload) =>
    request<{ status: string }>(
      '/settings',
      { method: 'PUT', body: JSON.stringify(payload) },
      'Failed to save settings',
    ),
  /// Exchanges the session token for a single-use ticket authorising one
  /// WebSocket upgrade. A browser can't put a bearer token on a WebSocket
  /// handshake, and a token in the query string would land in the agent's
  /// access log; the ticket is good for one connection and ~30 seconds.
  issueWsTicket: (purpose: WsTicketPurpose) =>
    request<WsTicketResponse>(
      '/ws-ticket',
      { method: 'POST', body: JSON.stringify({ purpose }) },
      'Failed to authorise the connection',
    ),
  /// Turns access without SSH off for good. There is deliberately no
  /// counterpart that turns it on: the panel may narrow what the agent
  /// exposes, never widen it — re-enabling is a config-file decision.
  disablePasswordlessTerminal: () =>
    request<{ status: string }>(
      '/remote-access/full-access',
      { method: 'DELETE' },
      'Failed to disable access without SSH',
    ),
  /// The directories the operator opened up, and the whole of what can be
  /// browsed: everything outside them is refused by the agent, so the page
  /// starts from this list rather than from `/`.
  fsRoots: (signal?: AbortSignal) =>
    request<FsRootsResponse>('/fs/roots', {}, 'Failed to list the roots', signal),
  fsList: (path: string, signal?: AbortSignal) =>
    request<FsEntry[]>(
      `/fs/list?path=${encodeURIComponent(path)}`,
      {},
      'Failed to list the directory',
      signal,
    ),
  fsStat: (path: string, signal?: AbortSignal) =>
    request<FsEntry>(
      `/fs/stat?path=${encodeURIComponent(path)}`,
      {},
      'Failed to read the entry',
      signal,
    ),
  /// The bytes, as a blob the browser can be handed. There is no `<a download>`
  /// shortcut here: the endpoint wants a bearer token, and a URL cannot carry
  /// one without putting it in the agent's access log.
  fsRead: async (path: string, signal?: AbortSignal): Promise<Blob> => {
    const res = await fsBytes(
      `/fs/read?path=${encodeURIComponent(path)}`,
      {},
      'Failed to read the file',
      signal,
    )
    return res.blob()
  },
  fsWrite: async (path: string, body: Blob, signal?: AbortSignal): Promise<void> => {
    await fsBytes(
      `/fs/write?path=${encodeURIComponent(path)}`,
      { method: 'PUT', body, headers: { 'Content-Type': 'application/octet-stream' } },
      'Failed to write the file',
      signal,
    )
  },
  fsMkdir: (path: string) =>
    request<unknown>(
      '/fs/mkdir',
      { method: 'POST', body: JSON.stringify({ path }) },
      'Failed to create the directory',
    ),
  fsRename: (from: string, to: string) =>
    request<unknown>(
      '/fs/rename',
      { method: 'POST', body: JSON.stringify({ from, to }) },
      'Failed to rename',
    ),
  fsChmod: (path: string, mode: number) =>
    request<unknown>(
      '/fs/chmod',
      { method: 'POST', body: JSON.stringify({ path, mode }) },
      'Failed to change the permissions',
    ),
  fsRemove: (path: string, recursive: boolean) =>
    request<unknown>(
      '/fs/remove',
      { method: 'DELETE', body: JSON.stringify({ path, recursive }) },
      'Failed to delete',
    ),
  getCustomCmds: () =>
    request<CustomCmdsView>('/custom-cmds', {}, 'Failed to fetch custom commands'),
  /// The whole set, in the order it should run in. A replace rather than a
  /// per-command edit: the order is part of what is stored, so a move has no
  /// smaller expression than the new list.
  updateCustomCmds: (commands: CustomCmd[]) =>
    request<CustomCmdsView>(
      '/custom-cmds',
      { method: 'PUT', body: JSON.stringify({ commands }) },
      'Failed to save custom commands',
    ),
  getPush: () => request<PushListView>('/push', {}, 'Failed to fetch push channels'),
  /// The whole set, in order, like the custom commands. Each entry carries the
  /// `from_index` it was loaded at, which is the only thing a withheld
  /// credential (a `null` value) can be resolved against — see `PushEntry`.
  updatePush: (payload: PushPayload) =>
    request<PushListView>(
      '/push',
      { method: 'PUT', body: JSON.stringify(payload) },
      'Failed to save push channels',
    ),
  /// Sends one notification now, through the channel as currently edited. A
  /// channel that cannot be tried is one whose first real alert is where it
  /// gets found out. The agent answers 200 with `ok: false` for a delivery
  /// that failed, so only a refused *request* throws here.
  testPush: (push: PushEntry, message: string) =>
    request<PushTestResult>(
      '/push/test',
      { method: 'POST', body: JSON.stringify({ push, message }) },
      'Failed to send the test notification',
    ),
  /// Who this session is on the agent, and with what role.
  getMe: () => request<{ username: string; role: Role }>('/me', {}, 'Failed to fetch your account'),
  changeMyPassword: (current_password: string, new_password: string) =>
    request<void>(
      '/me/password',
      { method: 'PUT', body: JSON.stringify({ current_password, new_password }) },
      'Failed to change the password',
    ),
  // Everything below needs an administrator, and every change carries the
  // administrator's own password: what changes access is re-authenticated,
  // not taken on the strength of a session that may have been left open.
  listUsers: () => request<AgentUser[]>('/users', {}, 'Failed to fetch accounts'),
  createUser: (username: string, password: string, role: string, current_password: string) =>
    request<AgentUser>(
      '/users',
      { method: 'POST', body: JSON.stringify({ username, password, role, current_password }) },
      'Failed to add the account',
    ),
  /// Changes the role, the password, or both; a field left out is kept.
  updateUser: (
    username: string,
    change: { role?: string; password?: string },
    current_password: string,
  ) =>
    request<AgentUser>(
      `/users/${encodeURIComponent(username)}`,
      { method: 'PUT', body: JSON.stringify({ ...change, current_password }) },
      'Failed to update the account',
    ),
  deleteUser: (username: string, current_password: string) =>
    request<void>(
      `/users/${encodeURIComponent(username)}`,
      { method: 'DELETE', body: JSON.stringify({ current_password }) },
      'Failed to delete the account',
    ),
  listRoles: () => request<Role[]>('/roles', {}, 'Failed to fetch roles'),
  createRole: (role: Omit<Role, 'builtin'>, current_password: string) =>
    request<Role>(
      '/roles',
      { method: 'POST', body: JSON.stringify({ role, current_password }) },
      'Failed to add the role',
    ),
  updateRole: (role: Role, current_password: string) =>
    request<Role>(
      `/roles/${encodeURIComponent(role.name)}`,
      { method: 'PUT', body: JSON.stringify({ role, current_password }) },
      'Failed to save the role',
    ),
  deleteRole: (name: string, current_password: string) =>
    request<void>(
      `/roles/${encodeURIComponent(name)}`,
      { method: 'DELETE', body: JSON.stringify({ current_password }) },
      'Failed to delete the role',
    ),
  getCardOrder: () => request<CardOrderPayload>('/card-order', {}, 'Failed to fetch card order'),
  updateCardOrder: (card_order: string[]) =>
    request<{ status: string }>(
      '/card-order',
      { method: 'PUT', body: JSON.stringify({ card_order }) },
      'Failed to save card order',
    ),
}
