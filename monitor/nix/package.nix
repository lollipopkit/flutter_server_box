# The monitor agent, built from this repository.
#
# Two builds, because the agent is two things in one directory: a Rust binary
# and the panel it serves. `server.rs` reads `frontend/dist` relative to its
# working directory, so the panel has to be somewhere the module can link to —
# hence `share/server-box-monitor/frontend`, and hence a `frontend` symlink in
# the state directory rather than a copy.
#
# ## The two hashes, and why only one of them is here
#
# `cargoLock.lockFile` points at the workspace lock, so Cargo's side needs no
# vendor hash at all — a guessed or stale one is a class of breakage this
# avoids entirely.
#
# npm has no equivalent, so `npmDepsHash` has to be a hash of the fetched tree.
# Get it with, from the repository root:
#
#     nix run nixpkgs#prefetch-npm-deps -- monitor/frontend/package-lock.json
#
# and paste the result below. It changes whenever that lock file does.
{ lib
, stdenv
, rustPlatform
, buildNpmPackage
, pkg-config
, sqlite
, nix-update-script
}:

let
  # The monorepo root: `monitor` is a workspace member, and the crate it
  # depends on (`crates/sbm_parser`) is a sibling, so the source cannot be
  # `monitor/` alone.
  src = lib.cleanSource ../..;

  panel = buildNpmPackage {
    pname = "server-box-monitor-panel";
    version = "0-unstable";
    inherit src;

    sourceRoot = "source/monitor/frontend";

    # Computed with the command at the top of this file, against
    # monitor/frontend/package-lock.json as of 2026-08-23.
    npmDepsHash = "sha256-6BtSAJfCCrxoRHbySnlPHS5cxnjsbVWgqxhAoGkw19M=";

    # `@serverbox/webui` is a `file:` dependency, so installing here only
    # symlinks it and its own devDependencies are never fetched. The package's
    # `prebuild` script does that install; it is repeated here because
    # buildNpmPackage runs `npm run build` directly.
    preBuild = ''
      npm install --prefix ../../packages/webui
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

  postInstall = ''
    mkdir -p $out/share/server-box-monitor
    ln -s ${panel}/dist $out/share/server-box-monitor/frontend
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
