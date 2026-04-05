# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:
let unstable = import <nixos-unstable> { };
in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "flakes" "nix-command" ];
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = false;

  # Konfiguracja GRUB
  boot.loader.grub = {
    enable = true;
    device = "nodev"; # "nodev" jest wymagane dla instalacji EFI
    efiSupport = true;
    useOSProber = true;
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.blacklistedKernelModules = [ "nouveau" ];
  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Time zone.
  time.timeZone = "Europe/Berlin";





  # Enable CUPS to print documents.
  services.printing.enable = true;
  #nvidia
  hardware.graphics = {
    enable = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    open = true;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  #niri-config
  programs.niri.enable = true;
  services.flatpak.enable = true;
  programs.fish.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk
  ];
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd \" dbus-run-session niri\"";
        user = "greeter";
      };
    };
  };
  fonts.packages = with pkgs; [
    fira-code
    nerd-fonts.jetbrains-mono
  ];

  # Sound.
  services.pulseaudio.enable = false;

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;

    pulse.enable = true;
    wireplumber.enable = true;
  };

  #Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.dhm = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" "kvm" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree

    ];
  };
  # QEMU i Libvirt
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true; # Emulacja TPM (np. dla Windows 11)
    };
  };
  programs.steam.enable = true;
  environment.variables = {
    EDITOR = "/run/current-system/sw/bin/nvim";
  };
  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    neovim
    wget
    librewolf
    eza
    git
    ghostty
    foot
    cifs-utils
    fish
    tuigreet
    rustc
    jq
    wallust
    cargo-leptos
    cargo
    zoxide
    starship
    grim
    slurp
    waybar
    unstable.awww
    vesktop
    vicinae
    xdg-desktop-portal-gtk
    gcc
    flatpak
    fastfetch
    wl-clipboard
    qt6.qtwayland
    libreoffice
    imagemagick
    rofi
    findutils
    coreutils
    brave
    python3
    unzip
    curl
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    virtio-win

  ];
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib # Wymagane przez wiele narzędzi
    openssl
    curl
    glib
    util-linux
    icu
  ];
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11";
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
}
