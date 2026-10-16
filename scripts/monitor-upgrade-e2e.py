"""Updates a monitor agent through its own API, as the panel and the app do,
and follows the update across the agent's restart:

    python3 monitor-upgrade-e2e.py <app dir>

`POST /update/run`, then `GET /update` until its `run` ends, carrying on
through the requests the restarting agent does not answer. Signs in on
127.0.0.1:3770 (loopback: no TLS needed) with the password in
<app dir>/initial-admin-credentials.txt, which never leaves the machine.
Standard library only: the VM has no pip.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:3770/api/v1"


def call(method, path, body=None, token=None):
    req = urllib.request.Request(
        BASE + path,
        method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={"content-type": "application/json", **({"authorization": f"Bearer {token}"} if token else {})},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        raw = resp.read()
        return json.loads(raw) if raw else None


def main():
    app_dir = sys.argv[1]
    with open(os.path.join(app_dir, "initial-admin-credentials.txt")) as f:
        password = next(line.split(":", 1)[1].strip() for line in f if line.startswith("password:"))
    token = call("POST", "/login", {"password": password})["token"]
    before = call("GET", "/update", token=token)
    assert before["install"] == "script", before
    call("POST", "/update/run", {}, token)
    print("    started; following")
    away = 0
    started = time.time()
    while time.time() - started < 600:
        time.sleep(2)
        try:
            update = call("GET", "/update", token=token)
        except (urllib.error.URLError, ConnectionError, TimeoutError):
            away += 1
            continue
        run = update.get("run") or {}
        if run.get("state") not in (None, "running"):
            for line in run.get("lines", [])[-6:]:
                print("    | " + line)
            print(f"    {run['state']} (exit {run.get('exit')}), {away} polls unanswered across the restart")
            sys.exit(0 if run["state"] == "done" else 1)
    sys.exit("the update did not end")


if __name__ == "__main__":
    main()
