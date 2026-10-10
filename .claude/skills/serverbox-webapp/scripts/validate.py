#!/usr/bin/env python3
"""Check a ServerBox Monitor web app folder the way the agent reads it.

    python3 validate.py <app-folder> [--schema <monitor-app.schema.json>] [--compose]

Three layers:

1. The manifest against the published JSON Schema
   (docs/schemas/monitor-app.schema.json) through `check-jsonschema`, run by
   `uvx` or `pipx` when it is not installed.
2. What the schema cannot say, the same rules as the agent's reader
   (monitor/src/stacks/manifest.rs): files in the folder, env names set by
   one place only, `web.port` naming a port setting, defaults that fit their
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


def check_manifest(m: dict, folder: Path, texts: dict[str, str], rep: Report) -> None:
    if m.get("id") != folder.name:
        rep.error(f"id {m.get('id')!r} differs from the folder's name {folder.name!r}")

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
            if not (d.startswith("/") or d.startswith("{stack}")) or not env_value_ok(d):
                rep.error(f"{at}: default is absolute, or under {{stack}}")
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
        if not ENV_NAME.match(name):
            rep.error(f"{where[0]}: {name!r} is not an env name")
        if len(where) > 1:
            rep.error(f"{name} is set by {where[0]} and {where[1]}")

    port = m.get("web", {}).get("port")
    if not any(s.get("key") == port and s.get("type") == "port" for s in settings):
        rep.error(f"web.port {port!r} names no port setting")

    if m.get("license", {}).get("accept") is not True:
        rep.warn("license.accept is false: the admin deploys without being shown the licence to accept")

    provided = set(sources)
    used: set[str] = set()
    for file in m.get("compose", {}).get("files", []):
        if file not in texts:
            rep.error(f"compose.files: {file} is not in the folder")
            continue
        needed, optional = compose_variables(texts[file])
        for name in sorted(needed - provided):
            rep.error(f"{file}: ${{{name}}} is not set by the manifest")
        used |= needed | optional
    for name in sorted(provided - used):
        rep.warn(f"{name} is set but no compose file names it (fine when a container reads it through env_file)")


def defaults_env(m: dict, stack: Path) -> str:
    """The env file the agent writes for the defaults, on a machine with no GPU."""
    values = {k: str(v) for k, v in m.get("env", {}).items()}
    for s in m.get("secrets", []):
        values[s["env"]] = "x" * s.get("length", 32)
    for s in m.get("settings", []):
        kind = s.get("type")
        if kind == "path":
            values[s["env"]] = s["default"].replace("{stack}", str(stack))
        elif kind == "port":
            values[s["env"]] = str(s["default"])
        elif kind == "bool":
            values.update(s["on"] if s["default"] else s["off"])
        elif kind == "choice":
            values.update(next(o["env"] for o in s["options"] if o["value"] == s["default"]))
        elif kind == "text" and s.get("default"):
            values[s["env"]] = s["default"]
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
        cmd = ["docker", "compose", "-p", f"sbm-{m['id']}", "--env-file", ".env"]
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
    print(f"ok: {manifest.get('id')} {manifest.get('version')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
