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
    dust
    bat
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
    atuin
    playerctl # MPRIS control - used by the Discord rich-presence daemon
    #---- modern CLI ----#
    ripgrep # rg - grep
    fzf # fuzzy finder
    tealdeer # tldr - man examples
    duf # df - disk usage
    procs # ps - processes
    sd # sed - find/replace
    delta # pretty git diff
    ouch # extract/compress anything
    choose # cut/awk - columns
    gping # ping with a graph
    doggo # dig - DNS
    xh # curl for HTTP/APIs
    yazi # ranger - TUI file manager
    zellij # tmux - multiplexer
    broot # tree nav
    direnv # per-dir env
    just # command runner
    tokei # code line stats
    #---- SHELL ----#
    ranger
    fish
    ghostty
    foot
    starship
    # --- Applications ---
    brave
    renoise
    libreoffice
    librewolf
    vesktop
    zathura
    audacity
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
  # wallpapers ship in the repo so a fresh install has them; the switcher reads
  # ~/.config/wallpapers, so deploy them there
  xdg.configFile."wallpapers" = {
    source = ./configs/wallpapers;
    recursive = true;
  };
  xdg.configFile."fastfetch/config.jsonc".source = ./configs/fastfetch/config.jsonc;
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
      # delta: syntax-highlighted, side-by-side diffs and blame
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta.navigate = true;
      delta.side-by-side = true;
      merge.conflictStyle = "zdiff3";
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
      # more code/markup -> nvim
      "text/markdown" = "nvim.desktop";
      "text/x-markdown" = "nvim.desktop";
      "text/css" = "nvim.desktop";
      "text/javascript" = "nvim.desktop";
      "application/javascript" = "nvim.desktop";
      "application/xml" = "nvim.desktop";
      "text/x-c++src" = "nvim.desktop";
      "text/x-java" = "nvim.desktop";
      "text/x-rust" = "nvim.desktop";
      "text/x-lua" = "nvim.desktop";
      "text/x-sql" = "nvim.desktop";
      # LibreOffice - office documents
      "application/vnd.oasis.opendocument.text" = "writer.desktop";
      "application/msword" = "writer.desktop";
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "writer.desktop";
      "application/rtf" = "writer.desktop";
      "application/vnd.oasis.opendocument.spreadsheet" = "calc.desktop";
      "application/vnd.ms-excel" = "calc.desktop";
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "calc.desktop";
      "text/csv" = "calc.desktop";
      "application/vnd.oasis.opendocument.presentation" = "impress.desktop";
      "application/vnd.ms-powerpoint" = "impress.desktop";
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = "impress.desktop";
      "application/vnd.oasis.opendocument.graphics" = "draw.desktop";
      # more images -> imv
      "image/avif" = "imv.desktop";
      "image/heic" = "imv.desktop";
      "image/jxl" = "imv.desktop";
      # more audio/video -> mpv
      "audio/opus" = "mpv.desktop";
      "audio/x-m4a" = "mpv.desktop";
      "audio/wav" = "mpv.desktop";
      "video/x-ms-wmv" = "mpv.desktop";
      "video/3gpp" = "mpv.desktop";
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

  # EasyEffects: autostart in the background. The effect chain (RNNoise denoise
  # + Autotune, tuned in the GUI) persists in EasyEffects' own db and is restored
  # on login, so no preset is force-loaded here (that would clobber GUI edits).
  services.easyeffects.enable = true;

  # Pin "Easy Effects Source" as the default mic so every app captures the
  # processed (denoise + autotune) stream, not the raw mic.
  systemd.user.services.ee-default-source = {
    Unit = {
      Description = "Pin Easy Effects Source as the default mic";
      After = [ "easyeffects.service" ];
      Requires = [ "easyeffects.service" ];
      PartOf = [ "easyeffects.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
      ExecStart = ''${pkgs.pipewire}/bin/pw-metadata -n default 0 default.configured.audio.source "{\"name\":\"easyeffects_source\"}"'';
    };
    Install = {
      WantedBy = [ "easyeffects.service" ];
    };
  };

  systemd.user.services.niri-refresh-ac = {
    Unit = {
      Description = "Switch eDP-1 to 60Hz on battery, 240Hz on AC";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.writeShellScript "niri-refresh-ac" ''
        export PATH=/run/current-system/sw/bin:$PATH
        apply() {
          NIRI_SOCKET="$(ls -t /run/user/$(id -u)/niri.*.sock 2>/dev/null | head -1)"
          [ -n "$NIRI_SOCKET" ] || return 1
          export NIRI_SOCKET
          if [ "$1" = 1 ]; then
            niri msg output eDP-1 mode "2560x1600@240.000"
          else
            niri msg output eDP-1 mode "2560x1600@60.000"
          fi
        }
        last=""
        while :; do
          on=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)
          if [ "$on" != "$last" ]; then
            if apply "$on"; then last="$on"; fi
          fi
          sleep 3
        done
      ''}";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
  # Wallpaper daemon as a service so it auto-restarts - if awww-daemon dies the
  # wallpaper silently goes black (awww img can't reach the socket).
  systemd.user.services.awww-daemon = {
    Unit = {
      Description = "awww wallpaper daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/run/current-system/sw/bin/awww-daemon";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

  # Discord rich presence for the dashboard's music (mpv MPRIS -> Discord IPC).
  # NOT auto-started - toggle it from the music tab or with systemctl. Needs
  # Vesktop's Rich Presence enabled and a Discord app id in ~/.config/qs-discord-rpc/app_id.
  systemd.user.services.discord-rpc = {
    Unit = {
      Description = "Discord rich presence from the dashboard's mpv (YT Music)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Environment = "PATH=${pkgs.playerctl}/bin:/run/current-system/sw/bin";
      ExecStart = "${pkgs.python3}/bin/python3 %h/.config/quickshell/scripts/qs-discord-rpc.py";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

}
