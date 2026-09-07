/**
 * A host made of a script, for testing a plugin without the app.
 *
 * PLUGINS.md section 12: the test acts as the shell. A plugin runs a whole
 * interaction — a login, a poll, an action and its confirmation — with nothing
 * underneath it, and what it asked the host for is asserted rather than mocked
 * away. No QuickJS, no Flutter, no build step: `bun test` and the plugin's own
 * module.
 *
 * Import from `@serverbox/plugin-api/test`. It is not part of the plugin API
 * and never reaches a published plugin.
 */

import type {
  CertInfo,
  ExecRequest,
  ExecResponse,
  HttpRequest,
  HttpResponse,
  PromptAnswer,
  PromptSpec,
  Sb,
  Scope,
  ServerHandle,
  ToastKind,
} from "./host.ts";
import { L10N_ARG_SEP, type Node } from "./ui.ts";

export type LogLevel = "trace" | "debug" | "info" | "warn" | "error";

/** One thing the plugin asked the host to do. */
export type Recorded =
  | { fn: "server.exec"; req: ExecRequest }
  | { fn: "http.fetch"; req: HttpRequest }
  | { fn: "ui.patch"; path: string; node: Node }
  | { fn: "ui.prompt"; spec: PromptSpec }
  | { fn: "ui.pickServer" }
  | { fn: "ui.toast"; text: string; kind: ToastKind }
  | { fn: "store.get"; scope: Scope; key: string }
  | { fn: "store.set"; scope: Scope; key: string; value: string | null }
  | { fn: "store.list"; scope: Scope; prefix: string }
  | { fn: "diag.crumb"; name: string }
  | { fn: "nav.openServer"; server: ServerHandle }
  | { fn: "nav.goTab"; tab: string }
  | { fn: "clipboard.read" }
  | { fn: "clipboard.write"; text: string };

/** A canned HTTP answer. */
export interface Reply {
  status?: number;
  headers?: Record<string, string>;
  body?: string;
  cert?: Partial<CertInfo> & { sha256: string };
  /** Answered instead of a response, the way the app reports a failure. */
  error?: { kind: string; message: string };
}

export interface MockOptions {
  /** What `sb.config.get` answers. */
  config?: Record<string, string>;
  /** Seeds the global key-value namespace. */
  global?: Record<string, string>;
  /** Seeds this server's key-value namespace. */
  server?: Record<string, string>;
  /**
   * Permissions the manifest did *not* ask for.
   *
   * Calling one throws the way the real host does, so a plugin that reaches
   * past its manifest fails in a test rather than on a device.
   */
  denied?: string[];
}

function hostError(kind: string, message: string): Error {
  const e = new Error(message) as Error & { kind: string };
  e.name = "HostError";
  e.kind = kind;
  return e;
}

function denied(fn: string, permission: string): Error {
  const e = new Error(`permission denied: sb.${fn} needs \`${permission}\``);
  e.name = "PermissionDenied";
  return e;
}

/** Which permission each function needs, matching `hostfn.rs`. */
const PERMISSION: Record<string, string | null> = {
  "server.exec": "server.exec",
  "http.fetch": "net.http",
  "ui.patch": null,
  "ui.prompt": "ui.dialog",
  "ui.pickServer": null,
  "ui.toast": null,
  "store.get": null,
  "store.set": null,
  "store.list": null,
  "diag.crumb": null,
  "nav.openServer": null,
  "nav.goTab": null,
  "clipboard.read": "clipboard",
  "clipboard.write": "clipboard",
};

/**
 * A host whose answers are set up in advance.
 *
 * Install it with {@link MockHost.install}, which puts it on `globalThis.sb`
 * the way the runtime does.
 */
export class MockHost {
  readonly calls: Recorded[] = [];
  readonly logs: Array<[LogLevel, string]> = [];
  readonly toasts: Array<[string, ToastKind]> = [];
  readonly crumbs: string[] = [];

  /** `"GET /redfish/v1/"` to the answers, in order; the last one repeats. */
  private routes = new Map<string, Reply[]>();
  private prompts: PromptAnswer[] = [];
  private pick: ServerHandle | null = null;
  private execs = new Map<string, ExecResponse>();
  private clipboard: string | null = null;

