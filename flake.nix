{

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { nixpkgs, ... }: let

    eachDefaultSystemMap = let
      defaultSystems = ["x86_64-linux" "aarch64-linux"];
    in fn: builtins.foldl' ( acc: sys: acc // { ${sys} = fn sys; } )
                           {}
                           defaultSystems;

    overlays.vu-client = final: prev: {
      vu-client = final.stdenv.mkDerivation {
        pname        = "vu-client";
        version      = "0.1.0";
        src          = ./.;
        buildPhase   = ": # TODO";
        installPhase = "touch "$out";
      };
    };
    overlays.default = overlays.vu-client;

    nixosModules.vu-client = { lib, pkgs, options, config, ... }: let
      cfg = config.services.vu-client;
    in {
      options.services.vu-client = {
        enable = lib.mkEnableOption "Enable VU-client service";

        package = lib.mkOption {
          type        = lib.types.package;
          default     = pkgs.vu-client;
          defaultText = "pkgs.vu-client";
          description = "Set the VU client package to use.";
        };
      };

      config = lib.mkIf cfg.enable {
        nixpkgs.overlays           = [overlays.default];
        environment.systemPackages = [cfg.package];
        systemd.services.vu-client = {
          description      = "VU Dial client daemons.";
          wantedBy         = ["multi-user.target"];
          restartIfChanged = true;
          serviceConfig    = {
            User       = "root";
            Group      = "root";
            ExecStart  = "${cfg.package}/bin/vu-client";
            Restart    = "on-failure";
            RestartSec = "5s";
          };
        };
      };

    };

    nixosModules.default = nixosModules.vu-client;

  in {

    inherit overlays nixosModules;

    packages = eachDefaultSystemMap ( system: let
      pkgsFor = nixpkgs.legacyPackages.${system}.extend overlays.default;
    in {
      inherit (pkgsFor) vu-client;
      default = pkgsFor.vu-client;
    } );



  };

}
