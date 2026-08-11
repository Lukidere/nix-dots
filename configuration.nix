#Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  unstable = import inputs.unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # ==========================================
  # 1. Nix & Nixpkgs Settings
  # ==========================================
  nixpkgs.config.allowUnfree = true;
  age.secrets."haslo-user".file = ./configs/secrets/haslo-user.age;
  nix = {
    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    # dedup identical store files via hardlinks - shrinks /nix/store
    optimise.automatic = true;
  };

  security = {
    pam.services.gtklock = { };
    rtkit.enable = true; # Wymagane dla PipeWire
  };

  boot = {
    initrd.kernelModules = [
      "rtw89_8852ce"
      "btusb"
      "btrtl"
      "amdgpu"
    ];
    kernelParams = [ "nvidia-drm.modeset=1" "quiet" "splash" "loglevel=3" "udev.log_level=3" ];
    consoleLogLevel = 0;
    initrd.verbose = false;
    plymouth.enable = true;
    loader = {
      systemd-boot.enable = false;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
      };
      efi.canTouchEfiVariables = true;

    };
    blacklistedKernelModules = [ "nouveau" ];
    kernelPackages = pkgs.linuxPackages_latest;
  };
  # ==========================================
  # 3. Hardware & Graphics (NVIDIA)
  # ==========================================
  hardware = {
    graphics.enable = true;
    enableRedistributableFirmware = true;
    firmware = with pkgs; [ linux-firmware ];

    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  services.usbmuxd.enable = true;
  services.libinput.enable = true; # Touchpad support
  services.power-profiles-daemon.enable = true;
  programs.steam.enable = true;
  # Lid: on battery/AC → suspend (swayidle locks before sleep);
  # docked (external monitor attached) → lock only, session stays on the monitor
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "lock";
  };

  # ==========================================
  # 4. Networking & Time
  # ==========================================
  networking = {
    hostName = "legion";
    networkmanager.enable = true;
  };
  time.timeZone = "Europe/Berlin";

  # ==========================================
  # 5. Audio, Bluetooth & Multimedia
  # ==========================================
  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.blueman.enable = true;

  # ==========================================
  # 6. Desktop Environment (Niri, Greetd, Portals)
  # ==========================================
  programs.niri.enable = true;

  # GTK greeter (regreet) - themed login matching the Rosé Pine dots
  programs.regreet = {
    enable = true;
    font = {
      name = "Iosevka Nerd Font";
      size = 12;
      package = pkgs.nerd-fonts.iosevka;
    };
    settings = {
      GTK = {
        application_prefer_dark_theme = true;
        cursor_theme_name = "Adwaita";
      };
      commands = {
        reboot = [ "systemctl" "reboot" ];
        poweroff = [ "systemctl" "poweroff" ];
      };
    };
    # Mirrors the gtklock lock-screen look (wallust rose-pine template)
    extraCss = ''
      window {
        background-color: rgb(38, 35, 58);
        color: #e0def4;
      }
      label {
        color: #e0def4;
        text-shadow: 0 1px 4px rgba(0, 0, 0, 0.4);
      }
      entry {
        border-radius: 12px;
        padding: 12px 20px;
        font-size: 16px;
        background-color: alpha(#191724, 0.6);
        color: #e0def4;
        border: 2px solid alpha(#31748f, 0.4);
        box-shadow: 0 2px 12px rgba(0, 0, 0, 0.3);
        caret-color: #31748f;
        transition: all 200ms ease;
      }
      entry:focus-within {
        border-color: #31748f;
        box-shadow: 0 0 0 3px alpha(#31748f, 0.2), 0 4px 16px rgba(0, 0, 0, 0.4);
        background-color: alpha(#191724, 0.8);
      }
      button {
        border-radius: 12px;
        padding: 10px 32px;
        background-image: none;
        background-color: alpha(#31748f, 0.2);
        color: #31748f;
        border: 1px solid alpha(#31748f, 0.3);
        transition: all 200ms ease;
      }
      button:hover {
        background-color: alpha(#31748f, 0.35);
        border-color: #31748f;
      }
      button:active {
        background-color: alpha(#31748f, 0.5);
      }
      combobox button, dropdown button {
        padding: 6px 12px;
      }
    '';
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      niri = {
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.RemoteDesktop" = [ "gnome" ];
      };
      common = {
        default = [ "gtk" ];
      };
    };
  };

  # ==========================================
  # 7. System Services & Virtualization
  # ==========================================
  services.dbus.enable = true;
  services.printing.enable = true;

  # Local restic backup of /home → /var/backup (protects against rm -rf, not
  # disk failure). Point repository at an external/remote path for real safety.
  # Password lives in an agenix secret; init once: `sudo restic init -r /var/backup/restic`.
  services.restic.backups.home = {
    initialize = true;
    repository = "/var/backup/restic";
    passwordFile = "/etc/restic-pw";  # plain file, chmod 600 (not in repo)
    paths = [ "/home/dhm" ];
    exclude = [
      "/home/dhm/.cache"
      "/home/dhm/.local/share/Trash"
      "/home/dhm/**/node_modules"
      "/home/dhm/**/target"
      "/home/dhm/**/.git"
      "/home/dhm/dotsy/configs/wallpapers"
    ];
    timerConfig = { OnCalendar = "daily"; Persistent = true; };
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6" ];
  };
  services.tailscale.enable = true;
  services.flatpak.enable = true;
  services.geoclue2.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true; # Emulacja TPM (np. dla Windows 11)
    };
  };

  # ==========================================
  # 8. Users & Global Programs
  # ==========================================
  programs.fish.enable = true;
  users.users.dhm = {
    shell = pkgs.fish;
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets."haslo-user".path;
    extraGroups = [
      "wheel"
      "libvirtd"
      "kvm"
      "video"
      "wireshark"
      "i2c" # ddcutil DDC/CI for external monitor brightness (MSI MAG271R)
    ];
  };

  # DDC/CI over I2C so ddcutil can drive the external monitor's brightness
  hardware.i2c.enable = true;

  # ==========================================
  # 9. Environment Variables & Fonts
  # ==========================================
  environment.variables = {
    EDITOR = "/run/current-system/sw/bin/nvim";
    RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
  };

  fonts.packages = with pkgs; [
    fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
  ];
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  virtualisation.docker.enable = true;

  # PO-token provider for yt-dlp (premium-quality YT Music streams in the dashboard)
  virtualisation.oci-containers = {
    backend = "docker";
    containers.bgutil-pot = {
      # digest-pinned (1.3.1) - tags are mutable, digest locks exact content
      image = "brainicism/bgutil-ytdlp-pot-provider@sha256:1aaa43a0ca72dfca6a6d2129a0fb4a23465c25adb1b043f8aff829a20825646b";
      ports = [ "127.0.0.1:4416:4416" ];
      extraOptions = [ "--init" ];
    };
  };
  # ==========================================
  # 10. System Packages
  # ==========================================
  environment.systemPackages = with pkgs; [
    # --- System & CLI Utilities ---
    cifs-utils
    coreutils
    psmisc
    wget
    wl-clipboard
    # --- Desktop, Wayland & WM Tools ---
    quickshell
    fd
    bluez
    hyprpicker
    fuzzel # dmenu-style picker (backend for bemoji)
    bemoji # emoji/glyph picker, copies to clipboard
    brightnessctl
    ddcutil # external monitor brightness over DDC/CI (MSI MAG271R)
    networkmanagerapplet
    qt6.qtwayland
    qt6.qtdeclarative # qmlls for neovim + qml tooling
    xwayland
    xwayland-satellite
    wallust
    claude-code
    libnotify
    geoclue2
    colloid-icon-theme
    htop
    imv
    (mpv.override { scripts = [ mpvScripts.mpris ]; }) # MPRIS control for headless playback
    yt-dlp
    gtklock
    swayidle
    unstable.awww
    # --- Audio & Media ---
    imagemagick
    gammastep
    obsidian
    pavucontrol # Mikser graficzny dla
    playerctl
    wireplumber # Narzędzie wpctl

    # --- Development & Programming ---
    cargo
    cargo-leptos
    gcc
    gh
    ghc
    haskell-language-server
    uv
    sqlite
    opencode
    nixd
    pyright
    bash-language-server
    clang-tools
    typescript-language-server
    lua-language-server
    ruff
    deadnix
    nixfmt
    shfmt
    shellcheck
    prettier
    stylua
    neovim
    nodejs_24
    openssl
    pkg-config
    (python3.withPackages (ps: [ ps.ytmusicapi ])) # qs-ytmusic.py (dashboard YT Music)
    bun
    rust-analyzer
    rustfmt
    rustc
    trunk
    wasm-bindgen-cli

    # --- Virtualization Tools ---
    spice
    spice-gtk
    spice-protocol
    virt-manager
    virt-viewer
    virtio-win
  ];
  networking.firewall.enable = true;

  # ==========================================
  # 11. System State
  # ==========================================
  system.stateVersion = "26.05";
}
