#!/usr/bin/env python3
"""Check a ServerBox Monitor web app folder the way the agent reads it.

    python3 validate.py <app-folder> [--schema <monitor-app.schema.json>] [--compose]

Three layers:

1. The manifest against the published JSON Schema
   (docs/schemas/monitor-app.schema.json) through `check-jsonschema`, run by
   `uvx` or `pipx` when it is not installed.
2. What the schema cannot say, the same rules as the agent's reader
   (monitor/src/stacks/manifest.rs): files in the folder, env names set by
   one place only, `web.port` (or `[llm]`) naming a port setting, defaults that fit their
   setting, and every variable a compose file needs being one the env file
   sets.
3. With --compose: `docker compose config` over the files with the env file
   the defaults would write, so Compose itself reads the stack.

Exit status 0 means no errors; warnings do not fail. Standard library only
(Python 3.11+ for tomllib).
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    sys.exit("Python 3.11 or newer is needed (tomllib)")

SCHEMA_URL = (
    "https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/"
    "docs/schemas/monitor-app.schema.json"
)
MAX_FILE = 256 * 1024
MAX_PACKAGE = 1024 * 1024
MAX_FILES = 32
FILE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
ENV_NAME = re.compile(r"^[A-Z_][A-Z0-9_]{0,63}$")
VARIABLE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(:?[-+?])?|\$([A-Za-z_][A-Za-z0-9_]*)")


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)


def env_value_ok(value: str) -> bool:
    return len(value.encode()) <= 1024 and not any(c in value for c in "'\n\r\0")


# The name a built image must have, as the agent requires (`BUILT_PREFIX`).
BUILT_PREFIX = "localhost/"


def yaml_entries(text: str):
    """`key: value` lines of a compose file, values unquoted, as the agent reads them."""
    for line in text.splitlines():
        line = line.split(" #", 1)[0].lstrip()
        if line.startswith("- "):
            line = line[2:]
        if line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip().strip("'\"")
        if key and not any(c.isspace() for c in key):
            yield key, value.strip().strip("'\"")


def compose_builds(file: str, text: str, texts: dict, rep) -> list[str]:
    """The Dockerfiles a compose file builds from, its `build:` sections held
    to what the agent accepts: a mapping, context `.`, a Dockerfile of the
    package, no `additional_contexts` or `dockerfile_inline`."""
    builds, dockerfiles = 0, []
    for key, value in yaml_entries(text):
        if key == "build":
            if value:
                rep.error(f"{file}: build: a mapping with `dockerfile:`")
            else:
                builds += 1
        elif key == "context" and value not in (".", "./"):
            rep.error(f"{file}: build context: only `.`")
        elif key == "dockerfile":
            if value not in texts or value == "manifest.toml":
                rep.error(f"{file}: dockerfile {value} is not in the package")
            dockerfiles.append(value)
        elif key in ("additional_contexts", "dockerfile_inline"):
            rep.error(f"{file}: build: no `{key}`")
    if builds != len(dockerfiles):
        rep.error(f"{file}: every build: names its dockerfile")
    return dockerfiles


def compose_variables(text: str) -> tuple[set[str], set[str]]:
    """The variables a compose file needs, and those it can do without."""
    needed: set[str] = set()
    optional: set[str] = set()
    for line in text.splitlines():
        if line.lstrip().startswith("#"):
            continue
        if " #" in line:
            line = line[: line.index(" #")]
        line = line.replace("$$", "")
        for m in VARIABLE.finditer(line):
            if m.group(3):
                needed.add(m.group(3))
            elif m.group(2) and m.group(2)[-1] in "-+":
                optional.add(m.group(1))
            else:
                needed.add(m.group(1))
    return needed, optional - needed


def setting_env_names(s: dict) -> set[str]:
    kind = s.get("type")
    if kind in ("path", "port", "text"):
        return {s["env"]} if isinstance(s.get("env"), str) else set()
    if kind == "bool":
        return set(s.get("on", {})) | set(s.get("off", {}))
    if kind == "choice":
        return {k for o in s.get("options", []) for k in o.get("env", {})}
    return set()


def run_check_jsonschema(manifest: Path, schema_ref: str, rep: Report) -> None:
    runner = None
    if shutil.which("check-jsonschema"):
        runner = ["check-jsonschema"]
    elif shutil.which("uvx"):
        runner = ["uvx", "--from", "check-jsonschema==0.38.2", "check-jsonschema"]
    elif shutil.which("pipx"):
        runner = ["pipx", "run", "--spec", "check-jsonschema==0.38.2", "check-jsonschema"]
    if runner is None:
        rep.warn("schema not checked: install uv (https://docs.astral.sh/uv/) or pipx so check-jsonschema can run")
        return
    proc = subprocess.run([*runner, "--schemafile", schema_ref, str(manifest)], capture_output=True, text=True)
    if proc.returncode != 0:
        rep.error("manifest does not match the schema:\n" + (proc.stdout + proc.stderr).strip())


def check_files(folder: Path, rep: Report) -> dict[str, str]:
    texts: dict[str, str] = {}
    entries = sorted(folder.iterdir())
    if len(entries) > MAX_FILES:
        rep.error(f"more than {MAX_FILES} files")
    total = 0
    for path in entries:
        if not path.is_file() or path.is_symlink():
            rep.error(f"{path.name}: only plain files; no folders or links")
            continue
        if not FILE.match(path.name):
            rep.error(f"{path.name}: a plain file name: letters, digits, ._-")
        data = path.read_bytes()
        total += len(data)
        if len(data) > MAX_FILE:
            rep.error(f"{path.name}: more than 256 KiB")
        try:
            texts[path.name] = data.decode()
        except UnicodeDecodeError:
            rep.error(f"{path.name}: not UTF-8 text")
    if total > MAX_PACKAGE:
        rep.error("the folder holds more than 1 MiB")
    return texts


def app_id(m: dict) -> str:
    """The app's id, made from its publisher and name."""
    return f"{m.get('publisher')}.{m.get('name')}"


