import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import type {
  AgentUpdate,
  InstalledApp,
  ContainerBackup,
  ContainerBackupSchedule,
  ContainerBackupSettings,
  StackApp,
  HealthReading,
  MaintenanceKind,
  MaintenanceTask,
  NfsExport,
  SharesView,
  ShareConnections,
  SmbShare,
  StorageAction,
  StorageView,
  StackEntry,
  StackJob,
  StackPrepare,
  StackPreview,
  StackService,
  StackValue,
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
  SettingsPayload,
  SettingsView,
  StatusResponse,
  SystemMetrics,
  TmuxView,
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
  FirewallActResult,
  FirewallChange,
  FirewallKind,
  FirewallPlanResult,
  FirewallView,
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
  VirtBackupEdit,
  VirtBackupJobEdit,
  VirtBackupJobs,
  VirtBackupRequest,
  VirtBackups,
  VirtScheduleCheck,
  VirtCloneRequest,
  VirtCloudInitEdit,
  VirtCloudInitState,
  VirtHardware,
  VirtHostDevices,
  VirtHwChange,
  VirtHwOutcome,
  VirtConsoleAnswer,
  VirtCreated,
  VirtCreateForm,
  VirtCreateSpec,
  VirtGuestKind,
  VirtConsoleKind,
  VirtError,
  VirtGuestDetail,
  VirtHistoryWindow,
  VirtLoad,
  VirtSnapDiff,
  VirtChange,
  VirtNetwork,
  VirtNetworkChanges,
  VirtPool,
  VirtPoolRule,
  VirtVolume,
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

/// For a PVE task the agent waits for that can run long (a backup, a
/// restore): `sbm_virt`'s client waits ten minutes for one, so this only has
/// to outlast that.
const TASK_TIMEOUT_MS = 660_000

export class ApiError extends Error {
  /// HTTP status, when the request got far enough to have one. Absent for a
  /// failure to reach the agent at all — a distinction callers that retry
  /// need, since "refused" and "unreachable" deserve opposite responses.
  readonly status?: number

  /// The agent's stable error code, where the endpoint gives one (`reauth`,
  /// `forbidden`, ...). Absent for the older
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
/// newer ones `{"error": "<code>", "message": "..."}`. A body with
/// a `message` is the second, and its `error` is the code.
export async function errorFrom(res: Response): Promise<ApiError> {
  const body = (await res.json().catch(() => null)) as ErrorBody | null
  return errorFromBody(res.status, body)
}

export type ErrorBody = { error?: string; message?: string } & Record<string, unknown>

/// [errorFrom] for a body already read (an XHR's). One without words of its
/// own (a proxy's page, an empty body) is said by its status.
export function errorFromBody(status: number, body: ErrorBody | null): ApiError {
  if (body?.message) return new ApiError(body.message, status, body.error, body)
  if (body?.error) return new ApiError(body.error, status, undefined, body)
  return new ApiError(get(LL).agentAnswered({ status }), status)
}

/// The agent could not be reached: the network, a timeout, a proxy that
/// dropped the connection.
function unreachable(): ApiError {
  return new ApiError(get(LL).agentUnreachable(), undefined, 'unreachable')
}

/// The session of [entry] is over: dropped, so the panel goes back to login.
function sessionExpired(entry: ServerEntry | undefined): ApiError {
  if (entry) servers.logout(entry.id, entry)
  return new ApiError(get(LL).agentSessionExpired(), 401)
}

/// [entry]'s bearer, over [headers].
function authHeaders(entry: ServerEntry | undefined, headers: Record<string, string> = {}): Record<string, string> {
  return entry?.token ? { ...headers, Authorization: `Bearer ${entry.token}` } : headers
}

/// One request to [entry]'s agent: the URL checked, the bearer sent, a 401
/// ending the session (but on `/login`, where it is a wrong password). Any
/// other answer is the caller's to read.
export async function fetchFor(
  entry: ServerEntry | undefined,
  path: string,
  init: RequestInit,
  signal?: AbortSignal,
): Promise<Response> {
  const server = entry ? { ...entry } : undefined
  requireSecureUrl(server?.url ?? '')
  let res: Response
  try {
    res = await fetch(`${server?.url ?? ''}/api/v1${path}`, {
      ...init,
      headers: authHeaders(server, init.headers as Record<string, string> | undefined),
      signal,
    })
  } catch {
    throw unreachable()
  }
  if (res.status === 401 && path !== '/login') throw sessionExpired(server)
  return res
}

function requestSignal(signal?: AbortSignal, timeoutMs = TIMEOUT_MS): AbortSignal {
  const timeout = AbortSignal.timeout(timeoutMs)
  return signal ? AbortSignal.any([signal, timeout]) : timeout
}

function requireSecureUrl(url: string) {
  if (!isSecureAgentUrl(url)) {
    throw new ApiError(get(LL).agentHttpsRequired(), undefined, 'insecure')
  }
}

async function request<T>(
  path: string,
  init: RequestInit = {},
  signal?: AbortSignal,
  timeoutMs = TIMEOUT_MS,
): Promise<T> {
  return requestFor<T>(servers.current, path, init, signal, timeoutMs)
}

/// [request] to an explicit entry: for what must reach the server it was
/// started for even if another is selected meanwhile (the desk saving its
/// session as the server switches).
export async function requestFor<T>(
  entry: ServerEntry | undefined,
  path: string,
  init: RequestInit = {},
  signal?: AbortSignal,
  timeoutMs = TIMEOUT_MS,
): Promise<T> {
  // JSON unless the caller says what it sends.
  const headers = { 'Content-Type': 'application/json', ...(init.headers as Record<string, string> | undefined) }
  const res = await fetchFor(entry, path, { ...init, headers }, requestSignal(signal, timeoutMs))
  if (!res.ok) throw await errorFrom(res)
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
/// Sends [body] to [path] on [entry] and answers the JSON reply: as
/// [requestFor], over XHR, which reports how much of the body has gone
/// ([onProgress], 0–1). Aborting [signal] fails it with code `aborted`.
export function uploadFor<T>(
  entry: ServerEntry,
  path: string,
  body: Blob,
  opts: { onProgress?: (sent: number) => void; signal?: AbortSignal; timeoutMs?: number } = {},
): Promise<T> {
  const server = { ...entry }
  requireSecureUrl(server.url)
  return new Promise<T>((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open('POST', `${server.url}/api/v1${path}`)
    xhr.timeout = opts.timeoutMs ?? TIMEOUT_MS
    for (const [name, value] of Object.entries(authHeaders(server, { 'Content-Type': body.type || 'application/octet-stream' }))) {
      xhr.setRequestHeader(name, value)
    }
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable && e.total > 0) opts.onProgress?.(e.loaded / e.total)
    }
    const abort = () => xhr.abort()
    opts.signal?.addEventListener('abort', abort, { once: true })
    const done = () => opts.signal?.removeEventListener('abort', abort)
    xhr.onabort = () => {
      done()
      reject(new ApiError('Aborted', 0, 'aborted'))
    }
    xhr.onerror = xhr.ontimeout = () => {
      done()
      reject(unreachable())
    }
    xhr.onload = () => {
      done()
      let json: ErrorBody | null = null
      try {
        json = JSON.parse(xhr.responseText)
      } catch {
        // Not JSON: said by its status.
      }
      if (xhr.status === 401) {
        reject(sessionExpired(server))
      } else if (xhr.status < 200 || xhr.status >= 300) {
        reject(errorFromBody(xhr.status, json))
      } else {
        resolve(json as T)
      }
    }
    if (opts.signal?.aborted) {
      xhr.onabort?.(new ProgressEvent('abort'))
      return
    }
    xhr.send(body)
  })
}

async function fsBytes(path: string, init: RequestInit, signal?: AbortSignal): Promise<Response> {
  const res = await fetchFor(servers.current, path, init, signal)
  if (!res.ok) throw await errorFrom(res)
  return res
}

/// One of the agent's `text/event-stream`s at [path] (`/desk/events`,
/// `/agent/events`), read with the bearer header, which an `EventSource`
/// cannot send.
export async function readEventStream(
  entry: ServerEntry,
  path: string,
  signal: AbortSignal,
  onEvent: (event: Record<string, unknown>) => void,
  /// The stream is open: the agent may send nothing for a long time.
  onOpen?: () => void,
  /// Posted as JSON: a stream that answers a request.
  body?: unknown,
): Promise<void> {
  const res = await fetchFor(
    entry,
    path,
    {
      method: body === undefined ? 'GET' : 'POST',
      headers: body === undefined ? {} : { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    },
    signal,
  )
  if (!res.ok || !res.body) throw await errorFrom(res)
  onOpen?.()
  const reader = res.body.pipeThrough(new TextDecoderStream()).getReader()
  let buffer = ''
  for (;;) {
    const { value, done } = await reader.read()
    if (done) return
    buffer += value
    let end: number
    while ((end = buffer.indexOf('\n\n')) >= 0) {
      const frame = buffer.slice(0, end)
      buffer = buffer.slice(end + 2)
      for (const line of frame.split('\n')) {
        if (!line.startsWith('data:')) continue
        try {
          onEvent(JSON.parse(line.slice(5).trim()) as Record<string, unknown>)
        } catch {
          // A line that is not JSON is not an event.
        }
      }
    }
  }
}

/// Fetches capabilities for an explicit server entry (rather than
/// `servers.current`) — used by the lock screen to show every authenticated
/// entry's OS icon, not just the currently selected one.
export async function getCapabilitiesFor(entry: ServerEntry, signal?: AbortSignal): Promise<Capabilities> {
  if (!entry.token) throw new ApiError('Not authenticated')
  requireSecureUrl(entry.url)
  const res = await fetch(`${entry.url}/api/v1/capabilities`, {
    headers: { Authorization: `Bearer ${entry.token}` },
    signal: requestSignal(signal),
  })
  if (!res.ok) throw await errorFrom(res)
  return res.json() as Promise<Capabilities>
}

/// Fetches status, including the agent-reported `name`, for an explicit server
/// entry — used by the menubar and the lock screen so the displayed name always
/// reflects `config.toml`, never a locally cached copy.
export async function getStatusFor(entry: ServerEntry, signal?: AbortSignal): Promise<StatusResponse> {
  if (!entry.token) throw new ApiError('Not authenticated')
  requireSecureUrl(entry.url)
  const res = await fetch(`${entry.url}/api/v1/status`, {
    headers: { Authorization: `Bearer ${entry.token}` },
    signal: requestSignal(signal),
  })
  if (!res.ok) throw await errorFrom(res)
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

/// Per agent URL ('' is this origin): the device token its last sign-in gave
/// this browser. It only keeps this browser out of the agent's account-wide
/// login throttle (`api::ratelimit::Who`); it signs nothing in on its own.
const DEVICES_KEY = 'servers.devices.v1'

function readDevices(): Record<string, string> {
  try {
    const parsed = JSON.parse(window.localStorage.getItem(DEVICES_KEY) ?? '{}') as unknown
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, string>) : {}
  } catch {
    return {}
  }
}

function rememberDevice(url: string, device: string) {
  try {
    window.localStorage.setItem(DEVICES_KEY, JSON.stringify({ ...readDevices(), [url]: device }))
  } catch {
    // Storage full or blocked: the next sign-in is a stranger's again.
  }
}

/// Signs in to the agent at [url] ('' for this origin), sending the device
/// token an earlier sign-in gave this browser and keeping a new one.
export async function loginTo(url: string, credentials: LoginRequest): Promise<LoginResponse> {
  requireSecureUrl(url)
  const device = readDevices()[url]
  let res: Response
  try {
    res = await fetch(`${url}/api/v1/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(device ? { ...credentials, device } : credentials),
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
  const answer = (await res.json()) as LoginResponse
  if (answer.device) rememberDevice(url, answer.device)
  return answer
}

export const api = {
  getStatus: (signal?: AbortSignal) =>
    request<StatusResponse>('/status', {}, signal),
  getMetrics: (signal?: AbortSignal) =>
    request<SystemMetrics>('/metrics', {}, signal),
  getHistory: (minutes: number, signal?: AbortSignal) =>
    request<HistoryPoint[]>(
      `/metrics/history?minutes=${minutes}`,
      {},
      signal,
    ),
  // Capabilities are platform-specific, so callers fetch them once per server.
  getCapabilities: () => request<Capabilities>('/capabilities', {}),
  /// Whether a newer agent is out; with [check], the agent reads its
  /// releases again first (at most once a minute).
  getUpdate: (check = false) => request<AgentUpdate>(check ? '/update?check=1' : '/update', {}),
  /// Starts the update apart from the agent, so its restart does not end it;
  /// `getUpdate`'s `run` then says how it goes. A refused sudo password is
  /// `403` with code `sudo_password`.
  startUpdate: (password?: string) =>
    request<void>('/update/run', { method: 'POST', body: JSON.stringify({ password }) }),
  /// One reading of the machine's process table.
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
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Sends one signal. The agent checks the PID's start identity first, and
  /// retries as root with `password` for another account's process.
  signalProcess: (payload: ProcessSignalRequest) =>
    request<ProcessSignalResult>(
      '/process',
      { method: 'POST', body: JSON.stringify(payload) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The machine's service units, or one unit's log, definition or status.
  /// A unit is named by the key its listing gave it.
  getServices: (part: ServicePart = 'list', key?: string) =>
    request<ServiceView>(
      `/services?${new URLSearchParams({ part, ...(key ? { key } : {}) })}`,
      {},
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// One action on one unit. The agent resolves the key against a fresh
  /// listing and decides itself whether it needs root.
  actService: (payload: ServiceActRequest) =>
    request<ServiceActResult>(
      '/services',
      { method: 'POST', body: JSON.stringify(payload) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The account's crontab, expanded on the agent against its own clock.
  getCron: () =>
    request<CronView>('/cron', {}, undefined, MACHINE_TIMEOUT_MS),
  /// One change; answers with the schedule as it now stands. The file is
  /// re-read at the moment of the write, so only `line_index` can be stale,
  /// and one that no longer names a job is refused (400) rather than applied
  /// to whatever moved into its place. A refusal arrives as
  /// `ApiError.message`, holding the rule's own name (`scheduleEmpty`, ...).
  editCron: (edit: CronEdit) =>
    request<CronView>(
      '/cron',
      { method: 'PUT', body: JSON.stringify(edit) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The runtime's containers, images or disk usage — one at a time.
  /// `part: 'logs'` names a container: a log belongs to one,
  /// and the agent refuses the request rather than guessing which.
  getContainers: (part: ContainerPart, id?: string) =>
    request<ContainerView>(
      `/containers?part=${part}${id ? `&id=${encodeURIComponent(id)}` : ''}`,
      {},
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// One change, answered in one round trip with the refreshed listing and
  /// `exit_code`/`output`, what the runtime said about the change. A refusal
  /// arrives as `ApiError.message` holding `invalid_input`, with the issue in
  /// `body.issue`.
  ///
  /// The agent bounds every action by `[remote_access.exec]`, which this side
  /// cannot read. A pull and a run fetch image layers, so they are the ones an
  /// operator raises that limit for: the longer deadline lets such a pull
  /// answer instead of being abandoned here while it still runs there.
  actContainer: (action: ContainerAction) =>
    request<ContainerActionResult>(
      '/containers',
      { method: 'POST', body: JSON.stringify(action) },
      undefined,
      action.action === 'pull_image' || action.action === 'run'
        ? TASK_TIMEOUT_MS
        : MACHINE_TIMEOUT_MS,
    ),
  /// The machine's tmux sessions. `available: false` when
  /// tmux is not installed; a machine with tmux and nothing running answers
  /// `available: true` with an empty list. Attaching is the terminal's
  /// `target`, not a request here.
  getTmux: () =>
    request<TmuxView>('/tmux', {}, undefined, MACHINE_TIMEOUT_MS),
  /// The benchmark runs this agent has started, and the live state of the one
  /// going. `live.answered === false` means the machine
  /// did not answer in time: ask again, and read nothing into `dir_exists`
  /// until it is true. The agent polls the run for this request, which can
  /// take a while on a machine under load, hence the long timeout.
  getBenchmark: (signal?: AbortSignal) =>
    request<BenchView>('/benchmark', {}, signal, MACHINE_TIMEOUT_MS),
  /// One run in full, including yabs' `result_json` and the stored log.
  getBenchmarkRun: (id: string, signal?: AbortSignal) =>
    request<BenchDetail>(
      `/benchmark?run=${encodeURIComponent(id)}`,
      {},
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
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Stops the run that is going; a sleep sits between the TERM and the KILL.
  cancelBenchmark: () =>
    request<{ cancelled: boolean }>(
      '/benchmark',
      { method: 'POST', body: JSON.stringify({ action: 'cancel' }) },
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
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The machine's accounts, or one account's own records.
  getSystemUsers: (part: UserPart = 'list', name?: string) =>
    request<UserView>(
      `/system-users?${new URLSearchParams({ part, ...(name ? { name } : {}) })}`,
      {},
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
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The machine's firewall, the one `kind` names or the one the agent
  /// prefers. A POST: the `sudo` password a read may need
  /// travels in the body.
  getFirewall: (kind?: FirewallKind, password?: string) =>
    request<FirewallView>(
      '/firewall',
      { method: 'POST', body: JSON.stringify({ ...(kind ? { kind } : {}), ...(password ? { password } : {}) }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// What a change would run and do. Runs nothing; a change that cannot be
  /// made arrives as `ApiError.message` holding its code, a draft's or an
  /// input's issue as `body.issue`.
  planFirewall: (change: FirewallChange, password?: string) =>
    request<FirewallPlanResult>(
      '/firewall/plan',
      { method: 'POST', body: JSON.stringify({ ...change, ...(password ? { password } : {}) }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Makes a change. The agent reads the firewall again and plans it anew, so
  /// what runs is never the client's copy; `keep_open` runs the plan's
  /// keep-open rules first. A plan that asks runs only under the `planId` the
  /// user confirmed; otherwise the answer is `confirm_required` with the new
  /// plan, and nothing has run.
  actFirewall: (change: FirewallChange, keepOpen: boolean, password?: string, planId?: string) =>
    request<FirewallActResult>(
      '/firewall/act',
      {
        method: 'POST',
        body: JSON.stringify({
          ...change,
          keep_open: keepOpen,
          ...(password ? { password } : {}),
          ...(planId ? { plan_id: planId } : {}),
        }),
      },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The snippet library saved on the agent.
  getSnippets: () => request<SnippetsView>('/snippets', {}),
  /// Replaces the whole library, in the order given. A refusal arrives with
  /// its code as `ApiError.message` and the row as `body.index`.
  updateSnippets: (snippets: Snippet[]) =>
    request<SnippetsView>(
      '/snippets',
      { method: 'PUT', body: JSON.stringify({ snippets }) },
    ),
  /// What a script types, expanded by the agent. Runs nothing. The panel has
  /// no server values to offer, so the context is empty and a script naming
  /// one is refused with `body.key`.
  planSnippet: (script: string) =>
    request<SnippetPlan>(
      '/snippets/plan',
      { method: 'POST', body: JSON.stringify({ script, context: {} }) },
    ),
  /// The desktop routes saved on the agent.
  getBmc: () => request<BmcList>('/bmc', {}),
  /// Replaces the whole set. A refusal arrives with its code as
  /// `ApiError.message` and the row as `body.index`.
  updateBmc: (targets: BmcTargetInput[]) =>
    request<BmcList>('/bmc', { method: 'PUT', body: JSON.stringify({ targets }) }),
  probeBmc: (url: string) =>
    request<BmcCertInfo>(
      '/bmc/probe',
      { method: 'POST', body: JSON.stringify({ url }) },
    ),
  /// An upstream failure arrives as `ApiError` with `body.failure`.
  bmcStatus: (id: string) =>
    request<BmcStatus>(`/bmc/${encodeURIComponent(id)}`, {}),
  bmcPower: (id: string, intent: BmcIntent) =>
    request<{ outcome: { kind: 'done' | 'accepted' } }>(
      `/bmc/${encodeURIComponent(id)}/power`,
      { method: 'POST', body: JSON.stringify({ intent }) },
    ),
  /// The host and its guests. `password` is the operator's sudo password
  /// for a libvirt that refuses the agent's account: sent for this request,
  /// never stored. A host's failure is `error` in a 200, not an `ApiError`.
  loadVirt: (password?: string) =>
    request<VirtLoad>(
      '/virt',
      { method: 'POST', body: JSON.stringify({ password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Returns once the host has finished it (a PVE task stopped).
  virtPower: (guest: string, action: VirtPowerAction, password?: string) =>
    request<{ error: VirtError | null }>(
      '/virt/power',
      { method: 'POST', body: JSON.stringify({ guest, action, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtDetail: (guest: string, password?: string) =>
    request<{ detail: VirtGuestDetail | null; error: VirtError | null }>(
      '/virt/detail',
      { method: 'POST', body: JSON.stringify({ guest, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// `history: null` where the host keeps none (libvirt).
  virtHistory: (guest: string, window: VirtHistoryWindow) =>
    request<{ history: VirtStats[] | null; error: VirtError | null }>(
      '/virt/history',
      { method: 'POST', body: JSON.stringify({ guest, window }) },
    ),
  /// Resolves the console and mints the ticket its websocket opens with.
  virtConsole: (guest: string, kind: VirtConsoleKind, password?: string) =>
    request<VirtConsoleAnswer>(
      '/virt/console',
      { method: 'POST', body: JSON.stringify({ guest, kind, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtSnapshots: (guest: string, password?: string) =>
    request<VirtSnapshots>(
      '/virt/snapshots',
      { method: 'POST', body: JSON.stringify({ guest, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Returns once the host has finished it.
  virtSnapshot: (guest: string, op: VirtSnapshotOp, password?: string) =>
    request<{ error: VirtError | null }>(
      '/virt/snapshot',
      { method: 'POST', body: JSON.stringify({ guest, ...op, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtSnapshotDiff: (guest: string, name: string, password?: string) =>
    request<{ diff: VirtSnapDiff[] | null; error: VirtError | null }>(
      '/virt/snapshot/diff',
      { method: 'POST', body: JSON.stringify({ guest, name, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtStorage: (password?: string) =>
    request<{ pools: VirtPool[] | null; rules: Record<string, VirtPoolRule> | null; error: VirtError | null }>(
      '/virt/storage',
      { method: 'POST', body: JSON.stringify({ password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtVolumes: (pool: string, password?: string) =>
    request<{ volumes: VirtVolume[] | null; error: VirtError | null }>(
      '/virt/volumes',
      { method: 'POST', body: JSON.stringify({ pool, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtNetworks: (password?: string) =>
    request<{ networks: VirtNetwork[] | null; changes: VirtNetworkChanges[] | null; error: VirtError | null }>(
      '/virt/networks',
      { method: 'POST', body: JSON.stringify({ password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Checked against what the host lists now, then made; returns once the
  /// host has.
  virtManage: (change: VirtChange, password?: string) =>
    request<{ error: VirtError | null }>(
      '/virt/manage',
      { method: 'POST', body: JSON.stringify({ change, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// What a new guest of `kind` can be made of; PVE needs the `node`.
  createForm: (kind: VirtGuestKind, node?: string, password?: string) =>
    request<{ form: VirtCreateForm | null; error: VirtError | null }>(
      '/virt/create/form',
      { method: 'POST', body: JSON.stringify({ kind, node: node ?? null, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Checked against what the host lists now, then made; returns once the
  /// host has.
  createGuest: (spec: VirtCreateSpec, password?: string) =>
    request<{ created: VirtCreated | null; error: VirtError | null }>(
      '/virt/create',
      { method: 'POST', body: JSON.stringify({ spec, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// `removeDisks` is libvirt's choice; PVE deletes a guest's disks with it.
  deleteGuest: (guest: string, removeDisks: boolean, password?: string) =>
    request<{ error: VirtError | null }>(
      '/virt/delete',
      { method: 'POST', body: JSON.stringify({ guest, remove_disks: removeDisks, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Where a copy's disks can go.
  cloneForm: (guest: string, password?: string) =>
    request<{ storages: VirtPool[] | null; error: VirtError | null }>(
      '/virt/clone/form',
      { method: 'POST', body: JSON.stringify({ guest, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The copy's id once the host has made it.
  cloneGuest: (guest: string, cloneRequest: VirtCloneRequest, password?: string) =>
    request<{ id: string | null; error: VirtError | null }>(
      '/virt/clone',
      { method: 'POST', body: JSON.stringify({ guest, request: cloneRequest, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The guest's hardware as its next start gets it, with the `revision` an
  /// edit is sent back with.
  virtHardware: (guest: string, password?: string) =>
    request<{ hardware: VirtHardware | null; error: VirtError | null }>(
      '/virt/hardware',
      { method: 'POST', body: JSON.stringify({ guest, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// One change, made from the read whose `revision` it carries; an older
  /// one is answered `conflict`.
  virtHardwareChange: (guest: string, revision: string | null, change: VirtHwChange, password?: string) =>
    request<{ outcome: VirtHwOutcome | null; error: VirtError | null }>(
      '/virt/hardware/change',
      { method: 'POST', body: JSON.stringify({ guest, revision, change, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Every pending change dropped.
  virtHardwareRevert: (guest: string, revision: string | null, password?: string) =>
    request<{ error: VirtError | null }>(
      '/virt/hardware/revert',
      { method: 'POST', body: JSON.stringify({ guest, revision, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtCloudInit: (guest: string, password?: string) =>
    request<{ cloud_init: VirtCloudInitState | null; error: VirtError | null }>(
      '/virt/cloud-init',
      { method: 'POST', body: JSON.stringify({ guest, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// A typed password goes to the host only.
  virtSetCloudInit: (guest: string, edit: VirtCloudInitEdit, password?: string) =>
    request<{ error: VirtError | null }>(
      '/virt/cloud-init/set',
      { method: 'POST', body: JSON.stringify({ guest, edit, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The host's USB and PCI devices the guest can be given.
  virtHostDevices: (guest: string, password?: string) =>
    request<{ devices: VirtHostDevices | null; error: VirtError | null }>(
      '/virt/host-devices',
      { method: 'POST', body: JSON.stringify({ guest, password: password ?? null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// PVE only.
  makeTemplate: (guest: string) =>
    request<{ error: VirtError | null }>(
      '/virt/template',
      { method: 'POST', body: JSON.stringify({ guest }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// A guest's backups, the jobs that take it and its node's backup
  /// storages. PVE only; libvirt answers `backup_refused`.
  virtBackups: (guest: string) =>
    request<VirtBackups>(
      '/virt/backups',
      { method: 'POST', body: JSON.stringify({ guest }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Returns once the host has finished it.
  virtBackup: (guest: string, backupRequest: VirtBackupRequest) =>
    request<{ error: VirtError | null }>(
      '/virt/backup',
      { method: 'POST', body: JSON.stringify({ guest, request: backupRequest }) },
      undefined,
      TASK_TIMEOUT_MS,
    ),
  /// Over the guest itself (stopped) without `vmid`, else as a new guest.
  /// Returns once the host has finished it.
  virtRestoreBackup: (guest: string, backup: string, target: { vmid?: number; storage?: string } = {}) =>
    request<{ error: VirtError | null }>(
      '/virt/backup/restore',
      { method: 'POST', body: JSON.stringify({ guest, backup, ...target }) },
      undefined,
      TASK_TIMEOUT_MS,
    ),
  virtEditBackup: (guest: string, backup: string, edit: VirtBackupEdit) =>
    request<{ error: VirtError | null }>(
      '/virt/backup/edit',
      { method: 'POST', body: JSON.stringify({ guest, backup, edit }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  virtDeleteBackup: (guest: string, backup: string) =>
    request<{ error: VirtError | null }>(
      '/virt/backup/delete',
      { method: 'POST', body: JSON.stringify({ guest, backup }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// The datacenter's backup jobs and every node's backup storages.
  backupJobs: () =>
    request<VirtBackupJobs>(
      '/virt/backup-jobs',
      { method: 'POST', body: '{}' },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// Made (`is_new`), edited, or with `remove` deleted.
  editBackupJob: (edit: VirtBackupJobEdit, remove = false) =>
    request<{ error: VirtError | null }>(
      '/virt/backup-jobs/edit',
      { method: 'POST', body: JSON.stringify({ edit, remove }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  /// "Run now": returns once every node's backup has finished.
  runBackupJob: (id: string) =>
    request<{ error: VirtError | null }>(
      '/virt/backup-jobs/run',
      { method: 'POST', body: JSON.stringify({ id }) },
      undefined,
      TASK_TIMEOUT_MS,
    ),
  /// What the host makes of a schedule: its next runs or its refusal.
  checkBackupSchedule: (schedule: string) =>
    request<{ check: VirtScheduleCheck | null; error: VirtError | null }>(
      '/virt/backup-jobs/schedule',
      { method: 'POST', body: JSON.stringify({ schedule }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  getPve: () => request<PveConfigView>('/virt/pve', {}),
  /// A refusal arrives with its code as `ApiError.message`.
  setPve: (config: PveConfigInput) =>
    request<PveConfigView>('/virt/pve', { method: 'PUT', body: JSON.stringify(config) }),
  removePve: () => request<PveConfigView>('/virt/pve', { method: 'DELETE' }),
  pinPve: (fingerprint: string) =>
    request<{ error: VirtError | null }>(
      '/virt/pve/cert',
      { method: 'POST', body: JSON.stringify({ fingerprint }) },
    ),
  pveTfa: (code: string) =>
    request<{ error: VirtError | null }>(
      '/virt/pve/tfa',
      { method: 'POST', body: JSON.stringify({ code }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  getBackups: () => request<BackupView>('/backup', {}),
  /// The blob's bytes, as stored. The panel has no key for what is in them.
  downloadBackup: async (name: string): Promise<Blob> => {
    const res = await fsBytes(
      `/backup/blob?name=${encodeURIComponent(name)}`,
      {},
    )
    return res.blob()
  },
  uploadBackup: async (name: string, body: Blob): Promise<void> => {
    await fsBytes(
      `/backup/blob?name=${encodeURIComponent(name)}`,
      { method: 'PUT', body, headers: { 'Content-Type': 'application/octet-stream' } },
    )
  },
  deleteBackup: async (name: string): Promise<void> => {
    await fsBytes(
      `/backup/blob?name=${encodeURIComponent(name)}`,
      { method: 'DELETE' },
    )
  },
  getDesktops: () => request<DesktopsView>('/desktops', {}),
  /// Replaces the whole set, in order. A refusal arrives with its code as
  /// `ApiError.message` and the row as `body.index`.
  updateDesktops: (desktops: Desktop[]) =>
    request<DesktopsView>(
      '/desktops',
      { method: 'PUT', body: JSON.stringify({ desktops }) },
    ),
  /// Shuts the machine down, reboots or suspends it. The password is for
  /// `sudo -S` and travels as its own field, never inside a command.
  power: (action: PowerAction, password?: string) =>
    request<PowerResult>(
      '/power',
      { method: 'POST', body: JSON.stringify({ action, password: password || null }) },
      undefined,
      MACHINE_TIMEOUT_MS,
    ),
  getSettings: () => request<SettingsView>('/settings', {}),
  updateSettings: (payload: SettingsPayload) =>
    request<{ status: string }>(
      '/settings',
      { method: 'PUT', body: JSON.stringify(payload) },
    ),
  /// Exchanges the session token for a single-use ticket authorising one
  /// WebSocket upgrade. A browser can't put a bearer token on a WebSocket
  /// handshake, and a token in the query string would land in the agent's
  /// access log; the ticket is good for one connection and ~30 seconds.
  issueWsTicket: (purpose: WsTicketPurpose) =>
    request<WsTicketResponse>(
      '/ws-ticket',
      { method: 'POST', body: JSON.stringify({ purpose }) },
    ),
  /// Where browsing starts: the agent account's home, then `/` (drive
  /// letters on Windows).
  fsRoots: (signal?: AbortSignal) =>
    request<FsRootsResponse>('/fs/roots', {}, signal),
  fsList: (path: string, signal?: AbortSignal) =>
    request<FsEntry[]>(
      `/fs/list?path=${encodeURIComponent(path)}`,
      {},
      signal,
    ),
  fsStat: (path: string, signal?: AbortSignal) =>
    request<FsEntry>(
      `/fs/stat?path=${encodeURIComponent(path)}`,
      {},
      signal,
    ),
  /// The bytes, as a blob the browser can be handed. There is no `<a download>`
  /// shortcut here: the endpoint wants a bearer token, and a URL cannot carry
  /// one without putting it in the agent's access log.
  fsRead: async (path: string, signal?: AbortSignal): Promise<Blob> => {
    const res = await fsBytes(
      `/fs/read?path=${encodeURIComponent(path)}`,
      {},
      signal,
    )
    return res.blob()
  },
  /// Writes a file. [ifVersion] is the `version` token the caller read with
  /// `fsStat`/`fsList`: the agent answers 409 and writes nothing when the file
  /// has moved on, so an editor can offer to overwrite rather than silently
  /// losing a change someone else made. A plain upload states nothing and
  /// overwrites.
  fsWrite: async (
    path: string,
    body: Blob,
    signal?: AbortSignal,
    ifVersion?: string | null,
  ): Promise<void> => {
    const query = new URLSearchParams({ path })
    if (ifVersion !== undefined && ifVersion !== null) {
      query.set('if_version', ifVersion)
    }
    try {
      await fsBytes(
        `/fs/write?${query}`,
        { method: 'PUT', body, headers: { 'Content-Type': 'application/octet-stream' } },
        signal,
      )
    } catch (e) {
      // `modified` as a code, so a caller can tell this conflict from any other
      // failure. The endpoint's older error shape carries it in `error`, which
      // `errorFrom` reads as the message rather than as a code.
      if (e instanceof ApiError && e.status === 409) {
        throw new ApiError('modified', 409, 'modified')
      }
      throw e
    }
  },
  fsMkdir: (path: string) =>
    request<unknown>(
      '/fs/mkdir',
      { method: 'POST', body: JSON.stringify({ path }) },
    ),
  fsRename: (from: string, to: string) =>
    request<unknown>(
      '/fs/rename',
      { method: 'POST', body: JSON.stringify({ from, to }) },
    ),
  fsChmod: (path: string, mode: number) =>
    request<unknown>(
      '/fs/chmod',
      { method: 'POST', body: JSON.stringify({ path, mode }) },
    ),
  fsRemove: (path: string, recursive: boolean) =>
    request<unknown>(
      '/fs/remove',
      { method: 'DELETE', body: JSON.stringify({ path, recursive }) },
    ),
  getCustomCmds: () =>
    request<CustomCmdsView>('/custom-cmds', {}),
  /// The whole set, in the order it should run in. A replace rather than a
  /// per-command edit: the order is part of what is stored, so a move has no
  /// smaller expression than the new list.
  updateCustomCmds: (commands: CustomCmd[]) =>
    request<CustomCmdsView>(
      '/custom-cmds',
      { method: 'PUT', body: JSON.stringify({ commands }) },
    ),
  getPush: () => request<PushListView>('/push', {}),
  /// The whole set, in order, like the custom commands. Each entry carries the
  /// `from_index` it was loaded at, which is the only thing a withheld
  /// credential (a `null` value) can be resolved against — see `PushEntry`.
  updatePush: (payload: PushPayload) =>
    request<PushListView>(
      '/push',
      { method: 'PUT', body: JSON.stringify(payload) },
    ),
  /// Sends one notification now, through the channel as currently edited. A
  /// channel that cannot be tried is one whose first real alert is where it
  /// gets found out. The agent answers 200 with `ok: false` for a delivery
  /// that failed, so only a refused *request* throws here.
  testPush: (push: PushEntry, message: string) =>
    request<PushTestResult>(
      '/push/test',
      { method: 'POST', body: JSON.stringify({ push, message }) },
    ),
  changeMyPassword: (current_password: string, new_password: string) =>
    request<void>(
      '/me/password',
      { method: 'PUT', body: JSON.stringify({ current_password, new_password }) },
    ),
  /// Desk apps installed on the agent (`api::apps`), approved or waiting.
  listApps: () => request<{ apps: InstalledApp[] }>('/apps', {}),
  /// The web apps the agent can deploy (`api::stacks`), and their state.
  listStacks: () => request<{ apps: StackApp[] }>('/stacks', {}),
  /// The catalog read again from its repositories now.
  refreshStacks: () => request<{ apps: StackApp[] }>('/stacks/refresh', { method: 'POST' }),
  prepareStack: (id: string) =>
    request<StackPrepare>(`/stacks/${encodeURIComponent(id)}/prepare`, {}),
  checkStack: (id: string, settings: Record<string, StackValue>) =>
    request<StackPreview>(
      `/stacks/${encodeURIComponent(id)}/check`,
      { method: 'POST', body: JSON.stringify({ settings }) },
    ),
  /// Deploys with what the account confirmed: that it installs third-party
  /// software, and the licence where the manifest asks.
  installStack: (
    id: string,
    settings: Record<string, StackValue>,
    consent: { acknowledged: boolean; acceptLicense: boolean },
    currentPassword: string,
  ) =>
    request<StackJob>(
      `/stacks/${encodeURIComponent(id)}`,
      {
        method: 'POST',
        body: JSON.stringify({
          settings,
          acknowledged: consent.acknowledged,
          accept_license: consent.acceptLicense,
          current_password: currentPassword,
        }),
      },
    ),
  /// New settings for a deployed app: it is deployed again with them.
  reconfigureStack: (id: string, settings: Record<string, StackValue>, currentPassword: string) =>
    request<StackJob>(
      `/stacks/${encodeURIComponent(id)}/settings`,
      { method: 'PUT', body: JSON.stringify({ settings, current_password: currentPassword }) },
    ),
  stackAction: (id: string, action: 'start' | 'stop' | 'restart' | 'update') =>
    request<StackJob>(
      `/stacks/${encodeURIComponent(id)}/action`,
      { method: 'POST', body: JSON.stringify({ action }) },
    ),
  /// How to sign in to deployed app [id] the first time, its password read.
  stackLogin: (id: string, currentPassword: string) =>
    request<{ user?: string | null; password?: string | null; note?: Record<string, string> | null }>(
      `/stacks/${encodeURIComponent(id)}/login`,
      { method: 'POST', body: JSON.stringify({ current_password: currentPassword }) },
    ),
  removeStack: (id: string, purge: boolean, currentPassword: string) =>
    request<StackJob>(
      `/stacks/${encodeURIComponent(id)}`,
      { method: 'DELETE', body: JSON.stringify({ purge, current_password: currentPassword }) },
    ),
  listContainerBackups: () =>
    request<{
      backups: ContainerBackup[]
      job: StackJob | null
      settings: ContainerBackupSettings
      folder: string
      default_folder: string
      free_bytes: number | null
      schedules: ContainerBackupSchedule[]
    }>('/container-backups', {}),
  setContainerBackupSettings: (settings: ContainerBackupSettings) =>
    request<ContainerBackupSettings>(
      '/container-backups/settings',
      { method: 'PUT', body: JSON.stringify(settings) },
    ),
  addContainerBackupSchedule: (schedule: Omit<ContainerBackupSchedule, 'id' | 'label' | 'last_run' | 'last_error'>) =>
    request<ContainerBackupSchedule>(
      '/container-backups/schedules',
      { method: 'POST', body: JSON.stringify(schedule) },
    ),
  removeContainerBackupSchedule: (id: string) =>
    request<void>(`/container-backups/schedules/${encodeURIComponent(id)}`, { method: 'DELETE' }),
  getStorage: () => request<StorageView>('/storage', {}),
  /// One change, run as root as a job; [sudoPassword] when sudo asks,
  /// [passphrase] for an encrypted format or an unlock.
  storageAct: (action: StorageAction, sudoPassword: string, passphrase?: string) =>
    request<StackJob>(
      '/storage/act',
      { method: 'POST', body: JSON.stringify({ ...action, sudo_password: sudoPassword || null, passphrase: passphrase || null }) },
    ),
  /// Every disk's SMART, read as root; without [sudoPassword], only where
  /// sudo needs none (403 `sudo_rejected` otherwise).
  storageHealth: (sudoPassword = '') =>
    request<HealthReading>(
      '/storage/health',
      { method: 'POST', body: JSON.stringify({ sudo_password: sudoPassword || null }) },
    ),
  /// One maintenance task's schedule; [every] null turns it off.
  setStorageMaintenance: (task: MaintenanceKind, every: 'weekly' | 'monthly' | null, at: string, day: number) =>
    request<{ maintenance: MaintenanceTask[] }>(
      '/storage/maintenance',
      { method: 'PUT', body: JSON.stringify({ task, every, at, day }) },
    ),
  /// Runs a scheduled task now, as the schedule would.
  runStorageMaintenance: (task: MaintenanceKind) =>
    request<{ maintenance: MaintenanceTask[] }>(`/storage/maintenance/${task}/run`, { method: 'POST' }),
  getShares: () => request<SharesView>('/shares', {}),
  shareConnections: (sudoPassword = '') =>
    request<ShareConnections>(
      '/shares/connections',
      { method: 'POST', body: JSON.stringify({ sudo_password: sudoPassword || null }) },
    ),
  /// Every SMB share ServerBox keeps, written as root.
  setSmbShares: (shares: SmbShare[], sudoPassword: string) =>
    request<SharesView>('/shares/smb', { method: 'PUT', body: JSON.stringify({ shares, sudo_password: sudoPassword || null }) }),
  /// Every NFS export ServerBox keeps, written as root.
  setNfsExports: (exports: NfsExport[], sudoPassword: string) =>
    request<SharesView>('/shares/nfs', { method: 'PUT', body: JSON.stringify({ exports, sudo_password: sudoPassword || null }) }),
  setSmbPassword: (user: string, password: string, sudoPassword: string) =>
    request<void>(
      '/shares/smb/password',
      { method: 'POST', body: JSON.stringify({ user, password, sudo_password: sudoPassword || null }) },
    ),
  /// Samba ([nfs] false) or the NFS server, installed as a job.
  installShares: (nfs: boolean, sudoPassword: string) =>
    request<StackJob>('/shares/install', { method: 'POST', body: JSON.stringify({ nfs, sudo_password: sudoPassword || null }) }),
  sharesJob: (since: number) => request<StackJob>(`/shares/job?since=${since}`, {}),
  storageJob: (since: number) => request<StackJob>(`/storage/job?since=${since}`, {}),
  /// Backs up [containers] (with [project], their whole compose project).
  createContainerBackup: (containers: string[], project: boolean, stop: boolean) =>
    request<StackJob>(
      '/container-backups',
      { method: 'POST', body: JSON.stringify({ containers, project, stop }) },
    ),
  containerBackupJob: (since: number) =>
    request<StackJob>(`/container-backups/job?since=${since}`, {}),
  cancelContainerBackupJob: () => request<void>('/container-backups/job/cancel', { method: 'POST' }),
  restoreContainerBackup: (id: string, currentPassword: string) =>
    request<StackJob>(
      `/container-backups/${encodeURIComponent(id)}/restore`,
      { method: 'POST', body: JSON.stringify({ current_password: currentPassword }) },
    ),
  removeContainerBackup: (id: string, currentPassword: string) =>
    request<void>(
      `/container-backups/${encodeURIComponent(id)}`,
      { method: 'DELETE', body: JSON.stringify({ current_password: currentPassword }) },
    ),
  stackJob: (id: string, since: number) =>
    request<StackJob>(`/stacks/${encodeURIComponent(id)}/job?since=${since}`, {}),
  cancelStackJob: (id: string) =>
    request<void>(`/stacks/${encodeURIComponent(id)}/job/cancel`, { method: 'POST' }),
  stackServices: (id: string) =>
    request<{ services: StackService[] }>(`/stacks/${encodeURIComponent(id)}/services`, {}),
  enterStack: (id: string) =>
    request<StackEntry>(`/stacks/${encodeURIComponent(id)}/enter`, { method: 'POST' }),
  /// Uploads a package (`.fsba`); it waits for approval.
  async installApp(file: Blob): Promise<InstalledApp> {
    const res = await fsBytes(
      '/apps',
      { method: 'POST', body: file, headers: { 'Content-Type': 'application/gzip' } },
      AbortSignal.timeout(120_000),
    )
    return res.json() as Promise<InstalledApp>
  },
  approveApp: (id: string, sha256: string, permissions: string[], currentPassword: string) =>
    request<InstalledApp>(
      `/apps/${encodeURIComponent(id)}/approval`,
      { method: 'PUT', body: JSON.stringify({ sha256, permissions, current_password: currentPassword }) },
    ),
  removeApp: (id: string, currentPassword: string) =>
    request<void>(
      `/apps/${encodeURIComponent(id)}`,
      { method: 'DELETE', body: JSON.stringify({ current_password: currentPassword }) },
    ),
  getCardOrder: () => request<CardOrderPayload>('/card-order', {}),
  updateCardOrder: (card_order: string[]) =>
    request<{ status: string }>(
      '/card-order',
      { method: 'PUT', body: JSON.stringify({ card_order }) },
    ),
}
