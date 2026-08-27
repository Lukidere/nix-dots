#!/usr/bin/env python3
"""List playback audio streams (per-app) for the dashboard volume mixer.

  qs-appvol.py list  -> [{"id": int, "label": str, "volume": int, "muted": bool}]

Volume is set from QML directly via `wpctl set-volume <id> <0..1>`.
"""
import json
import re
import subprocess
import sys


def streams():
    try:
        data = json.loads(subprocess.run(
            ["pw-dump"], capture_output=True, text=True, timeout=4).stdout)
    except Exception:
        return []
    out = []
    for n in data:
        p = (n.get("info") or {}).get("props") or {}
        if p.get("media.class") != "Stream/Output/Audio":
            continue
        label = (p.get("application.name") or p.get("media.name")
                 or p.get("node.name") or "app")
        out.append({"id": n.get("id"), "label": str(label)})
    return out


def volume(sid):
    try:
        t = subprocess.run(["wpctl", "get-volume", str(sid)],
                           capture_output=True, text=True, timeout=3).stdout
    except Exception:
        return 0, False
    m = re.search(r"Volume:\s*([\d.]+)", t)
    vol = int(round(float(m.group(1)) * 100)) if m else 0
    return vol, "[MUTED]" in t


def main():
    if (sys.argv[1] if len(sys.argv) > 1 else "list") != "list":
        sys.exit(0)
    res = []
    for s in streams():
        vol, muted = volume(s["id"])
        res.append({"id": s["id"], "label": s["label"], "volume": vol, "muted": muted})
    print(json.dumps(res))


if __name__ == "__main__":
    main()
