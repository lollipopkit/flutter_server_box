# Karakeep's MCP server (AGPL-3.0, apps/mcp of the release) over HTTP, built
# on the machine by ServerBox Monitor (`build:` in compose.yaml).
#
# Written for ServerBox Monitor: Karakeep's MCP server speaks stdio only
# (apps/mcp/src/index.ts), and Agent mode reaches MCP servers over Streamable
# HTTP. Its release image, pinned by digest, gets bridge.js beside it: no
# dependency, plain Node.
#
# - POST /mcp: a JSON-RPC message (or a batch) passed to the server's stdin;
#   each request answered with its response as JSON, ids rewritten so two
#   clients never collide; notifications answered 202. No SSE stream (GET is
#   405), which Streamable HTTP allows.
# - Every request needs `Authorization: Bearer <MCP_TOKEN>`.
# - The server is started on the first request, with the API key set in the
#   app's settings, else the one the compose file's seed job left in /key/key;
#   without either the bridge answers 503.

ARG KARAKEEP_VERSION=0.33.2
FROM ghcr.io/karakeep-app/karakeep-mcp:${KARAKEEP_VERSION}@sha256:7b6e5b3d0613a3c23f107f828bd0b367876148c63291d7ff55e23082d193b58a

COPY <<"EOF" /app/apps/mcp/bridge.js
const http = require("node:http");
const crypto = require("node:crypto");
const fs = require("node:fs");
const cp = require("node:child_process");
const readline = require("node:readline");

const token = Buffer.from("Bearer " + (process.env.MCP_TOKEN || ""));
if (!process.env.MCP_TOKEN) throw new Error("MCP_TOKEN is not set");

let child = null;
let next = 1;
const waiting = new Map();

function server() {
  if (child) return child;
  // The admin's own key (the app's setting) first, else the seed job's.
  let key = process.env.KARAKEEP_MCP_API_KEY || "";
  if (!key) {
    try {
      key = fs.readFileSync("/key/key", "utf8").trim();
    } catch {
      return null;
    }
  }
  if (!key) return null;
  child = cp.spawn("node", ["index.js"], {
    cwd: "/app/apps/mcp",
    env: { ...process.env, KARAKEEP_API_KEY: key, KARAKEEP_MCP_API_KEY: "", MCP_TOKEN: "" },
    stdio: ["pipe", "pipe", "inherit"],
  });
  readline.createInterface({ input: child.stdout }).on("line", (line) => {
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      return;
    }
    const w = msg.id !== undefined && waiting.get(msg.id);
    if (!w) return;
    waiting.delete(msg.id);
    msg.id = w.id;
    w.resolve(msg);
  });
  child.on("exit", () => {
    child = null;
    for (const [id, w] of waiting) {
      waiting.delete(id);
      w.resolve({ jsonrpc: "2.0", id: w.id, error: { code: -32603, message: "the MCP server stopped" } });
    }
  });
  return child;
}

function send(proc, msg) {
  if (msg.id === undefined || msg.method === undefined) {
    proc.stdin.write(JSON.stringify(msg) + "\n");
    return null;
  }
  const id = next++;
  return new Promise((resolve) => {
    waiting.set(id, { id: msg.id, resolve });
    proc.stdin.write(JSON.stringify({ ...msg, id }) + "\n");
  });
}

function answer(res, status, body) {
  res.writeHead(status, body === undefined ? {} : { "content-type": "application/json" });
  res.end(body === undefined ? undefined : JSON.stringify(body));
}

http
  .createServer((req, res) => {
    const auth = Buffer.from(req.headers.authorization || "");
    if (auth.length !== token.length || !crypto.timingSafeEqual(auth, token)) return answer(res, 401, { error: "unauthorized" });
    if (req.url.split("?")[0] !== "/mcp") return answer(res, 404, { error: "not found" });
    if (req.method === "DELETE") return answer(res, 200);
    if (req.method !== "POST") return answer(res, 405, { error: "POST only" });
    const chunks = [];
    let size = 0;
    req.on("data", (c) => {
      size += c.length;
      if (size > 4 << 20) req.destroy();
      else chunks.push(c);
    });
    req.on("end", async () => {
      let body;
      try {
        body = JSON.parse(Buffer.concat(chunks).toString("utf8"));
      } catch {
        return answer(res, 400, { jsonrpc: "2.0", id: null, error: { code: -32700, message: "parse error" } });
      }
      const proc = server();
      if (!proc) return answer(res, 503, { error: "no API key yet: see the app's sign-in note" });
      const batch = Array.isArray(body);
      const replies = (await Promise.all((batch ? body : [body]).map((m) => send(proc, m)))).filter(Boolean);
      if (!replies.length) return answer(res, 202);
      answer(res, 200, batch ? replies : replies[0]);
    });
  })
  .listen(8080, "0.0.0.0");
EOF

EXPOSE 8080
ENTRYPOINT ["node", "bridge.js"]
