#Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:
let
  unstable = import <nixos-unstable> { };
in
{
  imports = [
    ./hardware-configuration.nix
    <home-manager/nixos>
    ./home.nix
  ];

  # ==========================================
  # 1. Nix & Nixpkgs Settings
  # ==========================================
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "flakes" "nix-command" ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # ==========================================
  # 2. Bootloader & Kernel
  # ==========================================
  boot.loader.systemd-boot.enable = false;

  boot.loader.grub = {
    enable = true;
    device = "nodev"; # "nodev" jest wymagane dla instalacji EFI
    efiSupport = true;
    useOSProber = true;
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ==========================================
  # 3. Hardware & Graphics (NVIDIA)
  # ==========================================
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.libinput.enable = true; # Touchpad support

  # ==========================================
  # 4. Networking & Time
  # ==========================================
  networking.hostName = "legion";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Berlin";

  # ==========================================
  # 5. Audio, Bluetooth & Multimedia
  # ==========================================
  security.rtkit.enable = true; # Wymagane dla PipeWire
  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  hardware.bluetooth.enable = true;
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
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;

  users.users.dhm = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" "kvm" ];
    packages = with pkgs; [ tree ];
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
  ];

  # ==========================================
  # 10. System Packages
  # ==========================================
  environment.systemPackages = with pkgs; [
    # --- System & CLI Utilities ---
    bottom
    cifs-utils
    coreutils
    curl
    eza
    fastfetch
    findutils
    git
    jq
    psmisc
    unzip
    wget
    wl-clipboard
    zoxide

    # --- Terminal & Shell ---
    fish
    foot
    ghostty
    starship
    tuigreet

    # --- Desktop, Wayland & WM Tools ---
    quickshell
    fd
    grim
    brightnessctl
    mako
    networkmanagerapplet
    qt6.qtwayland
    rofi
    slurp
    wallust
    waybar
    claude-code
    # --- Audio & Media ---
    imagemagick
    pavucontrol # Mikser graficzny dla PipeWire/Waybar
    playerctl
    wireplumber # Narzędzie wpctl dla Waybara

    # --- Development & Programming ---
    cargo
    cargo-leptos
    gcc
    neovim
    nodejs_24
    openssl
    pkg-config
    python3
    rust-analyzer
    rustc
    trunk
    wasm-bindgen-cli

    # --- Applications ---
    brave
    steam
    libreoffice
    librewolf
    vesktop
    zathura
    unstable.awww
    vicinae

    # --- Virtualization Tools ---
    spice
    spice-gtk
    spice-protocol
    virt-manager
    virt-viewer
    virtio-win
  ];

  # ==========================================
  # 11. System State
  # ==========================================
  system.copySystemConfiguration = true;
  system.stateVersion = "25.11";
}
