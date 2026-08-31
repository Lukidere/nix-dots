#!/usr/bin/env python3
"""Post-wallust contrast fixer.

Softdark-style palettes give a lovely dark background but accent colours that sit
almost on top of it (contrast ~1.1), so terminal/prompt text is unreadable. This
lifts each accent's lightness (hue/saturation kept) until it clears a minimum
contrast ratio against the background, leaving background and foreground alone.

Rewrites ~/.cache/wallust/colors.json (quickshell) and the palette lines of
~/.config/ghostty/config (terminal), then tells a running ghostty to reload.
Run it right after `wallust run/theme`.
"""
import json
import colorsys
import os
import re
import subprocess

HOME = os.path.expanduser("~")
COLORS = os.path.join(HOME, ".cache/wallust/colors.json")
GHOSTTY = os.path.join(HOME, ".config/ghostty/config")
WAL_VIM = os.path.join(HOME, ".cache/wal/colors-wal.vim")  # neopywal -> neovim

TARGET = 4.2        # WCAG-ish readable contrast for accents
DIM_TARGET = 2.6    # color8 (bright black) stays deliberately dim but visible


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rgb2hex(rgb):
    return "#" + "".join(f"{max(0, min(255, round(x * 255))):02X}" for x in rgb)


def _lin(x):
    return x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4


def lum(rgb):
    r, g, b = (_lin(x) for x in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def fix(hexc, bg_rgb, lighten, target):
    rgb = hex2rgb(hexc)
    if ratio(rgb, bg_rgb) >= target:
        return hexc
    h, l, s = colorsys.rgb_to_hls(*rgb)
    for _ in range(60):
        l = min(1.0, l + 0.02) if lighten else max(0.0, l - 0.02)
        rgb = colorsys.hls_to_rgb(h, l, s)
        if ratio(rgb, bg_rgb) >= target:
            break
        if l in (0.0, 1.0):
            break
    return rgb2hex(rgb)


def main():
    with open(COLORS) as f:
        d = json.load(f)
    bg = d["special"]["background"]
    bg_rgb = hex2rgb(bg)
    lighten = lum(bg_rgb) < 0.5   # dark bg -> push accents lighter, and vice versa
    cols = d["colors"]

    for i in range(16):
        if i == 0:
            continue  # keep the true-black slot
        k = f"color{i}"
        cols[k] = fix(cols[k], bg_rgb, lighten, DIM_TARGET if i == 8 else TARGET)

    with open(COLORS, "w") as f:
        json.dump(d, f, indent=2)

    if os.path.exists(GHOSTTY):
        out = []
        for ln in open(GHOSTTY).read().split("\n"):
            m = re.match(r"palette = (\d+)=", ln)
            if m and 0 <= int(m.group(1)) <= 15:
                idx = int(m.group(1))
                ln = f"palette = {idx}={cols['color' + str(idx)]}"
            out.append(ln)
        with open(GHOSTTY, "w") as f:
            f.write("\n".join(out))

    _fix_wal_vim()
    subprocess.run(["pkill", "-USR2", "ghostty"], check=False)


def _fix_wal_vim():
    """Same correction for neovim's neopywal palette (its own bg + colour order)."""
    if not os.path.exists(WAL_VIM):
        return
    txt = open(WAL_VIM).read()
    m = re.search(r'let background = "(#[0-9A-Fa-f]{6})"', txt)
    if not m:
        return
    bg_rgb = hex2rgb(m.group(1))
    lighten = lum(bg_rgb) < 0.5

    def repl(mo):
        idx, hexc = int(mo.group(1)), mo.group(2)
        if idx == 0:
            return mo.group(0)
        tgt = DIM_TARGET if idx == 8 else TARGET
        return f'let color{idx} = "{fix(hexc, bg_rgb, lighten, tgt)}"'

    txt = re.sub(r'let color(\d+) = "(#[0-9A-Fa-f]{6})"', repl, txt)
    with open(WAL_VIM, "w") as f:
        f.write(txt)


if __name__ == "__main__":
    main()
