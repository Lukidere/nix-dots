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
     - Gmail inbox tab (unread badge, opening a mail marks it read via IMAP, simplified body view)
     - detailed internet/bluetooth control panel with info about the system
- App launcher with subsections and a calculator
- File manager (trash-safe delete, sorting, keyboard navigation, open-terminal-here)
- Themed login (regreet) matching the gtklock lock screen
- Silent boot with plymouth splash
- Notifications with popups and OSD for volume/brightness
- AstroNvim setup with nix-provided LSPs (rust, python, nix, bash, ts, lua, haskell, qml)

### Gmail tab setup
The mail tab reads your inbox over IMAP with a Google app password (never commit it):
1. Google Account → Security → 2-Step Verification → App passwords
2. Generate one for "Mail"
3. <code>mkdir -p ~/.config/qs-gmail && echo "you@gmail.com:your-app-password" > ~/.config/qs-gmail/credentials && chmod 600 ~/.config/qs-gmail/credentials</code>
4. Open the mail tab → Re-check

### YouTube Music setup
1. <code>ytmusicapi browser</code> - paste request headers from an authenticated music.youtube.com tab (copy them from a POST /youtubei/v1/browse request in devtools)
2. <code>mkdir -p ~/.config/qs-ytmusic && mv browser.json ~/.config/qs-ytmusic/</code>
3. <code>~/.config/quickshell/scripts/qs-ytmusic.py cookies</code> - exports cookies.txt for premium-quality streams
