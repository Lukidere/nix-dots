import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    height: col.implicitHeight

    property bool   btOn:        false
    property bool   btConn:      false
    property string btDevice:    ""
    property string btMAC:       ""
    property var    pairedDevs:  []
    property var    scannedDevs: []
    property bool   scanning:    false
    property string busyMAC:     ""

    // ── State polling ───────────────────────────────────────────────
    readonly property Process _btProc: Process {
        command: ["sh","-c",
            "bluetoothctl show 2>/dev/null; echo '---';" +
            "bluetoothctl devices Connected 2>/dev/null; echo '---';" +
            "bluetoothctl devices Paired 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("---\n")
                root.btOn = /Powered: yes/.test(parts[0] || "")

                // connected devices
                const connLines = (parts[1] || "").trim().split("\n").filter(Boolean)
                if (connLines.length > 0) {
                    const m = connLines[0].match(/Device ([0-9A-Fa-f:]+) (.+)/)
                    if (m) {
                        root.btConn = true
                        root.btMAC = m[1]
                        root.btDevice = m[2].trim()
                    } else {
                        root.btConn = false; root.btMAC = ""; root.btDevice = ""
                    }
                } else {
                    root.btConn = false; root.btMAC = ""; root.btDevice = ""
                }

                // paired devices
                const paired = []
                const pairedLines = (parts[2] || "").trim().split("\n").filter(Boolean)
                for (const line of pairedLines) {
                    const pm = line.match(/Device ([0-9A-Fa-f:]+) (.+)/)
                    if (pm) {
                        paired.push({
                            mac: pm[1],
                            name: pm[2].trim(),
                            connected: connLines.some(l => l.includes(pm[1]))
                        })
                    }
                }
                root.pairedDevs = paired
            }
        }
    }

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { root._btProc.running = false; root._btProc.running = true }
    }

    // ── Scan for new devices ────────────────────────────────────────
    readonly property Process _scanListProc: Process {
        command: ["bluetoothctl","devices"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const devs = []
                const pairedMACs = root.pairedDevs.map(d => d.mac)
                this.text.trim().split("\n").filter(Boolean).forEach(line => {
                    const m = line.match(/Device ([0-9A-Fa-f:]+) (.+)/)
                    if (m && !pairedMACs.includes(m[1])) {
                        devs.push({ mac: m[1], name: m[2].trim() })
                    }
                })
                root.scannedDevs = devs
            }
        }
    }

    Process { id: _scanOn;  command: ["bluetoothctl","scan","on"];  running: false }
    Process { id: _scanOff; command: ["bluetoothctl","scan","off"]; running: false }

    Timer {
        id: _scanRefresh
        interval: 3000; running: root.scanning; repeat: true
        onTriggered: { _scanListProc.running = false; _scanListProc.running = true }
    }
    Timer {
        id: _scanTimeout
        interval: 30000; running: root.scanning; repeat: false
        onTriggered: { root.scanning = false; _scanOff.running = true }
    }

    // ── Actions ─────────────────────────────────────────────────────
    Process { id: _btToggle; running: false
        onRunningChanged: if (!running) { _btProc.running = false; _btProc.running = true }
    }
    Process { id: _btAction; running: false
        onRunningChanged: {
            if (!running) {
                root.busyMAC = ""
                _btProc.running = false; _btProc.running = true
            }
        }
    }
    Process { id: _openBtMgr; command: ["blueman-manager"]; running: false }

    function connectDevice(mac) {
        root.busyMAC = mac
        _btAction.command = ["bluetoothctl","connect",mac]
        _btAction.running = false; _btAction.running = true
    }
    function disconnectDevice(mac) {
        root.busyMAC = mac
        _btAction.command = ["bluetoothctl","disconnect",mac]
        _btAction.running = false; _btAction.running = true
    }
    function pairDevice(mac) {
        root.busyMAC = mac
        _btAction.command = ["bluetoothctl","pair",mac]
        _btAction.running = false; _btAction.running = true
    }
    function removeDevice(mac) {
        root.busyMAC = mac
        _btAction.command = ["bluetoothctl","remove",mac]
        _btAction.running = false; _btAction.running = true
    }

    // ── Inline components ───────────────────────────────────────────
    component TogglePill: Rectangle {
        id: tp
        width: 38; height: 18; radius: 9
        signal toggled()
        property bool active: false
        color: active ? Colors.color4 : Qt.lighter(Colors.background, 1.5)
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
            anchors.centerIn: parent
            text: tp.active ? "ON" : "OFF"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 9; font.bold: true
            color: tp.active ? Colors.background : Colors.color6
        }
        MouseArea { anchors.fill: parent; onClicked: tp.toggled() }
    }

    component SmallBtn: Rectangle {
        property string label: ""
        property bool accent: false
        signal clicked()
        width: btnLbl.implicitWidth + 16; height: 22; radius: 6
        color: accent
            ? (sbMa.containsMouse ? Qt.lighter(Colors.color4, 1.2) : Colors.color4)
            : (sbMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.3))
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            id: btnLbl; anchors.centerIn: parent; text: parent.label
            font.family: "Iosevka Nerd Font"; font.pixelSize: 9
            color: parent.accent ? Colors.background : Colors.foreground
        }
        MouseArea { id: sbMa; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }

    // ── Layout ──────────────────────────────────────────────────────
    Column {
        id: col
        width: parent.width; spacing: 8

        // Header
        Item {
            width: parent.width; height: 18
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: (root.btOn ? (root.btConn ? "\u{F00B1}" : "\u{F00AF}") : "\u{F00B2}") + "  Bluetooth"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                color: root.btConn ? Colors.color4 : (root.btOn ? Colors.foreground : Colors.color6)
            }
            TogglePill {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                active: root.btOn
                onToggled: {
                    const on = !root.btOn
                    root.btOn = on
                    _btToggle.command = on ? ["bluetoothctl","power","on"] : ["bluetoothctl","power","off"]
                    _btToggle.running = false; _btToggle.running = true
                    if (!on) { root.scanning = false; _scanOff.running = true }
                }
            }
        }

        // Connected device info
        Column {
            width: parent.width; spacing: 4
            visible: root.btConn

            Item {
                width: parent.width; height: 14
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "Connected"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.color2
                }
            }
            Item {
                width: parent.width; height: 14
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: root.btDevice
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.foreground
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: root.btMAC
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                    color: Colors.color8
                }
            }
        }

        // Divider
        Rectangle {
            width: parent.width; height: 1; color: Colors.color8; opacity: 0.3
            visible: root.btOn
        }

        // Paired devices
        Column {
            width: parent.width; spacing: 4
            visible: root.btOn && root.pairedDevs.length > 0

            Text {
                text: "PAIRED DEVICES (" + root.pairedDevs.length + ")"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: Colors.color6
            }

            Repeater {
                model: root.pairedDevs
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: 36; radius: 6
                    color: pdMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text {
                            text: "\u{F00AF}"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                            color: modelData.connected ? Colors.color4 : Colors.color6
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: modelData.name
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                color: modelData.connected ? Colors.color4 : Colors.foreground
                            }
                            Text {
                                text: modelData.mac
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                                color: Colors.color8
                            }
                        }
                    }
                    Row {
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        spacing: 4

                        Text {
                            visible: root.busyMAC === modelData.mac
                            text: "..."
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                            color: Colors.color3
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        SmallBtn {
                            visible: root.busyMAC !== modelData.mac
                            label: modelData.connected ? "Disconnect" : "Connect"
                            accent: !modelData.connected
                            onClicked: {
                                if (modelData.connected) root.disconnectDevice(modelData.mac)
                                else root.connectDevice(modelData.mac)
                            }
                        }
                        SmallBtn {
                            visible: !modelData.connected && root.busyMAC !== modelData.mac
                            label: "Remove"
                            onClicked: root.removeDevice(modelData.mac)
                        }
                    }

                    MouseArea { id: pdMa; anchors.fill: parent; hoverEnabled: true; z: -1 }
                }
            }
        }

        // Divider
        Rectangle {
            width: parent.width; height: 1; color: Colors.color8; opacity: 0.3
            visible: root.btOn
        }

        // Scan controls
        Item {
            width: parent.width; height: 28
            visible: root.btOn

            SmallBtn {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                label: root.scanning ? "\u{F0453}  Scanning..." : "\u{F0453}  Scan"
                accent: !root.scanning
                onClicked: {
                    if (root.scanning) {
                        root.scanning = false
                        _scanOff.running = false; _scanOff.running = true
                    } else {
                        root.scannedDevs = []
                        root.scanning = true
                        _scanOn.running = false; _scanOn.running = true
                    }
                }
            }

            SmallBtn {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                label: "Open Manager"
                onClicked: { _openBtMgr.running = false; _openBtMgr.running = true }
            }
        }

        // Scanned (new) devices
        Column {
            width: parent.width; spacing: 2
            visible: root.scanning && root.scannedDevs.length > 0

            Text {
                text: "AVAILABLE (" + root.scannedDevs.length + ")"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: Colors.color6
            }

            Repeater {
                model: root.scannedDevs
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: 34; radius: 6
                    color: sdMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text {
                            text: "\u{F00AF}"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                            color: Colors.color6
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: modelData.name
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                color: Colors.foreground
                            }
                            Text {
                                text: modelData.mac
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                                color: Colors.color8
                            }
                        }
                    }

                    Row {
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Text {
                            visible: root.busyMAC === modelData.mac
                            text: "Pairing..."
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                            color: Colors.color3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        SmallBtn {
                            visible: root.busyMAC !== modelData.mac
                            label: "Pair"
                            accent: true
                            onClicked: root.pairDevice(modelData.mac)
                        }
                    }

                    MouseArea { id: sdMa; anchors.fill: parent; hoverEnabled: true; z: -1 }
                }
            }
        }

        // Scanning indicator
        Text {
            visible: root.scanning && root.scannedDevs.length === 0
            text: "Searching for devices..."
            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
            color: Colors.color8
        }
    }
}