RESERVED = {"SBM_UID", "SBM_GID", "SBM_TZ", "SBM_RENDER_GID"}


def service_block(compose: str, name: str) -> list[str] | None:
    """The lines of compose service `name` under `services:`, its own left out."""
    lines = compose.splitlines()
    try:
        start = next(i for i, l in enumerate(lines) if l.rstrip() == "services:") + 1
    except StopIteration:
        return None
    content = [i for i in range(start, len(lines)) if lines[i].strip() and not lines[i].lstrip().startswith("#")]
    if not content:
        return None
    indent = lambda l: len(l) - len(l.lstrip())
    depth = indent(lines[content[0]])
    for i in content:
        line = lines[i]
        if indent(line) == depth and line.strip().endswith(":") and line.strip()[:-1].strip("'\"") == name:
            block = []
            for l in lines[i + 1:]:
                if l.strip() and not l.lstrip().startswith("#") and indent(l) <= depth:
                    break
                block.append(l)
            return block
        if indent(line) < depth:
            break
    return None


PINNED = re.compile(r"^.+@sha256:[0-9a-fA-F]{64}$")


def published_entries(line: str) -> list[str]:
    """The entries a compose line lists: `- "a:b"`, or `ports: ['a:b', 'c:d']`."""
    line = line.strip()
    if line.startswith("ports:"):
        line = line[len("ports:"):].strip()
    line = line.removeprefix("- ")
    if line.startswith("[") and line.endswith("]"):
        line = line[1:-1]
    return [e.strip().strip("'\"") for e in line.split(",") if e.strip()]


def check_mcp(m: dict, settings: list, texts: dict[str, str], rep: Report) -> None:
    """[[mcp]]: as `stacks::manifest` checks it (the schema covers the shape)."""
    secrets = {s.get("env") for s in m.get("secrets", [])}
    for i, server in enumerate(m.get("mcp", [])):
        at = f"mcp[{i}]"
        port = next((s for s in settings if s.get("key") == server.get("port") and s.get("type") == "port"), None)
        if port is None or port.get("protocol", "tcp") != "tcp":
            rep.error(f"{at}.port: names no TCP port setting")
        auth = server.get("auth") or {}
        if "secret" in auth and auth["secret"] not in secrets:
            rep.error(f"{at}.auth.secret: {auth['secret']} is not a [[secrets]] entry")
        service = server.get("service")
        if server.get("publisher") == "builtin" or not service:
            continue
        block = next((b for f in m.get("compose", {}).get("files", []) if f in texts and (b := service_block(texts[f], service)) is not None), None)
        if block is None:
            rep.error(f"{at}.service: {service} is not a service of the compose files")
            continue
        image = next((v for k, v in yaml_entries("\n".join(block)) if k == "image"), "")
        if not PINNED.match(image):
            rep.error(f"{at}.service: {service}: an image pinned by digest (@sha256:…)")
        if port is not None:
            ref = "${" + port.get("env", "") + "}"
            published = [e for l in block for e in published_entries(l) if ref in e]
            if not published or any(not l.startswith("127.0.0.1:") for l in published):
                rep.error(f"{at}.service: {service}: publishes {ref} on 127.0.0.1 alone")


