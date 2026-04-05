{ ... }:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.dhm = { ... }: {
    home.stateVersion = "25.11";

    home.file.".config/niri/config.kdl".source = ../../.config/niri/config.kdl;

    home.file.".config/waybar/config.jsonc".source = ../../.config/waybar/config.jsonc;
    home.file.".config/waybar/modules.json".source = ../../.config/waybar/modules.json;
    home.file.".config/waybar/style.css".source = ../../.config/waybar/style.css;
    home.file.".config/waybar/colors.css".source = ../../.config/waybar/colors.css;

    home.file.".config/rofi/config.rasi".source = ../../.config/rofi/config.rasi;
    home.file.".config/rofi/bgselector/style.rasi".source =
      ../../.config/rofi/bgselector/style.rasi;
    home.file.".config/rofi/colors/wallust.rasi".source =
      ../../.config/rofi/colors/wallust.rasi;

    home.file.".config/fish/config.fish".source = ../../.config/fish/config.fish;
    home.file.".config/fish/conf.d/fish_frozen_theme.fish".source =
      ../../.config/fish/conf.d/fish_frozen_theme.fish;
    home.file.".config/fish/conf.d/fish_frozen_key_bindings.fish".source =
      ../../.config/fish/conf.d/fish_frozen_key_bindings.fish;
    home.file.".config/fish/conf.d/rustup.fish".source = ../../.config/fish/conf.d/rustup.fish;

    home.file.".config/ghostty/config".source = ../../.config/ghostty/config;

    home.file.".config/wallust/wallust.toml".source = ../../.config/wallust/wallust.toml;
    home.file.".config/wallust/templates".source = ../../.config/wallust/templates;

    home.file.".config/scripts/bgselector.sh".source = ../../.config/scripts/bgselector.sh;
    home.file.".config/scripts/theme-sync.sh".source = ../../.config/scripts/theme-sync.sh;
    home.file.".config/scripts/media-control.sh".source = ../../.config/scripts/media-control.sh;
    home.file.".config/scripts/low-battery-notify.sh".source =
      ../../.config/scripts/low-battery-notify.sh;
    home.file.".config/scripts/git-cleanup.sh".source = ../../.config/scripts/git-cleanup.sh;
    home.file.".config/scripts/lib/common.sh".source = ../../.config/scripts/lib/common.sh;
  };
}
