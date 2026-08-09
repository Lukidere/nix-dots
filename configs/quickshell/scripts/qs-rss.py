#!/usr/bin/env python3
"""RSS/Atom backend for the quickshell dashboard news tab.

Feeds: ~/.config/qs-rss/feeds, one URL per line (# comments allowed).
Auto-created with sensible defaults on first run.

Commands (JSON on stdout):
  status  -> {"configured": bool}
  list    -> [{"title","link","source","date","ts"}]  (newest first, 40)
"""
import concurrent.futures
import json
import os
import sys
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

FEEDS = os.path.expanduser("~/.config/qs-rss/feeds")
LIMIT = 40
TIMEOUT = 6
DEFAULTS = [
    "https://news.ycombinator.com/rss",
    "https://www.phoronix.com/rss.php",
    "https://lwn.net/headlines/newrss",
]


def out(data):
    print(json.dumps(data))
    sys.exit(0)


def load_feeds():
    if not os.path.exists(FEEDS):
        os.makedirs(os.path.dirname(FEEDS), exist_ok=True)
        with open(FEEDS, "w") as f:
            f.write("# One feed URL per line. Lines starting with # are ignored.\n")
            f.write("\n".join(DEFAULTS) + "\n")
    urls = []
    with open(FEEDS) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                urls.append(line)
    return urls or DEFAULTS


def _text(el):
    return (el.text or "").strip() if el is not None else ""


def _strip_ns(tag):
    return tag.rsplit("}", 1)[-1]


def parse_date(s):
    if not s:
        return None
    try:
        return parsedate_to_datetime(s)  # RFC822 (RSS)
    except (TypeError, ValueError):
        pass
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))  # ISO (Atom)
    except ValueError:
        return None


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "qs-rss/1.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        raw = r.read()
    root = ET.fromstring(raw)
    # feed title: rss/channel/title or atom feed/title
    source = ""
    for el in root.iter():
        if _strip_ns(el.tag) == "channel":
            for c in el:
                if _strip_ns(c.tag) == "title":
                    source = _text(c)
                    break
            break
    if not source:
        for c in root:
            if _strip_ns(c.tag) == "title":
                source = _text(c)
                break
    # entries: RSS <item> or Atom <entry>
    items = []
    for el in root.iter():
        if _strip_ns(el.tag) not in ("item", "entry"):
            continue
        title = link = date = ""
        for c in el:
            ct = _strip_ns(c.tag)
            if ct == "title" and not title:
                title = _text(c)
            elif ct == "link":
                # RSS: text node; Atom: href attr (prefer rel=alternate)
                href = c.get("href")
                if href:
                    if c.get("rel", "alternate") == "alternate" or not link:
                        link = href
                elif not link:
                    link = _text(c)
            elif ct in ("pubDate", "published", "updated", "date") and not date:
                date = _text(c)
        dt = parse_date(date)
        items.append({
            "title": title or "(untitled)",
            "link": link,
            "source": source,
            "ts": dt.timestamp() if dt else 0.0,
        })
    return items


def _safe_fetch(url):
    try:
        return fetch(url)
    except Exception:
        return []


def rel_date(ts):
    if not ts:
        return ""
    now = datetime.now(timezone.utc).timestamp()
    d = max(0, now - ts)
    if d < 3600:
        return f"{int(d // 60)}m"
    if d < 86400:
        return f"{int(d // 3600)}h"
    return f"{int(d // 86400)}d"


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        load_feeds()  # ensure file exists
        out({"configured": True})

    urls = load_feeds()
    all_items = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        for res in ex.map(_safe_fetch, urls):
            all_items.extend(res)
    all_items.sort(key=lambda x: x["ts"], reverse=True)
    all_items = all_items[:LIMIT]
    for it in all_items:
        it["date"] = rel_date(it["ts"])
    out(all_items)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
