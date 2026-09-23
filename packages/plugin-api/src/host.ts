/**
 * The `sb` object, which is everything outside the plugin.
 *
 * PLUGINS.md section 4.3. Anything that goes through the app answers a
 * `Promise`; the two that read instance-local state are synchronous.
 *
 * **Every function takes one object and answers one object.** That is what the
 * host implements — a host call carries a single JSON value in each direction
 * — so a positional signature here would describe an interface that does not
 * exist, and a plugin written against it would fail on a device after passing
 * its own tests.
 *
 * A namespace exists whether or not its functions are granted. Calling one the
 * manifest did not ask for throws an `Error` whose `name` is
 * `PermissionDenied` — there is nothing useful to do with it except report, and
 * the host records it either way.
 */

// ------------------------------------------------------------------ shared

/**
 * A server the host handed out.
 *
 * Opaque on purpose: a plugin cannot construct one, and that is the whole of
 * "a plugin acts only on servers it was given". The two sources are the bound
 * server in {@link InitCtx} and {@link Ui.pickServer}.
 */
export type ServerHandle = string & { readonly __sb: unique symbol };

/** Which key-value namespace a value belongs to. */
export type Scope =
  /** Shared by every instance of this plugin. Where a list of accounts goes. */
  | "global"
  /** This instance's bound server only. */
  | "server";

/** What the app could not do. Rejected promises carry one of these. */
export interface HostError extends Error {
  name: "HostError";
  /**
   * A short machine-readable tag — `io`, `timeout`, `cert`, `decode`,
   * `cancelled`.
   */
  kind: string;
  /**
   * Whether the command is still running on the server.
   *
   * Set on `cancelled` and `timeout` from {@link Server.exec}, and on nothing
   * else. See {@link RemoteState}.
   */
  remote?: RemoteState;
}

// -------------------------------------------------------------------- exec

/**
 * What became of the command after the app stopped waiting for it.
 *
 * The two are not the same thing and the app cannot make them the same: an SSH
 * channel carries a signal, so cancelling really ends the command; one HTTP
 * request to a monitor agent has nothing to signal down, so the agent goes on
 * running it until its own timeout. A plugin that says "stopped" over the
 * second case has told somebody their server is idle while it walks a
 * filesystem.
 */
export type RemoteState =
  /** It was stopped there. Nothing is left running. */
  | "stopped"
  /** Only the waiting stopped. It is still running, and its output goes nowhere. */
  | "running";

export interface ExecRequest {
  server: ServerHandle;
  script: string;

  /**
   * How long to wait. The app applies five minutes when this is absent —
   * there is always a bound, because a plugin holding a host call for ever is
   * a surface that never draws again.
   *
   * Running out rejects with `kind: "timeout"`, carrying
   * {@link HostError.remote}.
   */
  timeoutMs?: number;

  /**
   * A label this plugin picks. `sb.server.cancel({key})` stops every run
   * carrying it.
   *
   * A label rather than something the call hands back, because the two moments
   * do not meet: a scan is started by `onHook` and stopped by a button several
   * draws later, and nothing is shared between them. Two runs may carry one
   * label on purpose — a fleet-wide surface asking twenty machines the same
   * question stops all twenty at once.
   *
   * Scoped to this surface. A label is a string the plugin made up, so it
   * reaches nothing another plugin — or another surface of this one — started.
   */
  cancelKey?: string;
}

export interface ExecResponse {
  code: number;
  stdout: string;
  stderr: string;
}

export interface CancelRequest {
  /** The {@link ExecRequest.cancelKey} of the runs to stop. */
  key: string;
}

export interface CancelResult {
  /**
   * How many runs the key reached.
   *
   * Zero is ordinary rather than a failure: a Stop pressed as the answer came
   * back names nothing, and the page is already showing the result.
   */
  stopped: number;
}

// -------------------------------------------------------------------- http

/** Straight out of the device, or through the bound server's SSH connection. */
export type Via = "direct" | "ssh";

/**
 * How a body is carried.
 *
 * Text by default: nearly every body a plugin sends or receives is UTF-8, and
 * base64 costs something on an interpreter.
 */
export type BodyEncoding = "utf8" | "base64";

export interface HttpRequest {
  url: string;
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  bodyEncoding?: BodyEncoding;

  /** `"ssh"` needs the `server.stream` permission as well as `net.http`. */
  via?: Via;
  /** Required when `via` is `"ssh"`. */
  server?: ServerHandle;

