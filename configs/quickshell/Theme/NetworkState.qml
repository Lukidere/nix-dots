pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // ── network state (single source of truth - Bar popup + Dashboard) ──
    property string connType:  ""   // "wifi" | "ethernet" | ""
    property string wifiName:  ""
    property string wifiIP:    ""
    property bool   wifiOn:    false
    property string wifiDev:   ""
    property bool   ethOn:     false
    property string ethConn:   ""
    property int    wifiSignal: 0
    property var    networks:  []

    // ── wifi action state ──
    property string connectingSSID:     ""
    property string lastWifiError:      ""
    property string lastAttemptSSID:    ""
    property bool   lastAttemptSecured: false
    property bool   wifiMenuOpen:       false   // written by the bar widget; gates radio scans

    property bool   btOn:      false
    property bool   btConn:    false
    property string btDevice:  ""
    property string btMAC:     ""
    property var    pairedDevs: []
    property string lastBtError: ""

    // lock flags: stop poll from overwriting state right after a manual toggle
    property bool _lockNet: false
    property bool _lockBt:  false
    property Timer _netLock: Timer { interval: 6000; onTriggered: root._lockNet = false }
    property Timer _btLock:  Timer { interval: 6000; onTriggered: root._lockBt  = false }

    readonly property Process _netProc: Process {
        command: ["sh", "-c",
            "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null; echo ===;" +
            "nmcli radio wifi 2>/dev/null; echo ===;" +
            "hostname -I 2>/dev/null | awk '{print $1}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._lockNet) return
                try {
                    const parts = this.text.split("===\n")
                    const lines = (parts[0] || "").trim().split("\n")
                    root.wifiOn = (parts[1] || "").trim().toLowerCase() === "enabled"
                    let wifiConn = "", wifiDev = "", ethConn = "", ethUp = false
                    for (const line of lines) {
                        const p = line.split(":")
                        if (p.length < 4) continue
                        const dev = p[0], type = p[1], state = p[2], conn = p[3] || ""
                        if (type === "ethernet" && state === "connected") { ethUp = true; ethConn = conn }
                        if (type === "wifi") { wifiDev = dev; if (state === "connected") wifiConn = conn }
                    }
                    root.wifiDev  = wifiDev
                    root.ethOn    = ethUp
                    root.ethConn  = ethConn
                    root.wifiName = wifiConn
                    root.connType = ethUp ? "ethernet" : wifiConn ? "wifi" : ""
                    const ip = (parts[2] || "").trim()
                    root.wifiIP = wifiConn !== "" ? ip : ""
                } catch (e) { console.warn("NetworkState net parse:", e) }
            }
        }
    }
    property Timer _netPoll: Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { root._netProc.running = false; root._netProc.running = true }
    }

    // ── wifi scan ──
    readonly property Process _scanProc: Process {
        // ponytail: popup closed → --rescan no reads NM cache only, no radio wakeups
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,ACTIVE", "device", "wifi", "list"]
                 .concat(root.wifiMenuOpen ? [] : ["--rescan", "no"])
        running: false
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
                        (b.inUse ? 100 : 0) - (a.inUse ? 100 : 0) ||
                        b.signal - a.signal)
                    root.networks = list
                    const cur = list.find(n => n.inUse)
                    root.wifiSignal = cur ? cur.signal : 0
                } catch (e) { console.warn("NetworkState scan parse:", e) }
            }
        }
    }
    property Timer _scanPoll: Timer {
        interval: 10000; running: root.wifiOn; repeat: true
        onTriggered: { root._scanProc.running = false; root._scanProc.running = true }
    }

    // ── background rescan (radio) - only while popup open and not connected ──
    property Process _rescanProc: Process {
        command: ["nmcli", "device", "wifi", "rescan"]
        running: false
        onExited: root._rescanDelay.restart()
    }
    property Timer _rescanDelay: Timer {
        interval: 2000
        onTriggered: { root._scanProc.running = false; root._scanProc.running = true }
    }
    property Timer _rescanPoll: Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: {
            if (root.wifiOn && root.wifiName === "" && root.wifiMenuOpen) {
                root._rescanProc.running = false; root._rescanProc.running = true
            }
        }
    }

    // ── bluetooth poll ──
    readonly property Process _btProc: Process {
        command: ["sh", "-c",
            "bluetoothctl show 2>/dev/null; echo '---';" +
            "bluetoothctl devices Connected 2>/dev/null; echo '---';" +
            "bluetoothctl devices Paired 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._lockBt) return
                try {
                    const parts = this.text.split("---\n")
                    root.btOn = /Powered: yes/.test(parts[0] || "")
                    const connLines = (parts[1] || "").trim().split("\n").filter(Boolean)
                    if (connLines.length > 0) {
                        const m = connLines[0].match(/Device ([0-9A-Fa-f:]+) (.+)/)
                        if (m) { root.btConn = true; root.btMAC = m[1]; root.btDevice = m[2].trim() }
                        else   { root.btConn = false; root.btMAC = ""; root.btDevice = "" }
                    } else { root.btConn = false; root.btMAC = ""; root.btDevice = "" }
                    const paired = []
                    for (const line of (parts[2] || "").trim().split("\n").filter(Boolean)) {
                        const pm = line.match(/Device ([0-9A-Fa-f:]+) (.+)/)
                        if (pm) paired.push({
                            mac:       pm[1],
                            name:      pm[2].trim(),
                            connected: connLines.some(l => l.includes(pm[1]))
                        })
                    }
                    root.pairedDevs = paired
                } catch (e) { console.warn("NetworkState bt parse:", e) }
            }
        }
    }
    property Timer _btPoll: Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { root._btProc.running = false; root._btProc.running = true }
    }

    // ── wifi actions ──
    function refreshWifi() {
        _netProc.running  = false; _netProc.running  = true
        _scanProc.running = false; _scanProc.running = true
    }

    function toggleWifi() {
        root.wifiOn = !root.wifiOn; root._lockNet = true; _netLock.restart()
        _wifiToggle.command = ["nmcli", "radio", "wifi", root.wifiOn ? "on" : "off"]
        _wifiToggle.running = false; _wifiToggle.running = true
        if (root.wifiOn) _wifiOnDelay.restart()
    }
    property Timer _wifiOnDelay: Timer {
        interval: 3000
        onTriggered: { root._rescanProc.running = false; root._rescanProc.running = true }
    }

    function connectToNetwork(ssid, secured) {
        root.connectingSSID = ssid
        root.lastWifiError  = ""
        root.lastAttemptSSID = ssid
        root.lastAttemptSecured = secured
        _connectProc.pendingPass = ""
        // SSID as positional param - never interpolated into the shell string
        _connectProc.command = ["sh", "-c",
            'nmcli --wait 30 connection up id "$1" || nmcli --wait 30 device wifi connect "$1"',
            "sh", ssid]
        _connectProc.running = false; _connectProc.running = true
    }

    function connectWithPassword(ssid, pass) {
        root.connectingSSID = ssid
        root.lastWifiError  = ""
        root.lastAttemptSSID = ssid
        root.lastAttemptSecured = true
        // ponytail: password via stdin passwd-file - never on argv (visible in ps);
        // nmcli --ask is broken on NixOS (spawns its own polkit agent, helper missing).
        // ceiling: hardcoded wpa-psk - pure-WPA3(SAE) networks need key-mgmt sae; add if one shows up
        _connectProc.pendingPass = "wifi-sec.psk:" + pass + "\n"
        _connectProc.stdinEnabled = true
        _connectProc.command = ["sh", "-c",
            'nmcli connection delete id "$1" >/dev/null 2>&1;' +
            'nmcli connection add type wifi con-name "$1" ssid "$1" wifi-sec.key-mgmt wpa-psk >/dev/null && ' +
            'nmcli --wait 30 connection up id "$1" passwd-file /dev/stdin',
            "sh", ssid]
        _connectProc.running = false; _connectProc.running = true
    }

    function disconnectWifi() {
        _wifiDisconn.command = root.wifiDev !== ""
            ? ["nmcli", "device", "disconnect", root.wifiDev]
            : ["sh", "-c", "nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2==\"wifi\"{print $1;exit}' | xargs -r nmcli dev disconnect"]
        _wifiDisconn.running = false; _wifiDisconn.running = true
    }

    property Process _connectProc: Process {
        running: false
        stdinEnabled: true
        property string pendingPass: ""
        onStarted: {
            if (pendingPass !== "") {
                write(pendingPass)
                pendingPass = ""
                stdinEnabled = false   // close stdin → EOF so passwd-file /dev/stdin read completes
            }
        }
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root.connectingSSID = ""
            if (exitCode === 0) {
                root.lastWifiError = ""
            } else {
                const err = (stderr.text || "").trim()
                root.lastWifiError = err !== "" ? err.split("\n")[0] : ("connect failed (" + exitCode + ")")
            }
            root.refreshWifi()
        }
    }
    property Process _wifiDisconn: Process {
        running: false
        onExited: root.refreshWifi()
    }
    property Process _wifiToggle: Process { running: false }

    // ── bluetooth actions ──
    function toggleBluetooth() {
        root.btOn = !root.btOn
        if (!root.btOn) { root.btConn = false; root.btMAC = ""; root.btDevice = "" }
        root._lockBt = true; _btLock.restart()
        _btToggle.command = root.btOn ? ["bluetoothctl", "power", "on"] : ["bluetoothctl", "power", "off"]
        _btToggle.running = false; _btToggle.running = true
    }
    function disconnectDevice(mac) {
        _btDisconn.command = ["bluetoothctl", "disconnect", mac]
        _btDisconn.running = false; _btDisconn.running = true
    }
    function connectDevice(mac) {
        root.lastBtError = ""
        _btConnect.command = ["bluetoothctl", "connect", mac]
        _btConnect.running = false; _btConnect.running = true
    }
    function removeDevice(mac) {
        _btRemove.command = ["bluetoothctl", "remove", mac]
        _btRemove.running = false; _btRemove.running = true
    }

    property Process _btToggle:   Process { running: false }
    property Process _btDisconn:  Process { running: false
        onRunningChanged: if (!running) { root._btProc.running = false; root._btProc.running = true }
    }
    property Process _btConnect:  Process { running: false
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const err = (stderr.text || "").trim()
                root.lastBtError = err !== "" ? err.split("\n")[0] : "connect failed"
            }
            root._btProc.running = false; root._btProc.running = true
        }
    }
    property Process _btRemove:   Process { running: false
        onRunningChanged: if (!running) { root._btProc.running = false; root._btProc.running = true }
    }

    Component.onCompleted: {
        root._netProc.running = false;  root._netProc.running = true
        root._scanProc.running = false; root._scanProc.running = true
    }
}
