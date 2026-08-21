#!/usr/bin/env bash
# dotsy installer - preflight checks, monitor detection, per-service setup.
# Safe to re-run; each step is idempotent and asks before changing anything.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DEFAULT="legion"

# ── tiny ui helpers ──────────────────────────────────────────────────
c()  { printf '\033[%sm%s\033[0m' "$1" "$2"; }
say()  { printf '%s %s\n' "$(c '1;34' '::')" "$1"; }
ok()   { printf '%s %s\n' "$(c '1;32' ' ok')" "$1"; }
warn() { printf '%s %s\n' "$(c '1;33' '  !')" "$1"; }
die()  { printf '%s %s\n' "$(c '1;31' 'err')" "$1" >&2; exit 1; }
ask()  { local a; read -rp "$(c '1;36' '  ? ')$1 [y/N] " a; [[ "$a" =~ ^[Yy]$ ]]; }

# ── preflight ────────────────────────────────────────────────────────
preflight() {
    say "Preflight"
    [[ $EUID -ne 0 ]] || die "run as your user, not root (it will sudo when needed)"
    command -v nix  >/dev/null || die "nix not found - install NixOS / the nix package manager first"
    command -v git  >/dev/null || die "git not found"
    if ! nix --extra-experimental-features 'nix-command flakes' flake --help >/dev/null 2>&1; then
        warn "flakes not enabled; add to /etc/nixos/configuration.nix:"
        warn '  nix.settings.experimental-features = [ "nix-command" "flakes" ];'
    fi
    ok "environment looks sane"
}

# ── hardware + host ──────────────────────────────────────────────────
check_host() {
    say "Host configuration"
    local h; h="$(hostname)"
    if [[ "$h" != "$HOST_DEFAULT" ]]; then
        warn "this flake targets host '$HOST_DEFAULT' but you are on '$h'."
        warn "either rename your host, or duplicate the flake nixosConfigurations entry for '$h'."
    fi
    if [[ ! -f "$REPO/hardware-configuration.nix" ]]; then
        warn "no hardware-configuration.nix in the repo."
        if ask "generate one now from this machine?"; then
            sudo nixos-generate-config --show-hardware-config | sudo tee "$REPO/hardware-configuration.nix" >/dev/null
            ok "wrote hardware-configuration.nix (review it before rebuilding)"
        fi
    else
        ok "hardware-configuration.nix present"
    fi
    warn "secrets are agenix-encrypted to this machine's key - set your own password secret"
    warn "  (see secrets.nix). A fresh clone cannot decrypt the original."
}

