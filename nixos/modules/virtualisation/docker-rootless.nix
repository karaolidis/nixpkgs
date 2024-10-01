{
  config,
  lib,
  pkgs,
  ...
}:
let

  cfg = config.virtualisation.docker.rootless;
  proxy_env = config.networking.proxy.envVars;
  settingsFormat = pkgs.formats.json { };
  daemonSettingsFile = settingsFormat.generate "daemon.json" cfg.daemon.settings;

in

{
  ###### interface

  options.virtualisation.docker.rootless = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        This option enables docker in a rootless mode, a daemon that manages
        linux containers. To interact with the daemon, one needs to set
        {command}`DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock`.
      '';
    };

    listenOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "%t/docker.sock" ];
      description = ''
        A list of unix and tcp sockets docker should listen to. The format follows
        ListenStream as described in systemd.socket(5).
      '';
    };

    enableOnBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When enabled, dockerd-rootless is started on boot. This is required for
        containers which are created with the
        `--restart=always` flag to work. If this option is
        disabled, docker might be started on demand by socket activation.
      '';
    };

    setSocketVariable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Point {command}`DOCKER_HOST` to rootless Docker instance for
        normal users by default.
      '';
    };

    daemon.settings = lib.mkOption {
      type = settingsFormat.type;
      default = { };
      example = {
        ipv6 = true;
        "fixed-cidr-v6" = "fd00::/80";
      };
      description = ''
        Configuration for docker daemon. The attributes are serialized to JSON used as daemon.conf.
        See https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file
      '';
    };

    liveRestore = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Allow dockerd to be restarted without affecting running container.
        This option is incompatible with docker swarm.
      '';
    };

    storageDriver = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "overlay2"
          "fuse-overlayfs"
          "btrfs"
          "vfs"
        ]
      );
      default = null;
      description = ''
        This option determines which Docker
        [storage driver](https://docs.docker.com/engine/security/rootless/#known-limitations/)
        to use.
        By default it lets docker automatically choose the preferred storage
        driver.
        However, it is recommended to specify a storage driver explicitly, as
        docker's default varies over versions.

        ::: {.warning}
        Changing the storage driver will cause any existing containers
        and images to become inaccessible.
        :::
      '';
    };

    logDriver = lib.mkOption {
      type = lib.types.enum [
        "none"
        "json-file"
        "syslog"
        "journald"
        "gelf"
        "fluentd"
        "awslogs"
        "splunk"
        "etwlogs"
        "gcplogs"
        "local"
      ];
      default = "journald";
      description = ''
        This option determines which Docker log driver to use.
      '';
    };

    extraOptions = lib.mkOption {
      type = lib.types.separatedString " ";
      default = "";
      description = ''
        The extra command-line options to pass to
        {command}`docker` daemon.
      '';
    };

    autoPrune = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to periodically prune Docker resources. If enabled, a
          systemd timer will run `docker system prune -f`
          as specified by the `dates` option.
        '';
      };

      flags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "--all" ];
        description = ''
          Any additional flags passed to {command}`docker system prune`.
        '';
      };

      dates = lib.mkOption {
        default = "weekly";
        type = lib.types.str;
        description = ''
          Specification (in the format described by
          {manpage}`systemd.time(7)`) of the time at
          which the prune will occur.
        '';
      };
    };

    package = lib.mkPackageOption pkgs "docker" { };
  };

  ###### implementation

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    environment.extraInit = lib.optionalString cfg.setSocketVariable ''
      if [ -z "$DOCKER_HOST" -a -n "$XDG_RUNTIME_DIR" ]; then
        export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
      fi
    '';

    # Taken from https://github.com/moby/moby/blob/master/contrib/dockerd-rootless-setuptool.sh
    systemd.user.services.docker = {
      wantedBy = lib.optional cfg.enableOnBoot [ "default.target" ];
      after = [
        "network.target"
        "docker.socket"
      ];
      description = "Docker Application Container Engine (Rootless)";
      # needs newuidmap from pkgs.shadow
      path = [ "/run/wrappers" ];
      environment = proxy_env;
      unitConfig = {
        # docker-rootless doesn't support running as root.
        ConditionUser = "!root";
        StartLimitInterval = "60s";
      };
      serviceConfig = {
        Type = "notify";
        ExecStart = "${cfg.package}/bin/dockerd-rootless --config-file=${daemonSettingsFile}";
        ExecReload = "${pkgs.procps}/bin/kill -s HUP $MAINPID";
        TimeoutSec = 0;
        RestartSec = 2;
        Restart = "always";
        StartLimitBurst = 3;
        LimitNOFILE = "infinity";
        LimitNPROC = "infinity";
        LimitCORE = "infinity";
        Delegate = true;
        NotifyAccess = "all";
        KillMode = "mixed";
      };
    };

    systemd.user.sockets.docker = {
      description = "Docker Socket for the API";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = cfg.listenOptions;
        SocketMode = "0660";
      };
      after = [ "network.target" ];
    };

    systemd.user.services.docker-prune = {
      description = "Prune docker resources";

      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;

      serviceConfig.Type = "oneshot";

      script = ''
        ${cfg.package}/bin/docker system prune -f ${toString cfg.autoPrune.flags}
      '';

      startAt = lib.optional cfg.autoPrune.enable cfg.autoPrune.dates;
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
    };

    virtualisation.docker.rootless.daemon.settings = {
      log-driver = lib.mkDefault cfg.logDriver;
      storage-driver = lib.mkIf (cfg.storageDriver != null) (lib.mkDefault cfg.storageDriver);
      live-restore = lib.mkDefault cfg.liveRestore;
    };
  };

}
