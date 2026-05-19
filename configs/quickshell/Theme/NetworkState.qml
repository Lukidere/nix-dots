pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string connType:  ""   // "wifi" | "ethernet" | ""
    property string wifiName:  ""
    property string wifiIP:    ""
    property bool   wifiOn:    false

    property bool   btOn:      false
    property bool   btConn:    false
    property string btDevice:  ""
    property string btMAC:     ""
    property var    pairedDevs: []

    // lock flags: stop poll from overwriting state right after a manual toggle
    property bool _lockNet: false
    property bool _lockBt:  false
    property Timer _netLock: Timer { interval: 6000; onTriggered: root._lockNet = false }
    property Timer _btLock:  Timer { interval: 6000; onTriggered: root._lockBt  = false }

    readonly property Process _netProc: Process {
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION device status; echo ===;" +
            "nmcli radio wifi 2>/dev/null; echo ===;" +
            "hostname -I 2>/dev/null | awk '{print $1}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._lockNet) return
                const parts = this.text.split("===\n")
                const lines = (parts[0] || "").trim().split("\n")
                root.wifiOn = (parts[1] || "").trim().toLowerCase() === "enabled"
                root.wifiIP = (parts[2] || "").trim()
                let wifiConn = "", etherConn = false
                for (const line of lines) {
                    const p = line.split(":")
                    const type = p[0], state = p[1], conn = p[2] || ""
                    if (type === "wifi"     && state === "connected") wifiConn = conn
                    if (type === "ethernet" && state === "connected") etherConn = true
                }
                root.connType = etherConn ? "ethernet" : wifiConn ? "wifi" : ""
                root.wifiName = wifiConn
            }
        }
    }
    property Timer _netPoll: Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { root._netProc.running = false; root._netProc.running = true }
    }

    readonly property Process _btProc: Process {
        command: ["sh", "-c",
            "bluetoothctl show 2>/dev/null; echo '---';" +
            "bluetoothctl devices Connected 2>/dev/null; echo '---';" +
            "bluetoothctl devices Paired 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._lockBt) return
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
            }
        }
    }
    property Timer _btPoll: Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { root._btProc.running = false; root._btProc.running = true }
    }

    function toggleWifi() {
        root.wifiOn = !root.wifiOn; root._lockNet = true; _netLock.restart()
        _wifiToggle.command = ["nmcli", "radio", "wifi", root.wifiOn ? "on" : "off"]
        _wifiToggle.running = false; _wifiToggle.running = true
    }
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
        _btConnect.command = ["bluetoothctl", "connect", mac]
        _btConnect.running = false; _btConnect.running = true
    }
    function removeDevice(mac) {
        _btRemove.command = ["bluetoothctl", "remove", mac]
        _btRemove.running = false; _btRemove.running = true
    }

    property Process _wifiToggle: Process { running: false }
    property Process _btToggle:   Process { running: false }
    property Process _btDisconn:  Process { running: false
        onRunningChanged: if (!running) { root._btProc.running = false; root._btProc.running = true }
    }
    property Process _btConnect:  Process { running: false
        onRunningChanged: if (!running) { root._btProc.running = false; root._btProc.running = true }
    }
    property Process _btRemove:   Process { running: false
        onRunningChanged: if (!running) { root._btProc.running = false; root._btProc.running = true }
    }

    Component.onCompleted: { root._netProc.running = false; root._netProc.running = true }
}
