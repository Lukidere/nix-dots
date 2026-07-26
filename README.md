# My Nix dots
### Requirements
You really only need nixos with flakes enabled

### How to run it
<code> sudo nixos-rebuild switch --flake github:Lukidere/nix-dots#legion </code>

### What does it contain

- Interactive bar:
     - Calendar with clock
     - Terminal/htop runners
     - Cpu,ram,disk usage
     - mpris media widget
     - niri workspaces visualization
     - sound, brightness controler
     - wifi/bluetooth controls
     - battery info
     - power menu
- Dashboard
     - Detailed volume and brightness menu
     - Connection info
     - Eye health toggle
     - Performance tab
     - YouTube Music player (search, playlists, liked songs - headless mpv playback with premium quality streams)
     - Detailed calendar with weather
     - Pomodoro timer and todo list
     - Interactive wallpaper changer which uses wallust to change theme of most apps (cached thumbnails, instant browsing)
     - Notification and clipboard center
     - detailed internet/bluetooth control panel with info about the system
- App launcher with subsections and a calculator
- File manager (trash-safe delete, sorting, keyboard navigation, open-terminal-here)
- Themed login (regreet) matching the gtklock lock screen
- Silent boot with plymouth splash
- Notifications with popups and OSD for volume/brightness
- AstroNvim setup with nix-provided LSPs (rust, python, nix, bash, ts, lua, haskell, qml)
