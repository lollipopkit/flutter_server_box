#!/usr/bin/env python3
"""Connect a newline-delimited MCP stdio client to the running desktop app."""
import http.client
import json
import os
import sys


def main():
    token = os.environ.get("SERVERBOX_MCP_TOKEN")
    if not token:
        sys.exit("Set SERVERBOX_MCP_TOKEN for this client.")
    host = os.environ.get("SERVERBOX_MCP_HOST", "127.0.0.1")
    port = int(os.environ.get("SERVERBOX_MCP_PORT", "49762"))
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    for line in sys.stdin.buffer:
        message = {}
        connection = http.client.HTTPConnection(host, port, timeout=55)
        try:
            message = json.loads(line)
            connection.request("POST", "/mcp", line, headers)
            response = connection.getresponse()
            body = response.read()
            if response.status == 202:
                continue
            if response.status != 200:
                raise ValueError
            reply = json.loads(body)
        except (OSError, ValueError, http.client.HTTPException):
            if not isinstance(message, dict) or "id" not in message:
                continue
            reply = {"jsonrpc": "2.0", "id": message["id"], "error": {
                "code": -32000, "message": "Check that ServerBox is running and the token is valid."
            }}
        finally:
            connection.close()
        print(json.dumps(reply), flush=True)


if __name__ == "__main__":
    main()