def check_llm(m: dict, settings: list, rep: Report) -> None:
    """[llm]: as `stacks::manifest` checks it."""
    llm = m.get("llm")
    if llm is None:
        return
    port = next((s for s in settings if s.get("key") == llm.get("port") and s.get("type") == "port"), None)
    if port is None or port.get("protocol", "tcp") != "tcp":
        rep.error("llm.port: names no TCP port setting")
    if llm.get("path", "/v1").endswith("/"):
        rep.error("llm.path: not ending with /")
    model = llm.get("model")
    if model is not None and not any(s.get("key") == model and s.get("type") == "text" for s in settings):
        rep.error("llm.model: names no text setting")
    key = llm.get("key")
    if key is not None and key not in {s.get("env") for s in m.get("secrets", [])}:
        rep.error(f"llm.key: {key} is not a [[secrets]] entry")
    tools = llm.get("tools")
    if tools is not None and model is None:
        rep.error("llm.tools: needs llm.model: the parser follows the model")


def check_manifest(m: dict, folder: Path, texts: dict[str, str], rep: Report) -> None:
    if "id" in m:
        rep.error("id: not written by hand; it is <publisher>.<name>")
    if app_id(m) != folder.name:
        rep.error(f"the id {app_id(m)!r} differs from the folder's name {folder.name!r}")

    sources: dict[str, list[str]] = {}
    for name, value in m.get("env", {}).items():
        sources.setdefault(name, []).append("env")
        if not env_value_ok(str(value)):
            rep.error(f"env.{name}: no ', line break or NUL; at most 1024 bytes")
    for i, s in enumerate(m.get("secrets", [])):
        sources.setdefault(s.get("env", ""), []).append(f"secrets[{i}]")

    keys: set[str] = set()
    settings = m.get("settings", [])
    for i, s in enumerate(settings):
        at = f"settings[{i}] ({s.get('key')})"
        if s.get("key") in keys:
            rep.error(f"{at}: key used twice")
        keys.add(s.get("key"))
        for name in setting_env_names(s):
            sources.setdefault(name, []).append(at)
        kind = s.get("type")
        if kind == "path":
            d = s.get("default", "")
            if not (d.startswith(("/", "{stack}", "{shared}"))) or not env_value_ok(d):
                rep.error(f"{at}: default is absolute, or under {{stack}} or {{shared}}")
            if s.get("data") and d.startswith("{shared}"):
                rep.error(f"{at}: a {{shared}} folder is not one app's data")
        elif kind == "bool":
            on, off = s.get("on", {}), s.get("off", {})
            if not on or set(on) != set(off):
                rep.error(f"{at}: `on` and `off` set the same names, at least one")
        elif kind == "choice":
            options = s.get("options", [])
            values = [o.get("value") for o in options]
            if len(set(values)) != len(values):
                rep.error(f"{at}: an option value appears twice")
            if s.get("default") not in values:
                rep.error(f"{at}: default is not one of the options")
            names = [set(o.get("env", {})) for o in options]
            if any(n != names[0] for n in names):
                rep.error(f"{at}: every option sets the same env names")
        elif kind == "text":
            try:
                pattern = re.compile(f"^(?:{s.get('pattern', '')})$")
            except re.error:
                rep.error(f"{at}: pattern is not a regular expression")
            else:
                d = s.get("default")
                if d and not pattern.match(d):
                    rep.error(f"{at}: default does not match the pattern")

    for name, where in sources.items():
        if name in RESERVED:
            rep.error(f"{where[0]}: {name} is written by the agent")
        if not ENV_NAME.match(name):
            rep.error(f"{where[0]}: {name!r} is not an env name")
        if len(where) > 1:
            rep.error(f"{name} is set by {where[0]} and {where[1]}")

    if "web" in m:
        port = m["web"].get("port")
        web = next((s for s in settings if s.get("key") == port and s.get("type") == "port"), None)
        if web is None:
            rep.error(f"web.port {port!r} names no port setting")
        elif web.get("protocol", "tcp") != "tcp":
            rep.error(f"web.port {port!r} is a TCP port setting")
    elif "llm" not in m:
        rep.error("web: an app without a page serves an [llm] endpoint")

    login = m.get("login")
    if login is not None:
        if not login:
            rep.error("login: says nothing")
        secret = login.get("password")
        if secret is not None and secret not in {s.get("env") for s in m.get("secrets", [])}:
            rep.error(f"login.password: {secret} is not a [[secrets]] entry")

    if m.get("web", {}).get("basic_auth"):
        user = (login or {}).get("user")
        if not (login or {}).get("password") or not user or ":" in user:
            rep.error("web.basic_auth: needs [login] user (no `:`) and password")

    check_mcp(m, settings, texts, rep)
    check_llm(m, settings, rep)

    if m.get("license", {}).get("accept") is not True:
        rep.warn("license.accept is false: the admin deploys without being shown the licence to accept")

    for name in texts:
        if name.endswith(".dockerignore"):
            rep.error(f"{name}: no .dockerignore: the agent writes the stack's")

    provided = set(sources) | RESERVED
    if (m.get("llm") or {}).get("tools"):
        provided.add("SBM_TOOL_PARSER")
    used: set[str] = set()
    dockerfiles: list[str] = []
    built_images = False
    for file in m.get("compose", {}).get("files", []):
        if file not in texts:
            rep.error(f"compose.files: {file} is not in the folder")
            continue
        dockerfiles += compose_builds(file, texts[file], texts, rep)
        built_images |= any(k == "image" and v.startswith(BUILT_PREFIX) for k, v in yaml_entries(texts[file]))
        needed, optional = compose_variables(texts[file])
        for name in sorted(needed - provided):
            rep.error(f"{file}: ${{{name}}} is not set by the manifest")
        used |= needed | optional
    if dockerfiles and not built_images:
        rep.error(f"compose.files: a built image is named {BUILT_PREFIX}…")
    if built_images and not dockerfiles:
        rep.error(f"compose.files: {BUILT_PREFIX}… is for a built image; nothing is built")
    if dockerfiles and "buildsImages" not in m.get("notices", []):
        rep.error("notices: buildsImages: the compose files build an image")
    for name in sorted(provided - used - RESERVED):
        rep.warn(f"{name} is set but no compose file names it (fine when a container reads it through env_file)")