# ── monitor detection + patch ────────────────────────────────────────
detect_internal() {
    local d name
    for d in /sys/class/drm/card*-eDP-* /sys/class/drm/card*-LVDS-* /sys/class/drm/card*-DSI-*; do
        [[ -e "$d/status" ]] || continue
        [[ "$(cat "$d/status")" == connected ]] || continue
        name="$(basename "$d")"; echo "${name#card*-}"; return 0
    done
    return 1
}
detect_ac() {
    local d
    for d in /sys/class/power_supply/*; do
        [[ "$(cat "$d/type" 2>/dev/null)" == Mains ]] && { basename "$d"; return 0; }
    done
    return 1
}
detect_ext_model() {
    command -v ddcutil >/dev/null || return 1
    # first non-empty Model: (laptop panels report an empty model)
    ddcutil detect 2>/dev/null \
        | sed -n 's/^[[:space:]]*Model:[[:space:]]*\([^[:space:]].*\)$/\1/p' \
        | sed 's/[[:space:]]*$//' | head -1
}

configure_monitors() {
    say "Monitor detection"
    local internal ac ext
    internal="$(detect_internal || true)"
    ac="$(detect_ac || true)"
    ext="$(detect_ext_model || true)"
    printf '   internal panel : %s\n' "${internal:-not found}"
    printf '   AC supply      : %s\n' "${ac:-not found}"
    printf '   external (DDC) : %s\n' "${ext:-not found (connect it + enable DDC/CI in the OSD; needs i2c group + reboot)}"

    # defaults baked into the configs
    local D_INT="eDP-1" D_AC="ACAD" D_EXT="MSI MAG271R"
    local qc="$REPO/configs/quickshell/Bar/Dashboard/QuickControls.qml"
    local hn="$REPO/home.nix"
    local ni="$REPO/configs/niri/config.kdl"

    if [[ -n "$internal" && "$internal" != "$D_INT" ]] && ask "set internal connector to '$internal'?"; then
        sed -i "s/\"$D_INT\"/\"$internal\"/g; s/eDP-1 mode/$internal mode/g" "$ni" "$hn"
        ok "patched internal connector -> $internal"
    fi
    if [[ -n "$ac" && "$ac" != "$D_AC" ]] && ask "set AC supply to '$ac'?"; then
        sed -i "s#power_supply/$D_AC/online#power_supply/$ac/online#g" "$hn"
        ok "patched AC supply -> $ac"
    fi
    if [[ -n "$ext" && "$ext" != "$D_EXT" ]] && ask "set external monitor model to '$ext' for brightness (ddcutil)?"; then
        sed -i "s/\"$D_EXT\"/\"$ext\"/g" "$qc"
        ok "patched ddcutil model -> $ext"
    fi
    [[ -z "$ext" ]] && warn "no external monitor over DDC/CI - the per-monitor brightness slider will no-op there"
}

# ── per-service credentials ──────────────────────────────────────────
setup_gmail() {
    local f="$HOME/.config/qs-gmail/credentials"
    [[ -f "$f" ]] && { ok "Gmail already configured"; return; }
    ask "set up the Gmail inbox tab now?" || return
    warn "needs a Google App Password (Account > Security > 2FA > App passwords)"
    local addr pw
    read -rp "   gmail address: " addr
    read -rsp "   app password : " pw; echo
    [[ -n "$addr" && -n "$pw" ]] || { warn "skipped (empty input)"; return; }
    mkdir -p "$(dirname "$f")"; printf '%s:%s\n' "$addr" "$pw" > "$f"; chmod 600 "$f"
    ok "wrote $f (chmod 600)"
}
setup_ytmusic() {
    local d="$HOME/.config/qs-ytmusic"
    [[ -f "$d/browser.json" ]] && { ok "YouTube Music already configured"; return; }
    ask "set up YouTube Music now?" || return
    warn "run:  ytmusicapi browser   (paste request headers from an authed music.youtube.com tab)"
    warn "then: mv browser.json $d/  &&  $HOME/.config/quickshell/scripts/qs-ytmusic.py cookies"
    mkdir -p "$d"; ok "created $d - finish the two commands above after rebuild"
}
setup_rss() {
    local f="$HOME/.config/qs-rss/feeds"
    [[ -f "$f" ]] && { ok "RSS feeds already present"; return; }
    mkdir -p "$(dirname "$f")"
    printf '# one feed URL per line, # for comments\n%s\n%s\n%s\n' \
        "https://news.ycombinator.com/rss" \
        "https://www.phoronix.com/rss.php" \
        "https://lwn.net/headlines/newrss" > "$f"
    ok "seeded default RSS feeds at $f"
}
setup_discord() {
    local f="$HOME/.config/qs-discord-rpc/app_id"
    [[ -s "$f" ]] && { ok "Discord rich presence already configured"; return; }
    ask "set up Discord rich presence (music tab) now?" || return
    warn "create an app at https://discord.com/developers/applications and copy its"
    warn "Application ID (its name becomes the 'Listening to ...' label). Also enable"
    warn "Rich Presence in Vesktop settings."
    local id
    read -rp "   Discord Application ID: " id
    [[ -n "$id" ]] || { warn "skipped (empty)"; return; }
    mkdir -p "$(dirname "$f")"; printf '%s\n' "$id" > "$f"
    ok "wrote $f - toggle it from the music tab after rebuild"
}

# ── build ────────────────────────────────────────────────────────────
rebuild() {
    say "Build"
    local host="$HOST_DEFAULT"
    ask "run 'sudo nixos-rebuild switch --flake .#$host' now?" || {
        warn "skipped - run it yourself when ready:"
        warn "  sudo nixos-rebuild switch --flake $REPO#$host"
        return
    }
    sudo nixos-rebuild switch --flake "$REPO#$host"
    ok "system built - log out/in (or reboot for i2c) to pick everything up"
}

main() {
    printf '%s\n' "$(c '1;35' 'dotsy installer')"
    preflight
    check_host
    configure_monitors
    say "Per-service setup"
    setup_gmail
    setup_ytmusic
    setup_rss
    setup_discord
    rebuild
    say "Done. See README.md for the manual bits (secrets, host rename)."
}
main "$@"
