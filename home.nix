{ ... }:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "bak";
  home-manager.users.dhm = { ... }: {
    home.stateVersion = "25.11";






    home.file.".config/niri/config.kdl" = {
      source = ./configs/niri/config.kdl;
      force = true;
    };


    home.file.".config/rofi/config.rasi".source = ./configs/rofi/config.rasi;
    home.file.".config/rofi/bgselector/style.rasi".source =
      ./configs/rofi/bgselector/style.rasi;

    # home.file.".config/fish/conf.d/fish_frozen_theme.fish".source =
    #   ./configs/fish/conf.d/fish_frozen_theme.fish;
    # home.file.".config/fish/conf.d/fish_frozen_key_bindings.fish".source =
    #   ./configs/fish/conf.d/fish_frozen_key_bindings.fish;
    # home.file.".config/fish/conf.d/rustup.fish".source = ./configs/fish/conf.d/rustup.fish;


    # home.file.".config/wallust/wallust.toml".source = ./configs/wallust/wallust.toml;
    # home.file.".config/wallust/templates".source = ./configs/wallust/templates;

    # home.file.".config/scripts/bgselector.sh".source = ./configs/scripts/bgselector.sh;
    # home.file.".config/scripts/theme-sync.sh".source = ./configs/scripts/theme-sync.sh;
    # home.file.".config/scripts/media-control.sh".source = ./configs/scripts/media-control.sh;
    # home.file.".config/scripts/low-battery-notify.sh".source = ./configs/scripts/low-battery-notify.sh;
    # home.file.".config/scripts/git-cleanup.sh".source = ./configs/scripts/git-cleanup.sh;
    # home.file.".config/scripts/lib/common.sh".source = ./configs/scripts/lib/common.sh;


    home.file.".config/fish/config.fish".source = ./configs/fish/config.fish;
    home.file.".config/fish/conf.d" = {
      source = ./configs/fish/conf.d;
      recursive = true;
    };
    home.file.".config/wallust" = {
      source = ./configs/wallust;
      recursive = true;
    };
    home.file.".config/scripts" = {
      source = ./configs/scripts;
      recursive = true;
    };
    home.file.".config/quickshell" = {
      source = ./configs/quickshell;
      recursive = true;
    };

  };
}