  private cfg: Record<string, string>;
  private kv: Record<Scope, Map<string, string>>;
  private deniedSet: Set<string>;

  constructor(options: MockOptions = {}) {
    this.cfg = { ...options.config };
    this.kv = {
      global: new Map(Object.entries(options.global ?? {})),
      server: new Map(Object.entries(options.server ?? {})),
    };
    this.deniedSet = new Set(options.denied ?? []);
  }

  // ------------------------------------------------------------- scripting

  /** What `METHOD path` answers from now on. Replaces any earlier answer. */
  route(method: string, path: string, reply: Reply): this {
    this.routes.set(`${method} ${path}`, [reply]);
    return this;
  }

  /** One answer for `METHOD path`, then back to the standing one. */
  routeOnce(method: string, path: string, reply: Reply): this {
    const key = `${method} ${path}`;
    this.routes.set(key, [reply, ...(this.routes.get(key) ?? [])]);
    return this;
  }

  /** Shorthand for a JSON `GET`. */
  get(path: string, body: unknown): this {
    return this.route("GET", path, { status: 200, body: JSON.stringify(body) });
  }

  exec(script: string, response: Partial<ExecResponse>): this {
    this.execs.set(script, { code: 0, stdout: "", stderr: "", ...response });
    return this;
  }

  /** The next dialog answers this. Queued, so several may be scripted. */
  answerPrompt(answer: Partial<PromptAnswer>): this {
    this.prompts.push({ cancelled: false, values: {}, ...answer });
    return this;
  }

  confirmNext(): this {
    return this.answerPrompt({ cancelled: false });
  }

  cancelNext(): this {
    return this.answerPrompt({ cancelled: true });
  }

  pickServerReturns(handle: string | null): this {
    this.pick = handle as ServerHandle | null;
    return this;
  }

  // --------------------------------------------------------------- reading

  /** Every call, as `"http.fetch"` and so on. */
  called(): string[] {
    return this.calls.map((c) => c.fn);
  }

  /** Every call to one function. */
  callsTo<T extends Recorded["fn"]>(fn: T): Extract<Recorded, { fn: T }>[] {
    return this.calls.filter((c) => c.fn === fn) as Extract<Recorded, { fn: T }>[];
  }

  /** `METHOD path` for each HTTP request, in order. */
  requests(): string[] {
    return this.callsTo("http.fetch").map(
      (c) => `${c.req.method ?? "GET"} ${pathOf(c.req.url)}`,
    );
  }

  value(scope: Scope, key: string): string | undefined {
    return this.kv[scope].get(key);
  }

  // -------------------------------------------------------------- the host

  /** Puts this on `globalThis.sb`, and answers a function that removes it. */
  install(): () => void {
    const slot = globalThis as { sb?: Sb };
    const previous = slot.sb;
    slot.sb = this.sb();
    return () => {
      if (previous === undefined) delete slot.sb;
      else slot.sb = previous;
    };
  }

