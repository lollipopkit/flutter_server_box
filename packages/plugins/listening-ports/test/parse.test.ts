/**
 * The two shapes this plugin reads, kept verbatim.
 *
 * Both commands print something different depending on version, privilege and
 * address family, and a parser written against a tidied-up sample is one that
 * works on the machine it was written on. The bodies below carry the header
 * lines, the `[::]` rows and the rows with no process — which is what a
 * command run without privilege actually returns.
 */

import { describe, expect, test } from "bun:test";
import { parse } from "../src/parse.ts";

const SS = `fmt=ss
tcp   LISTEN 0      4096         0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=812,fd=3))
tcp   LISTEN 0      511          127.0.0.1:6379     0.0.0.0:*    users:(("redis-server",pid=940,fd=6))
tcp   LISTEN 0      4096            [::]:22            [::]:*    users:(("sshd",pid=812,fd=4))
tcp   LISTEN 0      70           127.0.0.1:33060    0.0.0.0:*
udp   UNCONN 0      0            127.0.0.1:323      0.0.0.0:*    users:(("chronyd",pid=701,fd=5))
`;

const NETSTAT = `fmt=netstat
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      812/sshd
tcp        0      0 127.0.0.1:6379          0.0.0.0:*               LISTEN      940/redis-server
tcp6       0      0 :::80                   :::*                    LISTEN      1201/nginx
udp        0      0 127.0.0.1:323           0.0.0.0:*                           701/chronyd
`;

describe("ss", () => {
  const { format, listeners } = parse(SS);

  test("reads every row and drops nothing", () => {
    expect(format).toBe("ss");
    expect(listeners).toHaveLength(5);
  });

  test("sorts by port, so a port is looked up rather than scanned for", () => {
    expect(listeners.map((l) => l.port)).toEqual([22, 22, 323, 6379, 33060]);
  });

  test("names the process where the command was allowed to", () => {
    expect(listeners[0]!.process).toBe("sshd");
    expect(listeners.find((l) => l.port === 6379)!.process).toBe(
      "redis-server",
    );
  });

  /// `-p` needs privilege to name another user's process. Without it the port
  /// is still worth showing: "what is open" is answerable when "what opened
  /// it" is not.
  test("a row with no process is a row, not a dropped one", () => {
    const mysqlx = listeners.find((l) => l.port === 33060)!;
    expect(mysqlx.process).toBeUndefined();
    expect(mysqlx.addr).toBe("127.0.0.1");
  });

  /// The one thing somebody opens this list to find out.
  test("loopback is not exposed and every interface is", () => {
    const byPort = (p: number, addr: string) =>
      listeners.find((l) => l.port === p && l.addr === addr)!;
    expect(byPort(22, "0.0.0.0").exposed).toBe(true);
    expect(byPort(22, "[::]").exposed).toBe(true);
    expect(byPort(6379, "127.0.0.1").exposed).toBe(false);
    expect(byPort(323, "127.0.0.1").exposed).toBe(false);
  });

  /// A UDP socket is `UNCONN`, not `LISTEN`. Filtering on the state column
  /// would drop every UDP row, and `-l` already asked for listening sockets.
  test("udp is kept even though it never says LISTEN", () => {
    expect(listeners.find((l) => l.proto === "udp")?.port).toBe(323);
  });
});

describe("netstat", () => {
  const { format, listeners } = parse(NETSTAT);

  test("the two header lines are not rows", () => {
    expect(format).toBe("netstat");
    expect(listeners).toHaveLength(4);
  });

  test("the program column is read off the end", () => {
    expect(listeners.find((l) => l.port === 80)!.process).toBe("nginx");
    expect(listeners.find((l) => l.port === 22)!.process).toBe("sshd");
  });

  /// `tcp6` and `tcp` are one protocol. Two rows differing only by a `6` read
  /// as two services, and a socket on `[::]` is on every interface whether or
  /// not the kernel also lists a v4 row beside it.
  test("the address family is not part of the protocol", () => {
    expect(new Set(listeners.map((l) => l.proto))).toEqual(
      new Set(["tcp", "udp"]),
    );
  });

  test("an IPv6 wildcard is exposed", () => {
    const http = listeners.find((l) => l.port === 80)!;
    expect(http.addr).toBe("::");
    expect(http.exposed).toBe(true);
  });
});

describe("the shapes that are not rows", () => {
  test("no command at all is told apart from nothing listening", () => {
    const { format, listeners } = parse("fmt=none\n");
    expect(format).toBe("none");
    expect(listeners).toEqual([]);
  });

  test("output with no marker reads as no command", () => {
    expect(parse("some stray text\n").format).toBe("none");
  });

  /// An IPv6 address is full of colons and only the last one separates the
  /// port — splitting from the left gives `[` and a port of `NaN`.
  test("an IPv6 address is split from the right", () => {
    const { listeners } = parse(
      "fmt=ss\ntcp LISTEN 0 4096 [fe80::1%eth0]:8080 [::]:*\n",
    );
    expect(listeners[0]).toMatchObject({
      addr: "[fe80::1%eth0]",
      port: 8080,
      exposed: true,
    });
  });

  test("a line that is not a listener costs a line, not the reading", () => {
    const { listeners } = parse(
      "fmt=ss\nsomething went wrong\ntcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*\n",
    );
    expect(listeners).toHaveLength(1);
    expect(listeners[0]!.port).toBe(22);
  });

  test("a port outside the range is not a port", () => {
    expect(
      parse("fmt=ss\ntcp LISTEN 0 4096 0.0.0.0:99999 0.0.0.0:*\n").listeners,
    ).toEqual([]);
  });
});