  /**
   * SHA-256 of the DER form of the certificate the peer must present,
   * lowercase hex.
   *
   * Absent refuses every certificate, unless {@link probeCert} is set. That is
   * deliberate: the alternative is trusting whatever answers the first time a
   * request is made, and by then the request carries a password.
   */
  pinSha256?: string;

  /**
   * Read the certificate and send nothing.
   *
   * The review half of trust-on-first-use, which cannot be a callback: TLS
   * verification is synchronous and there is no opening to ask a user from
   * inside it. The host refuses this alongside a body or a header — what makes
   * accepting any certificate safe here is that nothing is sent.
   */
  probeCert?: boolean;

  timeoutMs?: number;
}

/**
 * A certificate as it is shown to somebody deciding whether to trust it.
 *
 * The fingerprint alone is unreadable, and a person comparing one against a
 * BMC's own web interface needs the rest to know they are looking at the same
 * thing.
 */
export interface CertInfo {
  /** Lowercase hex, SHA-256 of the DER form. */
  sha256: string;
  subject: string;
  issuer: string;
  /** RFC 3339, or empty where the host could not read it. */
  notBefore: string;
  notAfter: string;
  /**
   * Worth showing rather than acting on: BMCs are routinely shipped with
   * certificates that expired years ago.
   */
  expired: boolean;
}

export interface HttpResponse {
  status: number;
  headers: Record<string, string>;
  body: string;
  bodyEncoding: BodyEncoding;
  /** Present on a probe, and on an ordinary request that got that far. */
  cert?: CertInfo;
}

// ---------------------------------------------------------------------- ui

export type ToastKind = "info" | "success" | "warn" | "error";

export interface PromptField {
  key: string;
  label: string;
  /** Never pre-filled by the host. See {@link PromptSpec}. */
  secret?: boolean;
  /**
   * What the box starts with.
   *
   * A `secret` field with one has put a stored password on screen, which is
   * what marking it secret was for — so leave it unset there, and read an
   * untouched box as "leave it as it was".
   */
  value?: string;
}

export interface PromptSpec {
  title: string;
  message?: string;
  /** The shorthand: a row of text boxes, keyed by {@link PromptField.key}. */
  fields?: PromptField[];
  /**
   * The general case: a body you drew, using the same nodes as a surface.
   *
   * **Values come back keyed by each control's `change` message**, which must
   * be a string — the plugin is blocked while the dialog is up and cannot
   * process events, so the app holds what the controls say and hands the map
   * back. A control with no `onChange` is not a field.
   *
   * ```ts
   * const answer = await sb.ui.prompt({
   *   title: l10n("addTitle"),
   *   node: column([
   *     onChange(input(job.when, { hint: l10n("fieldWhen") }), "when"),
   *     onChange(input(job.command, { lines: 3 }), "command"),
   *     onChange(segmented(kind, [{ value: "cron" }, { value: "timer" }]), "kind"),
   *   ]),
   * });
   * if (!answer.cancelled) save(answer.values.when, answer.values.command);
   * ```
   */
  node?: Node;
  /** The confirming button's label. Defaults to the app's own. */
  confirm?: string;
  /**
   * `sheet` raises it from the bottom instead — where a form belongs on a
   * phone, since the keyboard has somewhere to go.
   */
  as?: "dialog" | "sheet";
}

export interface PromptAnswer {
  cancelled: boolean;
  values: Record<string, string>;
}

// -------------------------------------------------------------- namespaces

/** One server, as a plugin is allowed to see it. */
export interface ServerSummary {
  server: ServerHandle;
  name: string;
}

export interface Server {
  /**
   * Runs a command and collects what it printed.
   *
   * Rejects rather than resolving when the run was stopped — by
   * {@link Server.cancel} (`kind: "cancelled"`) or by
   * {@link ExecRequest.timeoutMs} (`kind: "timeout"`). Rejected on purpose: a
   * stopped `du` has a *prefix* of its output, and resolving with it would let
   * a plugin that does not check an extra field draw a partial reading as a
   * complete one.
   *
   * ```ts
   * try {
   *   const r = await sb.server.exec({ server, script, cancelKey: "scan" });
   * } catch (e) {
   *   const { kind, remote } = classify(e);
   *   if (kind === "cancelled" && remote === "running") {
   *     // Say so. The command is still walking that filesystem.
   *   }
   * }
   * ```
   */
  exec(req: ExecRequest): Promise<ExecResponse>;

  /**
   * Stops every run this surface started under {@link ExecRequest.cancelKey}.
   *
   * Needs `server.exec`, which is the same grant that started them.
   *
   * **It stops the app waiting. Whether it stops the command depends on how
   * the server is reached** — see {@link RemoteState}. The cancelled run's
   * rejection is where that answer arrives, not here: one key may cover
   * several machines reached different ways.
   */
  cancel(req: CancelRequest): Promise<CancelResult>;