def defaults_env(m: dict, stack: Path) -> str:
    """The env file the agent writes for the defaults, on a machine with no GPU."""
    values = {k: str(v) for k, v in m.get("env", {}).items()}
    for s in m.get("secrets", []):
        values[s["env"]] = "x" * s.get("length", 32)
    for s in m.get("settings", []):
        kind = s.get("type")
        if kind == "path":
            values[s["env"]] = s["default"].replace("{stack}", str(stack)).replace("{shared}", str(stack / ".shared"))
        elif kind == "port":
            values[s["env"]] = str(s["default"])
        elif kind == "bool":
            values.update(s["on"] if s["default"] else s["off"])
        elif kind == "choice":
            values.update(next(o["env"] for o in s["options"] if o["value"] == s["default"]))
        elif kind == "text" and s.get("default"):
            values[s["env"]] = s["default"]
    values.update({"SBM_UID": "1000", "SBM_GID": "1000", "SBM_TZ": "UTC", "SBM_RENDER_GID": "1000"})
    if (m.get("llm") or {}).get("tools"):
        values["SBM_TOOL_PARSER"] = ""
    return "".join(f"{k}='{v}'\n" for k, v in sorted(values.items()))


def run_compose_config(m: dict, folder: Path, rep: Report) -> None:
    if not shutil.which("docker"):
        rep.warn("--compose: docker is not installed here")
        return
    with tempfile.TemporaryDirectory() as tmp:
        stack = Path(tmp)
        for path in folder.iterdir():
            if path.name != "manifest.toml":
                shutil.copy(path, stack / path.name)
        (stack / ".env").write_text(defaults_env(m, stack))
        cmd = ["docker", "compose", "-p", "sbm-" + app_id(m).replace(".", "-"), "--env-file", ".env"]
        for f in m["compose"]["files"]:
            cmd += ["-f", f]
        proc = subprocess.run([*cmd, "config", "--quiet"], cwd=stack, capture_output=True, text=True)
        if proc.returncode != 0:
            rep.error("docker compose config failed:\n" + (proc.stdout + proc.stderr).strip())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    parser.add_argument("folder", type=Path)
    parser.add_argument("--schema", help="a local schema file instead of the published one")
    parser.add_argument("--compose", action="store_true", help="also run docker compose config")
    args = parser.parse_args()

    folder: Path = args.folder.resolve()
    rep = Report()
    manifest_path = folder / "manifest.toml"
    if not manifest_path.is_file():
        print(f"error: {manifest_path} not found")
        return 1
    texts = check_files(folder, rep)
    try:
        manifest = tomllib.loads(texts.get("manifest.toml", ""))
    except tomllib.TOMLDecodeError as e:
        print(f"error: manifest.toml: {e}")
        return 1

    run_check_jsonschema(manifest_path, args.schema or SCHEMA_URL, rep)
    check_manifest(manifest, folder, texts, rep)
    if args.compose and not rep.errors:
        run_compose_config(manifest, folder, rep)

    for w in rep.warnings:
        print(f"warning: {w}")
    for e in rep.errors:
        print(f"error: {e}")
    if rep.errors:
        return 1
    print(f"ok: {app_id(manifest)} {manifest.get('version')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
