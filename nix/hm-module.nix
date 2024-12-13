self: {
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.tg-check-in-tool;
  defaultPackage = self.defaultPackage.${pkgs.stdenv.hostPlatform.system};
  escapeSystemdName = x: lib.replaceStrings [" " "/"] ["" "-"] x;
in {
  options.programs.tg-check-in-tool = with types; {
    enable = mkEnableOption "Whether or not to enable tg-check-in-tool.";
    package = mkOption {
      type = with types; nullOr package;
      default = defaultPackage;
      defaultText = literalExpression "inputs.tg-check-in-tool.packages.${pkgs.stdenv.hostPlatform.system}.default";
      description = ''
        The tg-check-in-tool package to use.

        By default, this option will use the `packages.default` as exposed by this flake.
      '';
    };
    systemd = mkOption {
      type = types.bool;
      default = pkgs.stdenv.isLinux;
      description = "Whether to enable to systemd service for tg-check-in-tool on linux.";
    };
    environmentFile = lib.mkOption {
      description = ''
        Environment file to be passed to the systemd service.
        Useful for passing secrets to the service to prevent them from being
        world-readable in the Nix store.
      '';
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/var/lib/secrets/tg.env";
    };
    chatMessageList = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Chat and message
      '';
      example = [
        "tgbot1 /checkin"
        "tgbot2 /checkin"
      ];
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services = let
      tg-check-in-tool-service = x: {
        "tg-check-in-tool-${escapeSystemdName x}" = lib.mkIf cfg.systemd {
          Unit = {
            Description = "Systemd service for tg-check-in-tool ${x}";
          };
          Service = {
            EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
            Type = "oneshot";
            ExecStart = "${cfg.package}/bin/tg-check-in-tool ${x}";
            # we want notmuch applied even if there was a problem
            SuccessExitStatus = "0 1";
          };
        };
      };
    in
      lib.mkMerge (lib.map tg-check-in-tool-service cfg.chatMessageList);
    systemd.user.timers = let
      tg-check-in-tool-timer = x: {
        "tg-check-in-tool-${escapeSystemdName x}" = lib.mkIf cfg.systemd {
          Unit = {
            Description = "Systemd timer for tg-check-in-tool ${x}";
          };
          Timer = {
            Unit = "tg-check-in-tool-${escapeSystemdName x}.service";
            OnCalendar = "*-*-* 08:00:00";
            Persistent = true;
            RandomizedDelaySec = "10min";
          };
          Install = {
            WantedBy = ["timers.target"];
          };
        };
      };
    in
      lib.mkMerge (lib.map tg-check-in-tool-timer cfg.chatMessageList);
    home.packages = [
      cfg.package
    ];
  };
}
