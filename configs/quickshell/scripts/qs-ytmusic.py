#!/usr/bin/env python3
"""YT Music backend for the quickshell dashboard music tab.

Auth (one-time): run `ytmusicapi browser` and save the result to
~/.config/qs-ytmusic/browser.json (paste request headers from an
authenticated music.youtube.com tab - works with a paid plan).

Commands (all print JSON to stdout):
  status              -> {"configured": bool}
  search <query>      -> [track]
  playlists           -> [{"id","title","count"}]
  playlist <id>       -> [track]
  liked               -> [track]
  cookies             -> writes Netscape cookies.txt next to browser.json (for yt-dlp)

track = {"id","title","artist","duration","cover"}
"""
import json
import os
import sys

AUTH = os.path.expanduser("~/.config/qs-ytmusic/browser.json")


def out(data):
    print(json.dumps(data))
    sys.exit(0)


def fail(msg):
    print(json.dumps({"error": str(msg)}))
    sys.exit(1)


def track(t):
    artists = t.get("artists") or []
    thumbs = t.get("thumbnails") or []
    return {
        "id": t.get("videoId") or "",
        "title": t.get("title") or "",
        "artist": ", ".join(a.get("name", "") for a in artists if a.get("name")),
        "duration": t.get("duration_seconds") or 0,
        "cover": thumbs[-1].get("url", "") if thumbs else "",
    }


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        out({"configured": os.path.exists(AUTH)})

    if not os.path.exists(AUTH):
        fail("not configured - run: ytmusicapi browser, save to " + AUTH)

    if cmd == "cookies":
        headers = json.load(open(AUTH))
        raw = next((v for k, v in headers.items() if k.lower() == "cookie"), "")
        if not raw:
            fail("no Cookie header in " + AUTH)
        path = os.path.join(os.path.dirname(AUTH), "cookies.txt")
        with open(path, "w") as f:
            f.write("# Netscape HTTP Cookie File\n")
            for part in raw.split(";"):
                if "=" not in part:
                    continue
                name, _, value = part.strip().partition("=")
                f.write("\t".join([".youtube.com", "TRUE", "/", "TRUE", "0", name, value]) + "\n")
        os.chmod(path, 0o600)
        out({"written": path})

    from ytmusicapi import YTMusic

    yt = YTMusic(AUTH)

    if cmd == "search":
        if len(sys.argv) < 3 or not sys.argv[2].strip():
            fail("empty query")
        res = yt.search(sys.argv[2], filter="songs", limit=25)
        out([track(t) for t in res if t.get("videoId")])

    if cmd == "playlists":
        res = yt.get_library_playlists(limit=50)
        out([
            {"id": p.get("playlistId", ""), "title": p.get("title", ""),
             "count": str(p.get("count", ""))}
            for p in res if p.get("playlistId")
        ])

    if cmd == "playlist":
        if len(sys.argv) < 3:
            fail("missing playlist id")
        res = yt.get_playlist(sys.argv[2], limit=200)
        out([track(t) for t in res.get("tracks", []) if t.get("videoId")])

    if cmd == "liked":
        res = yt.get_liked_songs(limit=100)
        out([track(t) for t in res.get("tracks", []) if t.get("videoId")])

    fail("unknown command: " + cmd)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:  # surface any API error as JSON
        fail(e)
