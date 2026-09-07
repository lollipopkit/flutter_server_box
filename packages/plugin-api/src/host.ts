/**
 * The `sb` object, which is everything outside the plugin.
 *
 * PLUGINS.md section 4.3. Anything that goes through the app answers a
 * `Promise`; the two that read instance-local state are synchronous.
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
  /** A short machine-readable tag — `io`, `timeout`, `cert`, `decode`. */
  kind: string;
}

// -------------------------------------------------------------------- exec

export interface ExecRequest {
  server: ServerHandle;
  script: string;
  timeoutMs?: number;
}

export interface ExecResponse {
  code: number;
  stdout: string;
  stderr: string;
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
  fields?: PromptField[];
  /** The confirming button's label. Defaults to the app's own. */
  confirm?: string;
}

export interface PromptAnswer {
  cancelled: boolean;
  values: Record<string, string>;
}

// -------------------------------------------------------------- namespaces

export interface Server {
  exec(req: ExecRequest): Promise<ExecResponse>;
}

export interface Http {
  fetch(req: HttpRequest): Promise<HttpResponse>;
}

export interface Ui {
  /**
   * Replaces the subtree the JSON Pointer names in this surface's last tree.
   *
   * For a long-running task, so a plugin streaming a log does not resend the
   * page per line.
   */
  patch(path: string, node: Node): Promise<void>;

  /** Raises a dialog and waits. Needs `ui.dialog`. */
  prompt(spec: PromptSpec): Promise<PromptAnswer>;

  /** Cancelled answers `null`. The returned handle may then be used. */
  pickServer(): Promise<ServerHandle | null>;

  toast(text: string, kind?: ToastKind): Promise<void>;
}

export interface Store {
  get(scope: Scope, key: string): Promise<string | null>;
  /** A `null` value deletes. */
  set(scope: Scope, key: string, value: string | null): Promise<void>;
  list(scope: Scope, prefix: string): Promise<string[]>;
}

export interface Diag {
  /**
   * Records that something happened, never what.
   *
   * The host keeps the name and the level and decides what else is safe to
   * keep, so do not put a value in the name.
   */
  crumb(name: string, level?: "info" | "warning"): Promise<void>;
}

export interface Nav {
  openServer(server: ServerHandle): Promise<void>;
  goTab(tab: string): Promise<void>;
}

export interface Clipboard {
  read(): Promise<string | null>;
  write(text: string): Promise<void>;
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
