#!/usr/bin/env python3
"""Push the dashboard's mpv (YT Music) MPRIS state to Discord as Rich Presence.

Prerequisites:
  - Vesktop with Rich Presence enabled (Settings -> Vesktop -> Rich Presence),
    which creates the discord-ipc-0 socket this talks to.
  - A Discord Application ID (https://discord.com/developers/applications ->
    New Application -> copy the Application ID) written to
    ~/.config/qs-discord-rpc/app_id  (or the QS_DISCORD_APP_ID env var).

Run it as a toggled user service; it polls mpv and updates the presence.
"""
import glob
import json
import os
import socket
import struct
import subprocess
import sys
import time

APP_ID_FILE = os.path.expanduser("~/.config/qs-discord-rpc/app_id")
PLAYER = "mpv"          # the headless mpv the music dashboard drives
POLL = 3


def app_id():
    v = os.environ.get("QS_DISCORD_APP_ID")
    if v:
        return v.strip()
    try:
        with open(APP_ID_FILE) as f:
            return f.read().strip()
    except OSError:
        return ""


def ipc_path():
    base = os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid())
    hits = glob.glob(os.path.join(base, "discord-ipc-*"))
    hits += glob.glob(os.path.join(base, "*", "discord-ipc-*"))  # flatpak/snap
    return sorted(hits)[0] if hits else None


class IPC:
    def __init__(self, cid):
        self.cid = cid
        self.sock = None

    def connect(self):
        p = ipc_path()
        if not p:
            return False
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(p)
        self.sock = s
        self._send(0, {"v": 1, "client_id": self.cid})
        self._recv()
        return True

    def _send(self, op, payload):
        data = json.dumps(payload).encode()
        self.sock.sendall(struct.pack("<II", op, len(data)) + data)

    def _recv(self):
        hdr = self._read(8)
        if not hdr:
            return None
        _op, ln = struct.unpack("<II", hdr)
        return json.loads(self._read(ln) or b"{}")

    def _read(self, n):
        buf = b""
        while len(buf) < n:
            c = self.sock.recv(n - len(buf))
            if not c:
                return None
            buf += c
        return buf

    def set_activity(self, activity):
        self._send(1, {
            "cmd": "SET_ACTIVITY",
            "args": {"pid": os.getpid(), "activity": activity},
            "nonce": str(time.time()),
        })
        self._recv()

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass
        self.sock = None


def pctl(*args):
    try:
        r = subprocess.run(["playerctl", "-p", PLAYER, *args],
                           capture_output=True, text=True, timeout=3)
        return r.stdout.strip()
    except Exception:
        return ""


def build_activity():
    if pctl("status") != "Playing":
        return None
    title = pctl("metadata", "xesam:title")
    if not title:
        return None
    act = {"type": 2, "details": title[:128]}           # type 2 = Listening
    artist = pctl("metadata", "xesam:artist")
    if artist:
        act["state"] = ("by " + artist)[:128]
    try:
        length = int(pctl("metadata", "mpris:length") or 0) // 1_000_000
        pos = int(float(pctl("position") or 0))
        if length > 0:
            act["timestamps"] = {"end": int(time.time()) + max(0, length - pos)}
    except (ValueError, TypeError):
        pass
    art = pctl("metadata", "mpris:artUrl")
    if art.startswith("http"):
        act["assets"] = {"large_image": art,
                         "large_text": (pctl("metadata", "xesam:album") or title)[:128]}
    return act


def main():
    cid = app_id()
    if not cid:
        sys.stderr.write("no Discord app id - set ~/.config/qs-discord-rpc/app_id\n")
        # exit 0 (not a transient failure) so systemd does not restart-loop, and
        # tell the user how to fix it instead of silently flipping the toggle off
        subprocess.run(
            ["notify-send", "-t", "8000", "Discord RPC",
             "Set your Discord Application ID in ~/.config/qs-discord-rpc/app_id"],
            check=False)
        return
    ipc = IPC(cid)
    last = object()
    while True:
        if not ipc.sock:
            if not ipc.connect():
                time.sleep(5)
                continue
            last = object()
        try:
            act = build_activity()
            key = json.dumps(act, sort_keys=True) if act else None
            if key != last:
                ipc.set_activity(act)      # None clears the presence
                last = key
        except (BrokenPipeError, OSError):
            ipc.close()
            time.sleep(3)
            continue
        time.sleep(POLL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
