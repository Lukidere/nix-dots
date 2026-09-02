# My Nix dots
### Requirements
You really only need nixos with flakes enabled

### How to run it
<code> sudo nixos-rebuild switch --flake github:dhmztr/nix-dots#legion </code>

### Guided install
Clone the repo and run the installer. It runs preflight checks, detects your
monitors and patches the brightness config to match, sets up the Gmail / YouTube
Music / RSS tabs, and offers to rebuild:
<code> git clone https://github.com/dhmztr/nix-dots && cd nix-dots && ./install.sh </code>

Notes: the flake targets host `legion` (rename it or add your own
`nixosConfigurations` entry), and the user password is agenix-encrypted to the
original machine, so set your own secret (see `secrets.nix`). External-monitor
brightness needs a DDC/CI-capable monitor with DDC/CI enabled in its OSD.

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
     - Detailed volume and brightness menu (per-monitor brightness incl. external over DDC/CI)
     - Per-app volume mixer: every app playing audio with its own draggable slider and mute
     - Connection info
     - Eye health toggle
     - Performance tab
     - YouTube Music launcher: search-as-you-type results, playlists, liked songs, build a queue on the fly (+ per track) while music plays - headless mpv with premium-quality streams, seekable progress bar
     - Detailed calendar with weather
     - Pomodoro timer and todo list
     - Interactive coverflow wallpaper carousel (scroll/drag, click or Enter to set) which uses wallust to retheme most apps (cached thumbnails, instant browsing); a contrast pass keeps accent colours readable in the terminal, neovim and shell
     - Notification and clipboard center
     - Gmail inbox tab (unread badge, opening a mail marks it read via IMAP, simplified body view)
     - News tab: merged RSS/Atom feed reader (configurable feeds, click opens in browser)
     - Music tab: toggle Discord rich presence (cover art, progress, link) for what you are listening to
     - detailed internet/bluetooth control panel with info about the system
     - Settings tab: default audio sink, night-light colour temperature + schedule, per-output display scale, wallust palette + a live palette editor (mock-bar preview, per-colour hex/RGB pickers), mic loopback, DND persistence, searchable keybind cheatsheet
- App launcher with subsections and a calculator
- File manager (image thumbnail previews, trash-safe delete, sorting, keyboard navigation, open-terminal-here)
- Emoji picker (bemoji + themed fuzzel, copies to clipboard) and color picker (hyprpicker, copies hex)
- OCR any screen region to the clipboard (grim + tesseract eng/pol, MOD+SHIFT+T)
- Screenshot notifications show a thumbnail preview of the capture
- Mic noise suppression via EasyEffects (RNNoise), auto-loaded on login
- Custom quickshell login screen (greetd): universal username + password with "remember me", clock and power, wallust-themed to match the desktop
- Silent boot with plymouth splash
- Notifications with popups and OSD for volume/brightness
- Fish shell with atuin (fuzzy history), zoxide and starship
- AstroNvim setup with nix-provided LSPs (rust, python, nix, bash, ts, lua, haskell, qml, c)

### Gmail tab setup
The mail tab reads your inbox over IMAP with a Google app password (never commit it):
1. Google Account → Security → 2-Step Verification → App passwords
2. Generate one for "Mail"
3. <code>mkdir -p ~/.config/qs-gmail && echo "you@gmail.com:your-app-password" > ~/.config/qs-gmail/credentials && chmod 600 ~/.config/qs-gmail/credentials</code>
4. Open the mail tab → Re-check

### News (RSS) setup
The news tab ships with sensible defaults (Hacker News, Phoronix, LWN). To customize, edit the auto-created feed list (one URL per line, `#` for comments):
<code>$EDITOR ~/.config/qs-rss/feeds</code>
Most sites expose a feed at <code>/rss</code>, <code>/feed</code> or <code>/atom.xml</code>; Reddit is <code>/r/NAME/.rss</code>, a YouTube channel is <code>/feeds/videos.xml?channel_id=ID</code>.

### YouTube Music setup
1. <code>ytmusicapi browser</code> - paste request headers from an authenticated music.youtube.com tab (copy them from a POST /youtubei/v1/browse request in devtools)
2. <code>mkdir -p ~/.config/qs-ytmusic && mv browser.json ~/.config/qs-ytmusic/</code>
3. <code>~/.config/quickshell/scripts/qs-ytmusic.py cookies</code> - exports cookies.txt for premium-quality streams
