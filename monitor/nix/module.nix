# A NixOS module for the monitor agent.
#
# `install.sh` cannot work here and is not meant to: its `--system` mode writes
# a unit into /etc/systemd/system, which on NixOS is a read-only symlink into
# the store. Its default (user) mode does work — everything it touches is under
# $HOME — so this module is for the system-wide service, which is the half that
# has no imperative equivalent on this distribution.
#
# Enable with, in configuration.nix:
#
#     imports = [ /path/to/monitor/nix/module.nix ];
#     services.server-box-monitor.enable = true;
#
# ## Why there is a state directory and a symlink in it
#
# The agent resolves three things relative to its *working directory*, and one
# of them it writes:
#
#   config.toml              read, and written when absent or migrated
#   serverbox_monitor.db     the SQLite file
#   frontend/dist            the panel's static files
#
# So the working directory cannot be the package — that is in the store and
# read-only — and it cannot be a plain directory either, because the panel has
# to be found from it. StateDirectory gives the first two a writable home, and
# `preStart` links the third in from the package. Migrations need nothing:
# `sqlx::migrate!` embeds them at compile time.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.server-box-monitor;
in
{
  options.services.server-box-monitor = {
    enable = lib.mkEnableOption "the ServerBox monitor agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "The monitor package to run.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "server-box-monitor";
      description = ''
        The account the agent runs as.

        Not root by default, and the reason is not tidiness: with
        `remote_access.full_access` on, a panel login opens a shell as whoever
        this is. `install.sh` makes the same choice for the same reason.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "server-box-monitor";
      description = "The group the agent runs as.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open the configured port.

        Off by default. The agent's own config decides whether it listens on
        anything but loopback, and opening a port here for a service that is
        not reachable anyway would be a firewall hole with nothing behind it.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3770;
      description = ''
        The port to open when [](#opt-services.server-box-monitor.openFirewall)
        is set. This does *not* configure the agent — that is config.toml's
        job, and duplicating it here would give two answers to one question.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      example = lib.literalExpression ''
        { server = { host = "127.0.0.1"; port = 3770; }; }
      '';
      description = ''
        config.toml, declared. Null leaves the file alone, which is what a
        machine configured through the panel wants: the agent writes its own
        settings there, and a declarative file would be overwritten on every
        rebuild and then rewritten by the agent.

        Set this and the file becomes generated and read-only, so the panel's
        settings page stops being able to persist anything.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = lib.mkIf (cfg.user == "server-box-monitor") {
      server-box-monitor = {
        isSystemUser = true;
        group = cfg.group;
        description = "ServerBox monitor agent";
      };
    };

    users.groups = lib.mkIf (cfg.group == "server-box-monitor") {
      server-box-monitor = { };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    systemd.services.server-box-monitor = {
      description = "ServerBox monitor agent";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      # The collection script shells out to ordinary tools. Giving it the
      # system profile rather than a curated list on purpose: which tools are
      # asked for is `sbm_parser`'s command manifest, and it changes there.
      path = with pkgs; [ coreutils procps util-linux ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/server_box_monitor serve";
        Restart = "on-failure";
        RestartSec = 5;

        User = cfg.user;
        Group = cfg.group;

        StateDirectory = "server-box-monitor";
        StateDirectoryMode = "0750";
        WorkingDirectory = "/var/lib/server-box-monitor";

        # Modest, and honest about why it is not more: with full_access on, the
        # agent's whole purpose is to run commands the user asked for, so a
        # sandbox that stopped it would stop the feature. These are the ones
        # that cost nothing.
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
      };

      preStart = ''
        # The panel, found relative to the working directory. A symlink rather
        # than a copy so that a rebuild moves it without leaving the old one.
        ln -sfn ${cfg.package}/share/server-box-monitor/frontend \
          /var/lib/server-box-monitor/frontend
      ''
      + lib.optionalString (cfg.settings != null) ''
        # Declared config wins, every start. Deliberately clobbering: with
        # `settings` set the file is this module's, and the panel's settings
        # page cannot persist over it.
        install -m 0640 ${
          (pkgs.formats.toml { }).generate "config.toml" cfg.settings
        } /var/lib/server-box-monitor/config.toml
      '';
    };
  };
}
