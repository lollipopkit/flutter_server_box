"""An OpenAI-compatible model for scripts/agent-chat-encryption-e2e.sh.

Streams `Answer to: <the last user message>`, and `Title` to a request
without tools (the chat's title). Usage: mock_model.py PORT
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Model(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        body = json.dumps({"data": [{"id": "mock"}]}).encode()
        self.send_response(200)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        req = json.loads(self.rfile.read(int(self.headers["content-length"])))
        if "tools" in req:
            users = [m for m in req["messages"] if m["role"] == "user"]
            content = users[-1]["content"]
            if isinstance(content, list):
                content = "".join(p.get("text", "") for p in content)
            text = f"Answer to: {content}"
        else:
            text = "Title"
        self.send_response(200)
        self.send_header("content-type", "text/event-stream")
        self.send_header("connection", "close")
        self.end_headers()
        for delta, finish in (({"role": "assistant", "content": text}, None), ({}, "stop")):
            chunk = {
                "id": "c1",
                "object": "chat.completion.chunk",
                "created": 1,
                "model": req["model"],
                "choices": [{"index": 0, "delta": delta, "finish_reason": finish}],
            }
            self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
        self.wfile.write(b"data: [DONE]\n\n")


ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Model).serve_forever()
