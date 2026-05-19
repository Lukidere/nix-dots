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
    inherit (pkgs) system;
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
    kernelParams = [ "nvidia-drm.modeset=1" ];
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

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd \"${pkgs.niri}/bin/niri-session\"";
        user = "greeter";
      };
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-wlr
    ];
    config = {
      niri = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
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
  services.tailscale.enable = true;
  services.flatpak.enable = true;
  services.geoclue2.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
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
    ];
  };

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
    brightnessctl
    networkmanagerapplet
    qt6.qtwayland
    wallust
    claude-code
    libnotify
    geoclue2
    colloid-icon-theme
    htop
    imv
    mpv
    gtklock
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
    nixd
    pyright
    nodePackages.bash-language-server
    nodePackages.typescript-language-server
    lua-language-server
    ruff
    deadnix
    nixfmt-rfc-style
    shfmt
    shellcheck
    nodePackages.prettier
    stylua
    neovim
    nodejs_24
    openssl
    pkg-config
    python3
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
  system.stateVersion = "25.11";
}
