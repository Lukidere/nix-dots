{ ... }:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "bak";
  home-manager.users.dhm = { ... }: {
    home.stateVersion = "25.11";

    # ---------------------------------------------------------------------------
    # dhmshell (Caelestia shell fork) – installed via flake.nix
    # ---------------------------------------------------------------------------
    # The `programs.caelestia` option is provided by dhmshell's Home Manager
    # module (homeManagerModules.default injected in flake.nix).
    #
    # After switching:
    #   sudo nixos-rebuild switch --flake .#legion
    #
    # The shell is managed as a systemd user service (caelestia.service) that
    # starts when graphical-session.target is reached (i.e. when niri launches).
    # Check its status with:
    #   systemctl --user status caelestia
    #   journalctl --user -u caelestia -f
    programs.caelestia = {
      enable = true;

      # niri activates graphical-session.target via niri-session, so this is the
      # correct target for starting the shell on niri.
      systemd.target = "graphical-session.target";

      # Pass required environment variables so Qt/QPA work properly on niri.
      systemd.environment = [
        "QT_QPA_PLATFORMTHEME=gtk3"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION=1"
      ];

      settings = {
        # Use ghostty as the shell's built-in terminal launcher.
        general.apps.terminal = [ "ghostty" ];

        # Disable smart (auto) scheme generation so wallust stays in charge of
        # the color scheme via its caelestia-scheme.json template.
        services.smartScheme = false;
      };
    };

    home.file.".config/niri/config.kdl" = {
      source = ./configs/niri/config.kdl;
      force = true;
    };

    home.file.".config/waybar/config.jsonc".source = ./configs/waybar/config.jsonc;
    home.file.".config/waybar/modules.json".source = ./configs/waybar/modules.json;
    home.file.".config/waybar/style.css".source = ./configs/waybar/style.css;

    home.file.".config/rofi/config.rasi".source = ./configs/rofi/config.rasi;
    home.file.".config/rofi/bgselector/style.rasi".source =
      ./configs/rofi/bgselector/style.rasi;

    home.file.".config/fish/config.fish".source = ./configs/fish/config.fish;
    home.file.".config/fish/conf.d/fish_frozen_theme.fish".source =
      ./configs/fish/conf.d/fish_frozen_theme.fish;
    home.file.".config/fish/conf.d/fish_frozen_key_bindings.fish".source =
      ./configs/fish/conf.d/fish_frozen_key_bindings.fish;
    home.file.".config/fish/conf.d/rustup.fish".source = ./configs/fish/conf.d/rustup.fish;


    home.file.".config/wallust/wallust.toml".source = ./configs/wallust/wallust.toml;
    home.file.".config/wallust/templates".source = ./configs/wallust/templates;

    home.file.".config/scripts/bgselector.sh".source = ./configs/scripts/bgselector.sh;
    home.file.".config/scripts/theme-sync.sh".source = ./configs/scripts/theme-sync.sh;
    home.file.".config/scripts/media-control.sh".source = ./configs/scripts/media-control.sh;
    home.file.".config/scripts/low-battery-notify.sh".source =
      ./configs/scripts/low-battery-notify.sh;
    home.file.".config/scripts/git-cleanup.sh".source = ./configs/scripts/git-cleanup.sh;
    home.file.".config/scripts/lib/common.sh".source = ./configs/scripts/lib/common.sh;
  };
}
