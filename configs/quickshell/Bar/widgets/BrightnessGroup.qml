import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44; height: 44

    property bool   menuOpen:    false
    property var    scannedDevs: []
    property bool   scanning:    false
    property string busyMAC:     ""

    readonly property Process _scanListProc: Process {
        command: ["bluetoothctl", "devices"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devs = []
                    const pairedMACs = NetworkState.pairedDevs.map(d => d.mac)
                    for (const line of this.text.trim().split("\n").filter(Boolean)) {
                        const m = line.match(/Device ([0-9A-Fa-f:]+) (.+)/)
                        if (m && !pairedMACs.includes(m[1])) devs.push({ mac: m[1], name: m[2].trim() })
                    }
                    root.scannedDevs = devs
                } catch(e) {}
            }
        }
    }
    property Process _scanOn:  Process { command: ["bluetoothctl", "scan", "on"];  running: false }
    property Process _scanOff: Process { command: ["bluetoothctl", "scan", "off"]; running: false }
    Timer { interval: 3000; running: root.scanning; repeat: true
            onTriggered: { _scanListProc.running = false; _scanListProc.running = true } }
    Timer { interval: 30000; running: root.scanning; repeat: false
            onTriggered: { root.scanning = false; _scanOff.running = false; _scanOff.running = true } }

    Process { id: _btAction; running: false
        onRunningChanged: { if (!running) root.busyMAC = "" } }

    Connections { target: NetworkState; function onPairedDevsChanged() { root.busyMAC = "" } }

    function toggleBluetooth() { NetworkState.toggleBluetooth() }
    function connectDevice(mac)    { root.busyMAC = mac; NetworkState.connectDevice(mac) }
    function disconnectDevice(mac) { root.busyMAC = mac; NetworkState.disconnectDevice(mac) }
    function pairDevice(mac) {
        root.busyMAC = mac
        _btAction.command = ["bluetoothctl", "pair", mac]
        _btAction.running = false; _btAction.running = true
    }
    function removeDevice(mac) { root.busyMAC = mac; NetworkState.removeDevice(mac) }

    Text {
        anchors.centerIn: parent
        text: root.busyMAC !== ""      ? "\u{F0772}"
            : !NetworkState.btOn       ? "\u{F00B2}"
            : NetworkState.btConn      ? "\u{F00B1}"
            :                            "\u{F00AF}"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
        color: root.busyMAC !== ""     ? Colors.color3
             : !NetworkState.btOn      ? Colors.color8
             : NetworkState.btConn     ? Colors.color4
             :                           Colors.foreground
        Behavior on color { ColorAnimation { duration: 150 } }
        RotationAnimator on rotation {
            from: 0; to: 360; duration: 1200; loops: Animation.Infinite
            running: root.busyMAC !== ""
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.menuOpen = !root.menuOpen }
}
