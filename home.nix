{ config, pkgs, ... }:
let
  treesitterGrammars = pkgs.vimPlugins.nvim-treesitter.withPlugins (
    p: with p; [
      vimdoc
      vim
      lua
      nix
      bash
      rust
      python
      javascript
      typescript
      tsx
      json
      yaml
      toml
      markdown
      markdown_inline
      regex
    ]
  );
in
{
  home.packages = with pkgs; [
    #---- CLI ----#
    bottom
    curl
    eza
    fastfetch
    findutils
    git
    jq
    unzip
    wget
    zoxide
    #---- SHELL ----#
    ranger
    fish
    ghostty
    foot
    starship
    tuigreet
    # --- Applications ---
    brave
    steam
    libreoffice
    librewolf
    vesktop
    zathura

  ];
  home.stateVersion = "25.11";

  xdg.configFile."niri/config.kdl" = {
    source = ./configs/niri/config.kdl;
    force = true;
  };

  xdg.configFile."nvim" = {
    source = ./configs/nvim;
    recursive = true;
  };

  xdg.configFile."nvim/nix-ts-path.lua".text = ''
    vim.opt.runtimepath:append("${treesitterGrammars}")
  '';

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

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
  };

}
