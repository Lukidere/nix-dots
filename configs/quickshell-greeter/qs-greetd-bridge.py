#!/usr/bin/env python3
"""Bridge between the quickshell greeter (QML) and greetd.

greetd frames each message as a 4-byte native-endian length followed by a JSON
payload. QML's Process/Socket reads line-delimited streams, not length-prefixed
frames, so this translates: line-JSON on stdin/stdout <-> greetd's framing on the
socket at $GREETD_SOCK.

--mock plays the protocol back without greetd so the UI can be built inside a
normal session (MOCK_PASSWORD selects the accepted password, default "test").

Nothing derived from the password is ever written to a log; error text carrying a
byte offset would leak its length.
"""
import json
import os
import socket
import struct
import sys
import threading

HEADER = struct.Struct("=I")  # native-endian u32, as greetd expects
MAX_FRAME = 1 << 20


def out(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def fail(desc):
    out({"type": "error", "error_type": "error", "description": desc})


class Conn:
    def __init__(self, path):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)
        self.lock = threading.Lock()

    def send(self, obj):
        payload = json.dumps(obj).encode()
        with self.lock:
            self.sock.sendall(HEADER.pack(len(payload)) + payload)

    def _recv(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                return None
            buf += chunk
        return buf

    def recv(self):
        head = self._recv(HEADER.size)
        if head is None:
            return None
        (length,) = HEADER.unpack(head)
        if length > MAX_FRAME:
            raise ValueError("frame too large")
        body = self._recv(length)
        return None if body is None else json.loads(body)


def run_real(path):
    try:
        conn = Conn(path)
    except OSError:
        fail("cannot connect to the login service")
        return 1

    def reader():
        while True:
            try:
                msg = conn.recv()
            except Exception:
                fail("lost connection to the login service")
                os._exit(1)
            if msg is None:
                fail("lost connection to the login service")
                os._exit(1)
            out(msg)

    threading.Thread(target=reader, daemon=True).start()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except ValueError:
            fail("internal error")
            return 1
        try:
            conn.send(req)
        except OSError:
            fail("lost connection to the login service")
            return 1
    return 0


def run_mock():
    password = os.environ.get("MOCK_PASSWORD", "test")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except ValueError:
            continue
        kind = req.get("type")
        if kind == "create_session":
            out({"type": "auth_message", "auth_message_type": "secret", "auth_message": "Password:"})
        elif kind == "post_auth_message_response":
            if req.get("response") == password:
                out({"type": "success"})
            else:
                out({"type": "error", "error_type": "auth_error", "description": "Authentication failure"})
        elif kind in ("start_session", "cancel_session"):
            out({"type": "success"})
    return 0


if __name__ == "__main__":
    if "--mock" in sys.argv[1:]:
        sys.exit(run_mock())
    sock = os.environ.get("GREETD_SOCK")
    if not sock:
        fail("GREETD_SOCK unset")
        sys.exit(1)
    sys.exit(run_real(sock))
