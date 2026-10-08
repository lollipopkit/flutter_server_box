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
# npm has no equivalent: the panel's hash is, from the repository root,
#
#     nix run nixpkgs#prefetch-npm-deps -- monitor/frontend/package-lock.json
#
# and changes whenever that lock file does.
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
#   refuses before compiling anything. nixpkgs-unstable has 1.97.1 — the
#   version `crates/sbm_ffi/rust-toolchain.toml` pinned then — and is accepted.
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
  # The agent also reads theme packages with fl_lib's `fl_theme`, a path
  # dependency into the `packages/fl_lib` submodule: a checkout without
  # submodules has an empty directory there and the build fails.
  src = lib.cleanSource ../..;

  panel = buildNpmPackage {
    pname = "server-box-monitor-panel";
    version = "0-unstable";
    inherit src;

    sourceRoot = "source/monitor/frontend";

    npmDepsHash = "sha256-0WJgMowLKnP7SUKSCok3bA5eVgSGSpPto3vuqVg897I=";

    nativeBuildInputs = [ nodejs npmHooks.npmConfigHook ];

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
