# The monitor agent, built from this repository.
#
# Two builds, because the agent is two things in one directory: a Rust binary
# and the panel it serves. `server.rs` reads `frontend/dist` relative to its
# working directory, so the panel has to be somewhere the module can link to —
# hence `share/server-box-monitor/frontend/dist`, and hence a `frontend`
# symlink in the state directory rather than a copy.
#
# ## The hashes
#
# `cargoLock.lockFile` points at the workspace lock, so Cargo's side needs no
# vendor hash at all — a guessed or stale one is a class of breakage this
# avoids entirely.
#
# npm has no equivalent, and there are *two* lock files: the panel's, and
# `packages/webui`'s, which the panel depends on through a `file:` link. Get
# either with, from the repository root:
#
#     nix run nixpkgs#prefetch-npm-deps -- monitor/frontend/package-lock.json
#     nix run nixpkgs#prefetch-npm-deps -- packages/webui/package-lock.json
#
# Each changes whenever its own lock file does.
#
# ## What has actually been built, and what has not
#
# Measured on NixOS 25.11 aarch64, 2026-08-23:
#
# - The panel half **builds**. Both npm dependency sets install offline and
#   `npm run build` completes, which is what the `chmod -R u+w` below and the
#   second `fetchNpmDeps` were added for.
# - The Rust half **needs a newer rustc than nixpkgs 25.11 ships**. That
#   channel has 1.91.1; `sqlx` asks for 1.94 and `sysinfo` for 1.95, so cargo
#   refuses before compiling anything. nixpkgs-unstable has 1.97.1 — the same
#   version `crates/sbm_ffi/rust-toolchain.toml` pins — and is accepted.
# - Against unstable the Rust build then proceeds and was **not seen to
#   finish**: the machine it ran on exhausted its disk while compiling
#   `libsqlite3-sys`. That is a property of that machine, not of this file, and
#   it means `postInstall` below has never run.
#
# So: not a package anyone should assume works. It is as far as one afternoon
# on one VM got, written down rather than rounded up.
{ lib
, rustPlatform
, buildNpmPackage
, fetchNpmDeps
, npmHooks
, nodejs
, pkg-config
, sqlite
, nix-update-script
}:

let
  # The monorepo root: `monitor` is a workspace member, and the crate it
  # depends on (`crates/sbm_parser`) is a sibling, so the source cannot be
  # `monitor/` alone.
  src = lib.cleanSource ../..;

  # `@serverbox/webui` is a `file:` dependency of the panel, so an install in
  # `monitor/frontend` only symlinks it and fetches none of its own packages.
  # The panel needs both halves: `clsx` / `tailwind-merge` /
  # `tailwind-variants` because vite bundles webui's source, and `svelte` /
  # `typescript` because `npm run build` runs `svelte-check` first.
  #
  # A second dependency set rather than one, because `npmDepsHash` below hashes
  # exactly one lock file and this is a different one. The repository solves the
  # same problem with a `prebuild` script that runs `npm install` — which cannot
  # work here, since a Nix build has no network.
  webuiDeps = fetchNpmDeps {
    name = "serverbox-webui-npm-deps";
    src = ../../packages/webui;
    hash = "sha256-XkjHnnOw/WVci9Z8zpKtK42TefzdbEmmlbewoCpFUlg=";
  };

  panel = buildNpmPackage {
    pname = "server-box-monitor-panel";
    version = "0-unstable";
    inherit src;

    sourceRoot = "source/monitor/frontend";

    npmDepsHash = "sha256-6BtSAJfCCrxoRHbySnlPHS5cxnjsbVWgqxhAoGkw19M=";

    nativeBuildInputs = [ nodejs npmHooks.npmConfigHook ];

    # Offline, from the cache above, standing in for the `prebuild` script.
    preBuild = ''
      # Writable first: the source arrives from the store, and buildNpmPackage
      # only makes `sourceRoot` writable — a sibling directory is still
      # r-xr-xr-x, so `npm ci` fails on `mkdir node_modules` with EACCES.
      chmod -R u+w ../../packages/webui
      pushd ../../packages/webui
      npm ci --offline --no-audit --no-fund --cache=${webuiDeps} --nodedir=${nodejs}
      popd
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist $out/dist
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  pname = "server-box-monitor";
  version = "0-unstable";
  inherit src;

  cargoLock.lockFile = ../../Cargo.lock;

  buildAndTestSubdir = "monitor";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ sqlite ];

  # sqlx's macros read `monitor/.sqlx` rather than a live database, which is
  # what makes an offline build possible at all.
  SQLX_OFFLINE = "true";

  # The tests want a database and a network. Left off rather than patched
  # around: `cargo test --workspace` on a developer's machine is where they
  # belong, and a package that pretends to run them is worse than one that
  # says it does not.
  doCheck = false;

  # `frontend/dist`, not `frontend` — `server.rs` reads `frontend/dist`
  # relative to its working directory, and the module links `frontend` from the
  # state directory to what is created here. Linking the panel's output *as*
  # `frontend` puts the files one level too high, and every request 404s with
  # the panel sitting right there.
  postInstall = ''
    mkdir -p $out/share/server-box-monitor/frontend
    ln -s ${panel}/dist $out/share/server-box-monitor/frontend/dist
  '';

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Server-side monitoring agent for ServerBox";
    homepage = "https://github.com/lollipopkit/flutter_server_box";
    license = licenses.agpl3Only;
    mainProgram = "server_box_monitor";
    platforms = platforms.linux;
  };
}
