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
      haskell
      qmljs
      kdl
      fish
    ]
  );
in
{
  home.packages = with pkgs; [
    #---- CLI ----#
    glow
    bottom
    curl
    eza
    fastfetch
    findutils
    git
    jujutsu
    docker
    jq
    unzip
    wget
    gh
    zoxide
    #---- SHELL ----#
    ranger
    fish
    ghostty
    foot
    starship
    # --- Applications ---
    brave
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

  # yt-dlp plugin: fetches PO tokens from the bgutil-pot container (configuration.nix)
  home.file.".config/yt-dlp/plugins/bgutil/yt_dlp_plugins".source =
    "${pkgs.python3Packages.bgutil-ytdlp-pot-provider}/${pkgs.python3.sitePackages}/yt_dlp_plugins";

  # Global cargo release profile: stripped + LTO so binaries stay small
  home.file.".cargo/config.toml".text = ''
    [profile.release]
    strip = "symbols"
    lto = true
    codegen-units = 1
  '';
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

  # Declarative git config (was imperative ~/.config/git/config)
  programs.git = {
    enable = true;
    settings = {
      user.name = "dhmztr";
      user.email = "117782259+dhmztr@users.noreply.github.com";
      pull.rebase = false;
      core.editor = "nvim";
      safe.directory = "/etc/nixos";
    };
  };

  # Declarative default applications (was imperative ~/.config/mimeapps.list)
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "librewolf.desktop";
      "x-scheme-handler/https" = "librewolf.desktop";
      "x-scheme-handler/about" = "librewolf.desktop";
      "x-scheme-handler/unknown" = "librewolf.desktop";
      "text/html" = "librewolf.desktop";
      "x-scheme-handler/discord" = "vesktop.desktop";
      "application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";
      "application/epub+zip" = "org.pwmt.zathura.desktop";
      "application/x-cbz" = "org.pwmt.zathura-cb.desktop";
      "application/x-cbr" = "org.pwmt.zathura-cb.desktop";
      "image/png" = "imv.desktop";
      "image/jpeg" = "imv.desktop";
      "image/gif" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "image/bmp" = "imv.desktop";
      "image/tiff" = "imv.desktop";
      "image/svg+xml" = "imv.desktop";
      "image/x-icon" = "imv.desktop";
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/x-flv" = "mpv.desktop";
      "video/ogg" = "mpv.desktop";
      "video/mpeg" = "mpv.desktop";
      "audio/mpeg" = "mpv.desktop";
      "audio/ogg" = "mpv.desktop";
      "audio/flac" = "mpv.desktop";
      "audio/x-wav" = "mpv.desktop";
      "audio/mp4" = "mpv.desktop";
      "audio/aac" = "mpv.desktop";
      "audio/webm" = "mpv.desktop";
      "audio/x-vorbis+ogg" = "mpv.desktop";
      "text/plain" = "nvim.desktop";
      "text/x-csrc" = "nvim.desktop";
      "text/x-python" = "nvim.desktop";
      "text/x-shellscript" = "nvim.desktop";
      "text/xml" = "nvim.desktop";
      "application/json" = "nvim.desktop";
      "application/x-yaml" = "nvim.desktop";
      "application/toml" = "nvim.desktop";
      "x-scheme-handler/terminal" = "com.mitchellh.ghostty.desktop";
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
    };
  };

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/run/current-system/sw/bin/quickshell";
      Restart = "on-failure";
      RestartSec = "1s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

}