  /**
   * Every server the user has, in the order the server tab shows them.
   *
   * Needs the `server.list` permission, which is **not** part of
   * `server.exec`: exec acts on a machine the user pointed at — the one a
   * surface is bound to, or one picked in {@link Ui.pickServer} — and this
   * hands over the whole list with nobody choosing. A plugin that only draws a
   * card for the machine in front of you does not need it and should not ask.
   *
   * Handles and names, and nothing else. There is no address in here and no
   * permission that adds one: reaching a server goes through
   * {@link Server.exec}, which goes through the app.
   */
  list(): Promise<{ servers: ServerSummary[] }>;
}

export interface Http {
  fetch(req: HttpRequest): Promise<HttpResponse>;
}

export interface PatchRequest {
  /** A JSON Pointer into this surface's last tree. */
  path: string;
  node: Node;
}

export interface ToastRequest {
  text: string;
  kind?: ToastKind;
}

/** What {@link Ui.pickServer} answers: one of the two, never both. */
export interface PickedServer {
  server?: ServerHandle;
  cancelled?: boolean;
}

export interface Ui {
  /**
   * Replaces the subtree the JSON Pointer names in this surface's last tree.
   *
   * For a long-running task, so a plugin streaming a log does not resend the
   * page per line. Rejects with `no_surface` when nothing is showing this
   * instance, which is how a plugin streaming a log can tell nobody is
   * watching.
   */
  patch(req: PatchRequest): Promise<void>;

  /** Raises a dialog and waits. Needs `ui.dialog`. */
  prompt(spec: PromptSpec): Promise<PromptAnswer>;

  /** `{server}` when one was chosen, `{cancelled: true}` when not. */
  pickServer(): Promise<PickedServer>;

  toast(req: ToastRequest): Promise<void>;
}

export interface StoreGetRequest {
  scope: Scope;
  key: string;
}

export interface StoreSetRequest {
  scope: Scope;
  key: string;
  /** `null` deletes. */
  value: string | null;
}

export interface StoreListRequest {
  scope: Scope;
  prefix: string;
}

export interface Store {
  /** `{value}`, which is `null` for a key that is not there. */
  get(req: StoreGetRequest): Promise<{ value: string | null }>;
  set(req: StoreSetRequest): Promise<void>;
  list(req: StoreListRequest): Promise<{ keys: string[] }>;
}

export interface CrumbRequest {
  /**
   * What happened, never what it was about.
   *
   * The host keeps this and the level and decides what else is safe to keep,
   * so do not put a value in the name.
   */
  name: string;
  level?: "info" | "warning";
}

export interface Diag {
  crumb(req: CrumbRequest): Promise<void>;
}

export interface OpenTerminalRequest {
  server: ServerHandle;

  /** Typed into the terminal. Absent opens an empty one. */
  cmd?: string;

  /**
   * Whether the command is sent as well as typed.
   *
   * Defaults to false, and that is the point of the call: the user reads the
   * line, edits it if they like, and presses enter. A plugin that wants a
   * command's output rather than a session the user watches has
   * {@link Server.exec}.
   */
  run?: boolean;
}

export interface Nav {
  openServer(req: { server: ServerHandle }): Promise<void>;

  /** Needs `server.exec` — causing commands to run on a machine is the same
   * capability whoever types them. */
  openTerminal(req: OpenTerminalRequest): Promise<void>;

  goTab(req: { tab: string }): Promise<void>;
}

export interface Clipboard {
  /** `{text}`, which is `null` when there is nothing to read. */
  read(): Promise<{ text: string | null }>;
  write(req: { text: string }): Promise<void>;
}

export interface Config {
  /** Plugin settings plus this server's config for this plugin. */
  get(key: string): string | undefined;
}

export interface Log {
  trace(message: string): void;
  debug(message: string): void;
  info(message: string): void;
  warn(message: string): void;
  error(message: string): void;
}

/** Everything outside the plugin. */
export interface Sb {
  readonly server: Server;
  readonly http: Http;
  readonly ui: Ui;
  readonly store: Store;
  readonly diag: Diag;
  readonly nav: Nav;
  readonly clipboard: Clipboard;
  readonly config: Config;
  readonly log: Log;
}

declare global {
  // eslint-disable-next-line no-var
  var sb: Sb;
}

// Imported for the doc links above; erased at build time.
import type { Node } from "./ui.ts";
import type { InitCtx } from "./plugin.ts";
export type { InitCtx, Node };