  sb(): Sb {
    const check = (fn: string) => {
      const needed = PERMISSION[fn];
      if (needed && this.deniedSet.has(needed)) throw denied(fn, needed);
    };

    return {
      server: {
        exec: async (req) => {
          check("server.exec");
          this.calls.push({ fn: "server.exec", req });
          const found = this.execs.get(req.script);
          if (!found) throw hostError("io", `no exec scripted for: ${req.script}`);
          return found;
        },
      },

      http: {
        fetch: async (req) => {
          check("http.fetch");
          this.calls.push({ fn: "http.fetch", req });

          // What the app does before anything reaches the network: no pin and
          // no review means no connection. A mock that let this through would
          // be testing a host this app does not have.
          if (!req.pinSha256 && !req.probeCert) {
            throw hostError("cert", "no reviewed certificate");
          }
          if (req.probeCert && (req.body || Object.keys(req.headers ?? {}).length > 0)) {
            const e = new Error("`probeCert` sends nothing, so it takes no body or headers");
            e.name = "OutOfScope";
            throw e;
          }

          const key = `${req.method ?? "GET"} ${pathOf(req.url)}`;
          const queue = this.routes.get(key);
          if (!queue || queue.length === 0) {
            throw hostError("network", `nothing routed for ${key}`);
          }
          const reply = queue.length > 1 ? queue.shift()! : queue[0]!;
          if (reply.error) throw hostError(reply.error.kind, reply.error.message);
          return {
            status: reply.status ?? 200,
            headers: reply.headers ?? {},
            body: reply.body ?? "",
            bodyEncoding: "utf8",
            ...(reply.cert ? { cert: fullCert(reply.cert) } : {}),
          } satisfies HttpResponse;
        },
      },

      ui: {
        patch: async ({ path, node }) => {
          this.calls.push({ fn: "ui.patch", path, node });
        },
        prompt: async (spec) => {
          check("ui.prompt");
          this.calls.push({ fn: "ui.prompt", spec });
          // Nothing scripted is a user who walked away, which is the safe
          // reading for a dialog that can power off a machine.
          return this.prompts.shift() ?? { cancelled: true, values: {} };
        },
        pickServer: async () => {
          this.calls.push({ fn: "ui.pickServer" });
          return this.pick === null ? { cancelled: true } : { server: this.pick };
        },
        toast: async ({ text, kind = "info" }) => {
          this.calls.push({ fn: "ui.toast", text, kind });
          this.toasts.push([text, kind]);
        },
      },

      store: {
        get: async ({ scope, key }) => {
          this.calls.push({ fn: "store.get", scope, key });
          return { value: this.kv[scope].get(key) ?? null };
        },
        set: async ({ scope, key, value }) => {
          this.calls.push({ fn: "store.set", scope, key, value });
          if (value === null) this.kv[scope].delete(key);
          else this.kv[scope].set(key, value);
        },
        list: async ({ scope, prefix }) => {
          this.calls.push({ fn: "store.list", scope, prefix });
          return {
            keys: [...this.kv[scope].keys()].filter((k) => k.startsWith(prefix)).sort(),
          };
        },
      },

      diag: {
        crumb: async ({ name }) => {
          this.calls.push({ fn: "diag.crumb", name });
          this.crumbs.push(name);
        },
      },

      nav: {
        openServer: async ({ server }) => {
          this.calls.push({ fn: "nav.openServer", server });
        },
        goTab: async ({ tab }) => {
          this.calls.push({ fn: "nav.goTab", tab });
        },
      },

      clipboard: {
        read: async () => {
          check("clipboard.read");
          this.calls.push({ fn: "clipboard.read" });
          return { text: this.clipboard };
        },
        write: async ({ text }) => {
          check("clipboard.write");
          this.calls.push({ fn: "clipboard.write", text });
          this.clipboard = text;
        },
      },

      config: { get: (key) => this.cfg[key] },

      log: {
        trace: (m) => this.logs.push(["trace", m]),
        debug: (m) => this.logs.push(["debug", m]),
        info: (m) => this.logs.push(["info", m]),
        warn: (m) => this.logs.push(["warn", m]),
        error: (m) => this.logs.push(["error", m]),
      },
    };
  }
}

function fullCert(partial: Partial<CertInfo> & { sha256: string }): CertInfo {
  return {
    subject: "CN=test",
    issuer: "CN=test",
    notBefore: "2020-01-01T00:00:00Z",
    notAfter: "2030-01-01T00:00:00Z",
    expired: false,
    ...partial,
  };
}

/** The path of a URL, so a route can be written without the host. */
export function pathOf(url: string): string {
  const i = url.indexOf("://");
  if (i < 0) return url;
  const rest = url.slice(i + 3);
  const slash = rest.indexOf("/");
  return slash < 0 ? "/" : rest.slice(slash);
}

/**
 * Walks a widget tree, for asserting what a plugin drew.
 *
 * The first node with this key, or `undefined`. Depth-first, so a key that is
 * unique within its surface is enough.
 */
export function find(node: Node, key: string): Node | undefined {
  if (node.k === key) return node;
  for (const child of node.c ?? []) {
    const hit = find(child, key);
    if (hit) return hit;
  }
  return undefined;
}

/** Every `l10n.` key the tree carries, in order, for asserting what it says. */
export function l10nKeys(node: Node): string[] {
  const out: string[] = [];
  const walk = (n: Node) => {
    for (const v of Object.values(n.p ?? {})) {
      if (typeof v === "string" && v.startsWith("l10n.")) out.push(v.split("")[0]!);
    }
    for (const c of n.c ?? []) walk(c);
  };
  walk(node);
  return out;
}
