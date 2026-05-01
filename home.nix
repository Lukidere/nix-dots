{ config, pkgs, ... }:
{
  home.stateVersion = "25.11";

  xdg.configFile."niri/config.kdl" = {
    source = ./configs/niri/config.kdl;
    force = true;
  };

  xdg.configFile."nvim" = {
    source = ./configs/nvim;
    recursive = true;
  };

  xdg.configFile."zathura" = {
    source = ./configs/zathura;
    recursive = true;
  };
  xdg.configFile."gtklock" = {
    source = ./configs/gtklock;
    recursive = true;
  };
  xdg.configFile."fish/config.fish".source = ./configs/fish/config.fish;
  xdg.configFile."fish/conf.d" = {
    source = ./configs/fish/conf.d;
    recursive = true;
  };
  xdg.configFile."wallust" = {
    source = ./configs/wallust;
    recursive = true;
  };
  xdg.configFile."scripts" = {
    source = ./configs/scripts;
    recursive = true;
  };
  # home.file.".config/quickshell" = {
  #   source = ./configs/quickshell;
  #   recursive = true;
  # };
  xdg.configFile."quickshell" = {
    source = ./configs/quickshell;
    recursive = true;

  };

}
