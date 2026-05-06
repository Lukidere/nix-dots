import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44; height: 44

    property bool   menuOpen:    false

    // State
    property bool   btOn:        false
    property bool   btConn:      false
    property string btDevice:    ""
    property string btMAC:       ""
    property var    pairedDevs:  []
    property var    scannedDevs: []
    property bool   scanning:    false
    property string busyMAC:     ""

    // ── State polling ─────────────────────────────────────────────
    readonly property Process _btProc: Process {
        command: ["sh", "-c",
            "bluetoothctl show 2>/dev/null; echo '---';" +
            "bluetoothctl devices Connected 2>/dev/null; echo '---';" +
            "bluetoothctl devices Paired 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = this.text.split("---\n")
                    root.btOn = /Powered: yes/.test(parts[0] || "")

                    // Connected devices
                    const connLines = (parts[1] || "").trim().split("\n").filter(Boolean)
                    if (connLines.length > 0) {
                        const m = connLines[0].match(/Device ([0-9A-Fa-f:]+) (.+)/)
                        if (m) {
                            root.btConn   = true
                            root.btMAC    = m[1]
                            root.btDevice = m[2].trim()
                        } else {
                            root.btConn = false; root.btMAC = ""; root.btDevice = ""
                        }
                    } else {
                        root.btConn = false; root.btMAC = ""; root.btDevice = ""
                    }

                    // Paired devices
                    const paired = []
                    const pairedLines = (parts[2] || "").trim().split("\n").filter(Boolean)
                    for (const line of pairedLines) {
                        const pm = line.match(/Device ([0-9A-Fa-f:]+) (.+)/)
                        if (pm) {
                            paired.push({
                                mac:       pm[1],
                                name:      pm[2].trim(),
                                connected: connLines.some(l => l.includes(pm[1]))
                            })
                        }
                    }
                    root.pairedDevs = paired
                } catch(e) { console.log("BT poll error:", e) }
            }
        }
    }
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { root._btProc.running = false; root._btProc.running = true }
    }
    onMenuOpenChanged: {
        if (menuOpen) { root._btProc.running = false; root._btProc.running = true }
    }

    // ── Scan for new devices ──────────────────────────────────────
    readonly property Process _scanListProc: Process {
        command: ["bluetoothctl", "devices"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devs = []
                    const pairedMACs = root.pairedDevs.map(d => d.mac)
                    for (const line of this.text.trim().split("\n").filter(Boolean)) {
                        const m = line.match(/Device ([0-9A-Fa-f:]+) (.+)/)
                        if (m && !pairedMACs.includes(m[1])) {
                            devs.push({ mac: m[1], name: m[2].trim() })
                        }
                    }
                    root.scannedDevs = devs
                } catch(e) {}
            }
        }
    }
    property Process _scanOn:  Process { command: ["bluetoothctl", "scan", "on"];  running: false }
    property Process _scanOff: Process { command: ["bluetoothctl", "scan", "off"]; running: false }
    Timer {
        interval: 3000; running: root.scanning; repeat: true
        onTriggered: { _scanListProc.running = false; _scanListProc.running = true }
    }
    Timer {
        interval: 30000; running: root.scanning; repeat: false
        onTriggered: { root.scanning = false; _scanOff.running = false; _scanOff.running = true }
    }

    // ── Actions ───────────────────────────────────────────────────
    Process {
        id: _btToggle
        running: false
        onRunningChanged: { if (!running) { root._btProc.running = false; root._btProc.running = true } }
    }
    Process {
        id: _btAction
        running: false
        onRunningChanged: {
            if (!running) {
                root.busyMAC = ""
                root._btProc.running = false; root._btProc.running = true
            }
        }
    }

    function toggleBluetooth() {
        const on = !root.btOn
        root.btOn = on
        _btToggle.command = on ? ["bluetoothctl", "power", "on"] : ["bluetoothctl", "power", "off"]
        _btToggle.running = false; _btToggle.running = true
        if (!on) { root.scanning = false; _scanOff.running = false; _scanOff.running = true }
    }

    function connectDevice(mac) {
        root.busyMAC = mac
        _btAction.command = ["bluetoothctl", "connect", mac]
        _btAction.running = false; _btAction.running = true
    }
    function disconnectDevice(mac) {
        root.busyMAC = mac
        _btAction.command = ["bluetoothctl", "disconnect", mac]
        _btAction.running = false; _btAction.running = true
    }
    function pairDevice(mac) {
        root.busyMAC = mac
        _btAction.command = ["bluetoothctl", "pair", mac]
        _btAction.running = false; _btAction.running = true
    }
    function removeDevice(mac) {
        root.busyMAC = mac
        _btAction.command = ["bluetoothctl", "remove", mac]
        _btAction.running = false; _btAction.running = true
    }

    // ── Bar button icon ───────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        text: root.busyMAC !== "" ? "\u{F0772}"
            : !root.btOn          ? "\u{F00B2}"
            : root.btConn         ? "\u{F00B1}"
            :                       "\u{F00AF}"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
        color: root.busyMAC !== "" ? Colors.color3
             : !root.btOn          ? Colors.color8
             : root.btConn         ? Colors.color4
             :                       Colors.foreground
        Behavior on color { ColorAnimation { duration: 150 } }
        RotationAnimator on rotation {
            from: 0; to: 360; duration: 1200; loops: Animation.Infinite
            running: root.busyMAC !== ""
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.menuOpen = !root.menuOpen }
}
