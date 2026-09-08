/**
 * What a machine is listening on, out of `ss` or `netstat`.
 *
 * Its own module so the parsing is testable without a host: the shape of these
 * two commands' output is the whole of what can go wrong here, and it differs
 * by distribution, by privilege and by address family.
 */

export interface Listener {
  /** `tcp` or `udp`. */
  proto: string;
  /** The address it is bound to, as the command printed it. */
  addr: string;
  port: number;
  /** The process, where the command was allowed to say. */
  process?: string;
  /**
   * Whether anything outside this machine can reach it.
   *
   * The one thing a person opens this list to find out, and the reason the
   * bind address is worth showing at all: `0.0.0.0` and `[::]` are every
   * interface, `127.0.0.1` and `[::1]` are this machine only.
   */
  exposed: boolean;
}

/** Which command produced the body, as the script's first line says. */
export type Format = "ss" | "netstat" | "none";

/**
 * The command, with its own format marker.
 *
 * A plugin gets raw stdout from `sb.server.exec` — there is no segment
 * protocol out here — so the script says which of the two it ran rather than
 * leaving the parser to guess from a shape that differs by version anyway.
 *
 * `-p` needs privilege to name *another* user's process. Without it the ports
 * are still listed and the process column is empty, which is worth having: the
 * question "what is open" is answerable when "what opened it" is not.
 */
export const COMMAND = [
  "if command -v ss >/dev/null 2>&1; then",
  "  printf 'fmt=ss\\n'",
  "  ss -tulnpH 2>/dev/null || ss -tulnH 2>/dev/null",
  "elif command -v netstat >/dev/null 2>&1; then",
  "  printf 'fmt=netstat\\n'",
  "  netstat -tulnp 2>/dev/null || netstat -tuln 2>/dev/null",
  "else",
  "  printf 'fmt=none\\n'",
  "fi",
].join("\n");

export function parse(raw: string): { format: Format; listeners: Listener[] } {
  const lines = raw.split("\n");
  let format: Format = "none";
  const body: string[] = [];

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith("fmt=")) {
      const named = trimmed.slice(4);
      if (named === "ss" || named === "netstat") format = named;
      continue;
    }
    body.push(line);
  }

  const listeners =
    format === "ss"
      ? body.map(parseSs).filter(isListener)
      : format === "netstat"
        ? body.map(parseNetstat).filter(isListener)
        : [];

  // By port, because that is what somebody is looking one up by. Ties broken
  // by protocol so a port listening on both is two adjacent rows rather than
  // two in an order that changes between reads.
  listeners.sort((a, b) => a.port - b.port || a.proto.localeCompare(b.proto));
  return { format, listeners };
}

const isListener = (l: Listener | null): l is Listener => l !== null;

/**
 * `ss -tulnpH`:
 *
 * ```text
 * tcp   LISTEN 0 4096 0.0.0.0:22   0.0.0.0:*  users:(("sshd",pid=1,fd=3))
 * udp   UNCONN 0 0    127.0.0.1:323 0.0.0.0:*
 * ```
 *
 * A UDP socket is `UNCONN` rather than `LISTEN`, which is why the state column
 * is not filtered on: `-l` already asked for listening sockets, and refusing
 * anything that does not say `LISTEN` would drop every UDP row.
 */
function parseSs(line: string): Listener | null {
  const cols = line.trim().split(/\s+/);
  if (cols.length < 5) return null;
  const proto = normalizeProto(cols[0]!);
  if (!proto) return null;

  const local = splitHostPort(cols[4]!);
  if (!local) return null;

  return {
    proto,
    addr: local.addr,
    port: local.port,
    process: processFromSs(cols.slice(5).join(" ")),
    exposed: isExposed(local.addr),
  };
}

/**
 * `netstat -tulnp`:
 *
 * ```text
 * tcp   0 0 0.0.0.0:22    0.0.0.0:*  LISTEN  1/sshd
 * udp   0 0 127.0.0.1:323 0.0.0.0:*          1234/chronyd
 * ```
 *
 * The header lines (`Active Internet connections`, `Proto Recv-Q ...`) fall
 * out on their own: neither starts with a protocol this accepts.
 */
function parseNetstat(line: string): Listener | null {
  const cols = line.trim().split(/\s+/);
  if (cols.length < 4) return null;
  const proto = normalizeProto(cols[0]!);
  if (!proto) return null;

  const local = splitHostPort(cols[3]!);
  if (!local) return null;

  // The program column is last where it is there at all, and is `pid/name`.
  // A row without it ends in the foreign address or in `LISTEN`.
  const last = cols[cols.length - 1]!;
  const slash = last.indexOf("/");
  const process = slash > 0 ? last.slice(slash + 1) : undefined;

  return {
    proto,
    addr: local.addr,
    port: local.port,
    process,
    exposed: isExposed(local.addr),
  };
}

/**
 * `tcp`, `tcp6`, `udp`, `udp6` — and nothing else.
 *
 * The family is dropped rather than kept: a service on `[::]` is on every
 * interface whether or not the kernel also lists a v4 row for it, and two rows
 * differing only by `6` reads as two services.
 */
function normalizeProto(raw: string): string | null {
  const lower = raw.toLowerCase();
  if (lower.startsWith("tcp")) return "tcp";
  if (lower.startsWith("udp")) return "udp";
  return null;
}

/**
 * `0.0.0.0:22`, `[::]:22`, `127.0.0.1:323`, `*:22`.
 *
 * From the right, because an IPv6 address is full of colons and only the last
 * one separates the port.
 */
function splitHostPort(raw: string): { addr: string; port: number } | null {
  const at = raw.lastIndexOf(":");
  if (at <= 0) return null;
  const port = Number(raw.slice(at + 1));
  if (!Number.isInteger(port) || port < 0 || port > 65535) return null;
  return { addr: raw.slice(0, at), port };
}

/** `users:(("sshd",pid=1,fd=3))` → `sshd`. */
function processFromSs(rest: string): string | undefined {
  const at = rest.indexOf('(("');
  if (at < 0) return undefined;
  const end = rest.indexOf('"', at + 3);
  if (end < 0) return undefined;
  const name = rest.slice(at + 3, end);
  return name || undefined;
}

/**
 * Whether the bind address reaches beyond this machine.
 *
 * Loopback and nothing else is local. A link-local or private address is
 * *reachable* — from the LAN, from a VPN — and calling it local would be the
 * reassuring answer rather than the true one.
 */
function isExposed(addr: string): boolean {
  const bare = addr.replace(/^\[|\]$/g, "");
  if (bare === "127.0.0.1" || bare === "::1") return false;
  if (bare.startsWith("127.")) return false;
  return true;
}
