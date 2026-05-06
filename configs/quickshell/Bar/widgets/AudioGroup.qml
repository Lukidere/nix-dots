import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44; height: 44

    property bool   menuOpen:       false

    // Connection state (from device status poll)
    property string wifiDev:        ""
    property bool   wifiOn:         false
    property string wifiName:       ""
    property string wifiIP:         ""
    property int    wifiSignal:     0
    property string ethDev:         ""
    property bool   ethOn:          false
    property string ethConn:        ""

    // Network list (from wifi scan)
    property var    networks:       []

    // Action state
    property string connectingSSID: ""
    property string promptSSID:     ""      // non-empty → show password prompt for this SSID
    property bool   _lockNet:       false   // ignore poll results briefly after toggle

    Timer { id: _netLock; interval: 6000; onTriggered: root._lockNet = false }

    // ── Device / connection status ────────────────────────────────
    readonly property Process _netProc: Process {
        command: ["sh", "-c",
            "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null; echo '---';" +
            "hostname -I 2>/dev/null | awk '{print $1}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._lockNet) return
                try {
                    const parts = this.text.split("---\n")
                    const lines = (parts[0] || "").trim().split("\n")
                    let foundEth = false, foundWifi = false
                    for (const line of lines) {
                        const p = line.split(":")
                        if (p.length < 4) continue
                        const dev = p[0], type = p[1], state = p[2], conn = p[3]
                        if (type === "ethernet") {
                            root.ethDev = dev
                            root.ethOn  = state === "connected"
                            root.ethConn = root.ethOn ? conn : ""
                            foundEth = true
                        }
                        if (type === "wifi") {
                            root.wifiDev = dev
                            if (state === "unavailable") {
                                root.wifiOn = false; root.wifiName = ""
                            } else if (state === "connected") {
                                root.wifiOn = true;  root.wifiName = conn
                            } else if (state === "disconnected" || state === "unmanaged") {
                                root.wifiOn = true;  root.wifiName = ""
                            }
                            foundWifi = true
                        }
                    }
                    if (!foundEth)  { root.ethDev  = ""; root.ethOn  = false; root.ethConn  = "" }
                    if (!foundWifi) { root.wifiDev = ""; root.wifiOn = false; root.wifiName = "" }
                    const ip = (parts[1] || "").trim()
                    root.wifiIP = (root.wifiName !== "") ? ip : ""
                } catch(e) { console.log("WiFi netProc error:", e) }
            }
        }
    }
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { root._netProc.running = false; root._netProc.running = true }
    }

    // ── WiFi scan (SSID + signal + security + ACTIVE) ─────────────
    readonly property Process _scanProc: Process {
        // Use ACTIVE (yes/no) — more reliable than IN-USE (* / empty)
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,ACTIVE", "device", "wifi", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const seen = new Set()
                    const list = []
                    for (const line of this.text.trim().split("\n")) {
                        if (!line) continue
                        // Parse right-to-left so SSIDs containing ":" are safe
                        const a = line.lastIndexOf(":")
                        if (a < 0) continue
                        const active   = line.slice(a + 1)               // "yes"/"no"
                        const r1       = line.slice(0, a)
                        const s = r1.lastIndexOf(":")
                        if (s < 0) continue
                        const security = r1.slice(s + 1)
                        const r2       = r1.slice(0, s)
                        const g = r2.lastIndexOf(":")
                        if (g < 0) continue
                        const signal   = parseInt(r2.slice(g + 1)) || 0
                        const ssid     = r2.slice(0, g)
                        if (!ssid || seen.has(ssid)) continue
                        seen.add(ssid)
                        list.push({ ssid, signal, security, inUse: active === "yes" })
                    }
                    list.sort((a, b) =>
                        (b.inUse   ? 100 : 0) - (a.inUse   ? 100 : 0) ||
                        b.signal - a.signal)
                    root.networks = list
                    const cur = list.find(n => n.inUse)
                    root.wifiSignal = cur ? cur.signal : 0
                } catch(e) { console.log("WiFi scan error:", e) }
            }
        }
    }

    // Refresh on popup open
    onMenuOpenChanged: {
        if (menuOpen) {
            root._netProc.running  = false; root._netProc.running  = true
            root._scanProc.running = false; root._scanProc.running = true
        }
    }

    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: {
            root._netProc.running = false; root._netProc.running = true
            if (root.wifiOn) { root._scanProc.running = false; root._scanProc.running = true }
        }
    }

    // ── Background rescan when not connected ──────────────────────
    Process {
        id: _rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        running: false
        onRunningChanged: { if (!running) _rescanDelay.restart() }
    }
    Timer { id: _rescanDelay; interval: 2000; onTriggered: { root._scanProc.running = false; root._scanProc.running = true } }
    Component.onCompleted: { _rescanProc.running = false; _rescanProc.running = true }
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: { if (root.wifiOn && root.wifiName === "") { _rescanProc.running = false; _rescanProc.running = true } }
    }

    // ── Connect / disconnect ──────────────────────────────────────
    Process {
        id: _connectProc
        running: false
        onRunningChanged: {
            if (!running) {
                root.connectingSSID = ""
                root._netProc.running  = false; root._netProc.running  = true
                root._scanProc.running = false; root._scanProc.running = true
            }
        }
    }
    Process {
        id: _disconnectProc
        running: false
        onRunningChanged: { if (!running) { root._netProc.running = false; root._netProc.running = true } }
    }
    Process {
        id: _toggleProc
        running: false
        onRunningChanged: { if (!running) { root._netProc.running = false; root._netProc.running = true } }
    }

    // Password prompt: try saved profile; if still not connected after 3s → ask for password
    Timer {
        id: _promptTimer
        property string ssid: ""
        interval: 3000; running: false; repeat: false
        onTriggered: {
            if (root.wifiName !== ssid && root.connectingSSID === "") {
                root.promptSSID = ssid
            }
        }
    }

    // ── Public API ────────────────────────────────────────────────
    function connectToNetwork(ssid) {
        root.connectingSSID = ssid
        root.promptSSID     = ""
        const esc = ssid.replace(/'/g, "'\\''")
        _connectProc.command = ["sh", "-c",
            "nmcli --wait 30 connection up id '" + esc + "'" +
            " || nmcli --wait 30 device wifi connect '" + esc + "'"]
        _connectProc.running = false; _connectProc.running = true
        _promptTimer.ssid = ssid
        _promptTimer.restart()
    }

    function connectWithPassword(ssid, pass) {
        root.connectingSSID = ssid
        root.promptSSID     = ""
        const escSsid = ssid.replace(/'/g, "'\\''")
        const escPass = pass.replace(/'/g, "'\\''")
        _connectProc.command = ["sh", "-c",
            "nmcli --wait 30 device wifi connect '" + escSsid + "' password '" + escPass + "'"]
        _connectProc.running = false; _connectProc.running = true
    }

    function disconnectWifi() {
        const cmd = root.wifiDev !== ""
            ? ["nmcli", "device", "disconnect", root.wifiDev]
            : ["sh", "-c", "nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2==\"wifi\"{print $1;exit}' | xargs -r nmcli dev disconnect"]
        _disconnectProc.command = cmd
        _disconnectProc.running = false; _disconnectProc.running = true
    }

    function toggleWifi() {
        const on = !root.wifiOn
        root.wifiOn = on
        root._lockNet = true; _netLock.restart()
        _toggleProc.command = on ? ["nmcli", "radio", "wifi", "on"] : ["nmcli", "radio", "wifi", "off"]
        _toggleProc.running = false; _toggleProc.running = true
        if (on) _wifiOnDelay.restart()
    }
    Timer {
        id: _wifiOnDelay; interval: 3000; repeat: false
        onTriggered: { _rescanProc.running = false; _rescanProc.running = true }
    }

    // ── Bar button icon ───────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        text: root.ethOn            ? "\u{F0200}"
            : !root.wifiOn          ? "\u{F092D}"
            : root.wifiName === ""  ? "\u{F092C}"
            : root.wifiSignal > 75  ? "\u{F092B}"
            : root.wifiSignal > 50  ? "\u{F092A}"
            : root.wifiSignal > 25  ? "\u{F0929}"
            :                         "\u{F0928}"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
        color: root.ethOn            ? Colors.color5
             : root.wifiName !== ""  ? Colors.foreground
             : root.wifiOn           ? Colors.color8
             :                         Colors.color1
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    MouseArea { anchors.fill: parent; onClicked: root.menuOpen = !root.menuOpen }
}
