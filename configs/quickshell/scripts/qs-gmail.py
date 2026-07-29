#!/usr/bin/env python3
"""Gmail backend for the quickshell dashboard mail tab.

Auth: ~/.config/qs-gmail/credentials, single line `address@gmail.com:app-password`
(Google app password, requires 2FA). chmod 600.

Commands (JSON on stdout):
  status          -> {"configured": bool}
  count           -> {"unread": int}
  list            -> [{"uid","from","subject","date","unread"}]  (newest first, 30)
  read <uid>      -> {"from","subject","date","body"}  (marks \\Seen)
"""
import email
import imaplib
import json
import os
import re
import sys
from email.header import decode_header
from html import unescape

CRED = os.path.expanduser("~/.config/qs-gmail/credentials")
LIMIT = 30


def out(data):
    print(json.dumps(data))
    sys.exit(0)


def fail(msg):
    print(json.dumps({"error": str(msg)}))
    sys.exit(1)


def dec(value):
    if not value:
        return ""
    return "".join(
        p.decode(c or "utf-8", "replace") if isinstance(p, bytes) else p
        for p, c in decode_header(value)
    )


def connect():
    # tighten perms defensively - dir 700, file 600
    try:
        os.chmod(os.path.dirname(CRED), 0o700)
        os.chmod(CRED, 0o600)
    except OSError:
        pass
    with open(CRED) as f:
        user, _, pw = f.read().strip().partition(":")
    if not user or not pw:
        fail("bad credentials format - expected address:app-password")
    m = imaplib.IMAP4_SSL("imap.gmail.com")
    m.login(user, pw)
    m.select("INBOX")
    return m


def simplify(html_text):
    t = re.sub(r"(?is)<(script|style|head)[^>]*>.*?</\1>", "", html_text)
    t = re.sub(r"(?i)<br\s*/?>", "\n", t)
    t = re.sub(r"(?i)</(p|div|tr|h[1-6]|li|blockquote)>", "\n", t)
    t = re.sub(r"<[^>]+>", "", t)
    t = unescape(t)
    t = re.sub(r"\r", "", t)
    t = re.sub(r"[ \t]{2,}", " ", t)
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()


def part_text(part):
    raw = part.get_payload(decode=True)
    if raw is None:
        return ""
    return raw.decode(part.get_content_charset() or "utf-8", "replace")


def body_text(msg):
    plain = None
    htm = None
    for part in msg.walk():
        ct = part.get_content_type()
        if ct == "text/plain" and plain is None:
            plain = part_text(part)
        elif ct == "text/html" and htm is None:
            htm = part_text(part)
    if plain and plain.strip():
        return plain.strip()
    if htm:
        return simplify(htm)
    return "(no readable content)"


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        out({"configured": os.path.exists(CRED)})

    if not os.path.exists(CRED):
        fail("not configured - put address:app-password into " + CRED)

    m = connect()

    if cmd == "count":
        _, data = m.search(None, "UNSEEN")
        out({"unread": len(data[0].split())})

    if cmd == "list":
        _, data = m.uid("search", None, "ALL")
        uids = data[0].split()[-LIMIT:][::-1]
        mails = []
        for uid in uids:
            _, fdata = m.uid("fetch", uid, "(FLAGS BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])")
            flags = b" ".join(x[0] if isinstance(x, tuple) else x for x in fdata if x)
            hdr_blob = next((x[1] for x in fdata if isinstance(x, tuple)), b"")
            msg = email.message_from_bytes(hdr_blob)
            sender = dec(msg.get("From", ""))
            sender = re.sub(r"\s*<[^>]*>", "", sender).strip().strip('"')
            date = dec(msg.get("Date", ""))
            date = re.sub(r"\s*[+-]\d{4}.*$", "", date).strip()
            mails.append({
                "uid": uid.decode(),
                "from": sender,
                "subject": dec(msg.get("Subject", "")) or "(no subject)",
                "date": date,
                "unread": b"\\Seen" not in flags,
            })
        out(mails)

    if cmd == "read":
        if len(sys.argv) < 3 or not sys.argv[2].isdigit():
            fail("missing/invalid uid")
        uid = sys.argv[2]
        _, fdata = m.uid("fetch", uid, "(RFC822)")
        blob = next((x[1] for x in fdata if isinstance(x, tuple)), None)
        if blob is None:
            fail("mail not found")
        m.uid("store", uid, "+FLAGS", "(\\Seen)")
        msg = email.message_from_bytes(blob)
        out({
            "from": dec(msg.get("From", "")),
            "subject": dec(msg.get("Subject", "")) or "(no subject)",
            "date": dec(msg.get("Date", "")),
            "body": body_text(msg),
        })

    fail("unknown command: " + cmd)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        fail(e)
