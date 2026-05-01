import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    height: col.implicitHeight

    // Ethernet state
    property string ethDev:    ""
    property bool   ethOn:     false
    property string ethConn:   ""
    property string ethIP:     ""

    // WiFi state
    property string wifiDev:   ""
    property bool   wifiOn:    true
    property string wifiName:  ""
    property string wifiIP:    ""
    property int    wifiSignal: 0
    property var    networks:  []
    property string connectingSSID: ""

    // ── State polling ───────────────────────────────────────────────
    readonly property Process _netProc: Process {
        command: ["sh","-c",
            "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null; echo '---';" +
            "hostname -I 2>/dev/null | awk '{print $1}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("---\n")
                const lines = (parts[0] || "").trim().split("\n")

                // Reset
                let foundEth = false
                let foundWifi = false

                for (const line of lines) {
                    const p = line.split(":")
                    if (p.length < 4) continue
                    const dev = p[0], type = p[1], state = p[2], conn = p[3]

                    if (type === "ethernet") {
                        root.ethDev = dev
                        root.ethOn = state === "connected"
                        root.ethConn = root.ethOn ? conn : ""
                        foundEth = true
                    }
                    if (type === "wifi") {
                        root.wifiDev = dev
                        if (state === "unavailable") {
                            root.wifiOn = false
                            root.wifiName = ""
                        } else if (state === "connected") {
                            root.wifiOn = true
                            root.wifiName = conn
                        } else if (state === "disconnected") {
                            root.wifiOn = true
                            root.wifiName = ""
                        }
                        foundWifi = true
                    }
                }
                if (!foundEth) { root.ethDev = ""; root.ethOn = false; root.ethConn = "" }
                if (!foundWifi) { root.wifiDev = ""; root.wifiOn = false; root.wifiName = "" }

                const ip = (parts[1] || "").trim()
                if (root.ethOn) root.ethIP = ip
                else root.ethIP = ""
                if (root.wifiName !== "") root.wifiIP = ip
                else root.wifiIP = ""
            }
        }
    }

    // ── WiFi scan ───────────────────────────────────────────────────
    readonly property Process _scanProc: Process {
        command: ["nmcli","-t","-f","SSID,SIGNAL,SECURITY,IN-USE","device","wifi","list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set()
                const list = []
                this.text.trim().split("\n").forEach(function(line) {
                    if (!line) return
                    const p = line.split(":")
                    const ssid = p[0] || ""
                    if (!ssid || seen.has(ssid)) return
                    seen.add(ssid)
                    list.push({
                        ssid: ssid,
                        signal: parseInt(p[1]) || 0,
                        security: p[2] || "",
                        inUse: (p[3] || "").trim() === "*"
                    })
                })
                list.sort(function(a, b) { return b.signal - a.signal })
                root.networks = list
                if (root.wifiOn) root.wifiSignal = (list.find(function(n) { return n.inUse }) || {}).signal || 0
            }
        }
    }

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            root._netProc.running = false; root._netProc.running = true
            if (root.wifiOn) { root._scanProc.running = false; root._scanProc.running = true }
        }
    }

    // ── Actions ─────────────────────────────────────────────────────
    Process { id: _toggleProc; running: false
        onRunningChanged: if (!running) { _netProc.running = false; _netProc.running = true }
    }
    Process { id: _connectProc; running: false
        onRunningChanged: {
            if (!running) {
                root.connectingSSID = ""
                _netProc.running = false; _netProc.running = true
                _scanProc.running = false; _scanProc.running = true
            }
        }
    }
    Process { id: _disconnectProc; running: false
        onRunningChanged: if (!running) { _netProc.running = false; _netProc.running = true }
    }

    property string promptSSID: ""

    function connectToNetwork(ssid) {
        root.connectingSSID = ssid
        _connectProc.command = ["nmcli","connection","up",ssid]
        _connectProc.running = false; _connectProc.running = true
    }

    function connectWithPassword(ssid, pass) {
        root.connectingSSID = ssid
        _connectProc.command = ["nmcli","device","wifi","connect",ssid,"password",pass]
        _connectProc.running = false; _connectProc.running = true
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

    component InfoRow: Item {
        property string label: ""
        property string value: ""
        property color valueColor: Colors.foreground
        width: parent.width; height: 14
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: parent.label
            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
            color: Colors.color6
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: parent.value
            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
            color: parent.valueColor
        }
    }

    // ── Layout ──────────────────────────────────────────────────────
    Column {
        id: col
        width: parent.width; spacing: 8

        // ── Ethernet section ────────────────────────────────────────
        Column {
            width: parent.width; spacing: 6
            visible: root.ethDev !== ""

            Item {
                width: parent.width; height: 18
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "\u{F0200}  Ethernet"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                    color: root.ethOn ? Colors.foreground : Colors.color6
                }
                TogglePill {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    active: root.ethOn
                    onToggled: {
                        if (root.ethOn) {
                            _toggleProc.command = ["nmcli","device","disconnect",root.ethDev]
                        } else {
                            _toggleProc.command = ["nmcli","device","connect",root.ethDev]
                        }
                        _toggleProc.running = false; _toggleProc.running = true
                    }
                }
            }

            InfoRow {
                label: "Status"
                value: root.ethOn ? "Connected" : "Disconnected"
                valueColor: root.ethOn ? Colors.color2 : Colors.color1
            }
            InfoRow { label: "Device"; value: root.ethDev }
            InfoRow { label: "Connection"; value: root.ethConn || "\u2014"; visible: root.ethOn }
            InfoRow { label: "IP"; value: root.ethIP || "\u2014"; visible: root.ethOn }
        }

        // Divider between ethernet and wifi
        Rectangle {
            width: parent.width; height: 1; color: Colors.color8; opacity: 0.3
            visible: root.ethDev !== "" && root.wifiDev !== ""
        }

        // ── WiFi section ────────────────────────────────────────────
        Column {
            width: parent.width; spacing: 6
            visible: root.wifiDev !== ""

            Item {
                width: parent.width; height: 18
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: (root.wifiOn ? "\u{F0928}" : "\u{F092D}") + "  WiFi"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                    color: root.wifiName !== "" ? Colors.foreground : Colors.color6
                }
                TogglePill {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    active: root.wifiOn
                    onToggled: {
                        const on = !root.wifiOn
                        root.wifiOn = on
                        _toggleProc.command = on ? ["nmcli","radio","wifi","on"] : ["nmcli","radio","wifi","off"]
                        _toggleProc.running = false; _toggleProc.running = true
                    }
                }
            }

            InfoRow {
                label: "Status"
                value: root.wifiName !== "" ? "Connected" : (root.wifiOn ? "Disconnected" : "WiFi Off")
                valueColor: root.wifiName !== "" ? Colors.color2 : Colors.color1
            }
            InfoRow { label: "Network"; value: root.wifiName || "\u2014"; visible: root.wifiName !== "" }
            InfoRow { label: "IP"; value: root.wifiIP || "\u2014"; visible: root.wifiName !== "" }

            // Signal bar
            Item {
                width: parent.width; height: 14
                visible: root.wifiName !== ""
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "Signal"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.color6
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Text {
                        text: root.wifiSignal + "%"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                        color: Colors.foreground
                    }
                    Rectangle {
                        width: 60; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter
                        color: Qt.lighter(Colors.background, 1.4)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.wifiSignal/100))
                            height: 4; radius: 2
                            color: root.wifiSignal > 60 ? Colors.color2 : root.wifiSignal > 30 ? Colors.color3 : Colors.color1
                            Behavior on width { NumberAnimation { duration: 400 } }
                        }
                    }
                }
            }

            // Disconnect button
            Rectangle {
                width: parent.width; height: 26; radius: 6
                visible: root.wifiName !== ""
                color: dcMa.containsMouse ? Qt.lighter(Colors.color1, 1.3) : Colors.color1
                opacity: 0.8
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent; text: "Disconnect"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.background
                }
                MouseArea {
                    id: dcMa; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        _disconnectProc.command = ["nmcli","connection","down",root.wifiName]
                        _disconnectProc.running = false; _disconnectProc.running = true
                    }
                }
            }
        }

        // Divider before network list
        Rectangle {
            width: parent.width; height: 1; color: Colors.color8; opacity: 0.3
            visible: root.wifiOn && root.wifiDev !== ""
        }

        // Available networks header
        Text {
            visible: root.wifiOn && root.wifiDev !== ""
            text: "AVAILABLE NETWORKS (" + root.networks.length + ")"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
            color: Colors.color6
        }

        // Password prompt
        Column {
            width: parent.width; spacing: 6
            visible: root.promptSSID !== ""

            Text {
                text: "Password for " + root.promptSSID
                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                color: Colors.foreground
            }
            Rectangle {
                width: parent.width; height: 30; radius: 6
                color: Qt.lighter(Colors.background, 1.3)
                border.color: passInput.activeFocus ? Colors.color4 : "transparent"
                border.width: 1
                TextInput {
                    id: passInput
                    anchors { fill: parent; margins: 8 }
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.foreground
                    echoMode: TextInput.Password
                    onAccepted: {
                        if (text.length > 0) {
                            root.connectWithPassword(root.promptSSID, text)
                            root.promptSSID = ""
                            text = ""
                        }
                    }
                }
            }
            Row {
                spacing: 6
                Rectangle {
                    width: 60; height: 24; radius: 6
                    color: connMa2.containsMouse ? Qt.lighter(Colors.color4, 1.2) : Colors.color4
                    Text { anchors.centerIn: parent; text: "Connect"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.background }
                    MouseArea {
                        id: connMa2; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (passInput.text.length > 0) {
                                root.connectWithPassword(root.promptSSID, passInput.text)
                                root.promptSSID = ""
                                passInput.text = ""
                            }
                        }
                    }
                }
                Rectangle {
                    width: 60; height: 24; radius: 6
                    color: canMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.3)
                    Text { anchors.centerIn: parent; text: "Cancel"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.foreground }
                    MouseArea {
                        id: canMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: { root.promptSSID = ""; passInput.text = "" }
                    }
                }
            }
        }

        // Network list
        Column {
            width: parent.width; spacing: 2
            visible: root.wifiOn && root.promptSSID === "" && root.wifiDev !== ""

            Repeater {
                model: root.networks
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width; height: 34; radius: 6
                    color: netItemMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text {
                            text: modelData.signal > 70 ? "\u{F0928}" : modelData.signal > 40 ? "\u{F0925}" : "\u{F0922}"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                            color: modelData.inUse ? Colors.color4 : Colors.color6
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: modelData.ssid
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                color: modelData.inUse ? Colors.color4 : Colors.foreground
                            }
                            Text {
                                text: (modelData.security ? "\u{F0341} " + modelData.security : "Open") + "  \u00B7  " + modelData.signal + "%"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                                color: Colors.color8
                            }
                        }
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: modelData.inUse ? "Connected" : (root.connectingSSID === modelData.ssid ? "Connecting..." : "")
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                        color: modelData.inUse ? Colors.color2 : Colors.color3
                    }
                    MouseArea {
                        id: netItemMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (modelData.inUse) return
                            if (modelData.security) {
                                root.connectingSSID = modelData.ssid
                                _connectProc.command = ["nmcli","connection","up",modelData.ssid]
                                _connectProc.running = false; _connectProc.running = true
                                _promptTimer.ssid = modelData.ssid
                                _promptTimer.running = true
                            } else {
                                root.connectToNetwork(modelData.ssid)
                            }
                        }
                    }
                }
            }
        }
    }

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
}
