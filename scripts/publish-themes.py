#!/usr/bin/env python3
"""Publish the official themes in store/ that changed since their last version.

    scripts/publish-themes.py [--dry-run] [--bump minor] [<id>[=<version>] ...]

The same publisher a third-party theme author runs in their own repository —
the serverbox-theme skill's scripts/publish.py — with store/ as the theme
repository. Packages go to this repository's `themes` release, a pre-release
that is never Latest: Latest is only ever an app release. See that script for
what it checks and in which order, and docs/src/content/docs/development/themes.md.
"""

import os
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
publisher = root / ".claude" / "skills" / "serverbox-theme" / "scripts" / "publish.py"
os.execv(sys.executable, [sys.executable, str(publisher), "--root", str(root / "store"), *sys.argv[1:]])
