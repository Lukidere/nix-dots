import QtQuick
import Quickshell.Io
import "../../Theme"
import "../../Notifications"

Item {
    id: root
    height: col.implicitHeight

    property int    volume:     50
    property bool   muted:      false
    property bool   micMuted:   false
    property int    brightness: 50
    property string connType:   ""   // "wifi" | "ethernet" | ""
    property string wifiName:   ""
    property string wifiIP:     ""
    property bool   wifiOn:     true
    property bool   btOn:       false
    property bool   btConn:     false
    property string btDevice:   ""
    property bool   eyeHealth:  false

    // Poll-lock flags: ignore poll results for a few seconds after a manual toggle
    property bool _lockAudio: false
    property bool _lockNet:   false
    property bool _lockBt:    false
    Timer { id: _audioLock; interval: 3000; onTriggered: root._lockAudio = false }
    Timer { id: _netLock;   interval: 6000; onTriggered: root._lockNet   = false }
    Timer { id: _btLock;    interval: 6000; onTriggered: root._lockBt    = false }

    // ── Audio ─────────────────────────────────────────────────────────────
    readonly property Process _audioProc: Process {
        command: ["sh","-c","wpctl get-volume @DEFAULT_AUDIO_SINK@ && wpctl get-volume @DEFAULT_AUDIO_SOURCE@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._lockAudio) return
                const lines = this.text.trim().split("\n")
                if (lines[0]) {
                    const m = lines[0].match(/Volume: ([\d.]+)/)
                    if (m) root.volume = Math.round(parseFloat(m[1])*100)
                    root.muted = lines[0].includes("[MUTED]")
                }
                if (lines[1]) root.micMuted = lines[1].includes("[MUTED]")
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true
            onTriggered: { root._audioProc.running=false; root._audioProc.running=true } }

    // ── Brightness ────────────────────────────────────────────────────────
    readonly property Process _brightProc: Process {
        command: ["sh","-c","echo $(( $(brightnessctl get -d amdgpu_bl1) * 100 / $(brightnessctl max -d amdgpu_bl1) ))"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim())
                if (!isNaN(v)) root.brightness = v
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true
            onTriggered: { root._brightProc.running=false; root._brightProc.running=true } }

    // ── Network ───────────────────────────────────────────────────────────
    readonly property Process _netProc: Process {
        command: ["sh","-c",
            "nmcli -t -f TYPE,STATE,CONNECTION device; echo ---;" +
            "hostname -I 2>/dev/null | awk '{print $1}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._lockNet) return
                const parts = this.text.split("---\n")
                const lines = (parts[0] || "").trim().split("\n")
                let found = false
                for (const line of lines) {
                    const p = line.split(":")
                    if (p[1] === "connected") {
                        root.wifiName = p[2] || ""
                        root.connType = p[0] === "ethernet" ? "ethernet" : "wifi"
                        root.wifiOn   = true
                        found = true; break
                    }
                }
                if (!found) { root.wifiName = ""; root.connType = ""; root.wifiOn = false }
                root.wifiIP = (parts[1] || "").trim()
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true
            onTriggered: { root._netProc.running=false; root._netProc.running=true } }

    // ── Bluetooth ─────────────────────────────────────────────────────────
    readonly property Process _btProc: Process {
        command: ["sh","-c","bluetoothctl show; bluetoothctl devices Connected"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._lockBt) return
                root.btOn   = /Powered: yes/.test(this.text)
                root.btConn = /Connected: yes/.test(this.text)
                const m = this.text.match(/Device [0-9A-F:]+ (.+)/)
                root.btDevice = m ? m[1].trim() : ""
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true
            onTriggered: { root._btProc.running=false; root._btProc.running=true } }

    Process { id: _volSet;     running: false }
    Process { id: _muteToggle; command: ["wpctl","set-mute","@DEFAULT_AUDIO_SINK@","toggle"];   running: false }
    Process { id: _micToggle;  command: ["wpctl","set-mute","@DEFAULT_AUDIO_SOURCE@","toggle"]; running: false }
    Process { id: _brightSet;  running: false }
    Process { id: _wifiToggle; running: false }
    Process { id: _btToggle;   running: false }
    Process { id: _eyeOn;      command: ["sh", "-c", "gammastep &"]; running: false }
    Process { id: _eyeOff;     command: ["sh","-c", "pkill -f [g]ammastep"];     running: false }
    readonly property Process _eyeProc: Process {
        command: ["sh", "-c", "pgrep -f '[g]ammastep'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.eyeHealth = this.text.trim() !== ""
        }
    }
    Timer { interval: 5000; running: true; repeat: true
            onTriggered: { root._eyeProc.running=false; root._eyeProc.running=true } }

    // ── Horizontal slider ─────────────────────────────────────────────────
    component HSlider: Item {
        id: hs
        height: 20
        signal moved(int v)
        property int value: 0

        Rectangle {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 4; radius: 2
            color: Qt.lighter(Colors.background, 1.5)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, hs.value/100))
                height: 4; radius: 2; color: Colors.color4
                Behavior on width { NumberAnimation { duration: 80 } }
            }
        }
        Rectangle {
            x: Math.max(0, (hs.width - 12) * Math.max(0, Math.min(1, hs.value/100)))
            y: 4; width: 12; height: 12; radius: 6
            color: Colors.color4
        }
        MouseArea {
            anchors.fill: parent
            function calc(mx) { return Math.max(0, Math.min(100, Math.round(mx/width*100))) }
            onPressed:         hs.moved(calc(mouseX))
            onPositionChanged: if (pressed) hs.moved(calc(mouseX))
        }
    }

    // ── Toggle pill ───────────────────────────────────────────────────────
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

    // ── Layout ────────────────────────────────────────────────────────────
    Column {
        id: col
        width: parent.width
        spacing: 14

        // Volume
        Column {
            width: parent.width; spacing: 6
            Item {
                width: parent.width; height: 18
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: (root.muted ? "\u{F075F}" : root.volume>66 ? "\u{F057E}" : root.volume>33 ? "\u{F0580}" : "\u{F057F}") + "  Volume"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                    color: root.muted ? Colors.color1 : Colors.foreground
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.muted ? "MUTED" : root.volume + "%"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                        color: root.muted ? Colors.color1 : Colors.color6
                    }
                    Rectangle {
                        width: 28; height: 18; radius: 9
                        color: root.micMuted ? Qt.lighter(Colors.color1, 1.2) : Qt.lighter(Colors.background, 1.5)
                        Text {
                            anchors.centerIn: parent
                            text: root.micMuted ? "\u{F036D}" : "\u{F036C}"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                            color: root.micMuted ? Colors.background : Colors.color6
                        }
                        MouseArea { anchors.fill: parent
                            onClicked: {
                                root.micMuted = !root.micMuted
                                root._lockAudio = true; _audioLock.restart()
                                _micToggle.running = false; _micToggle.running = true
                            }
                        }
                    }
                    TogglePill {
                        active: !root.muted
                        onToggled: {
                            root.muted = !root.muted
                            root._lockAudio = true; _audioLock.restart()
                            _muteToggle.running = false; _muteToggle.running = true
                        }
                    }
                }
            }
            HSlider {
                width: parent.width; value: root.volume
                onMoved: function(v) {
                    root.volume = v
                    root._lockAudio = true; _audioLock.restart()
                    _volSet.command = ["wpctl","set-volume","@DEFAULT_AUDIO_SINK@",(v/100).toFixed(2)]
                    _volSet.running = false; _volSet.running = true
                }
            }
        }

        // Brightness
        Column {
            width: parent.width; spacing: 6
            Item {
                width: parent.width; height: 18
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: (root.brightness>66 ? "\u{F00DF}" : root.brightness>33 ? "\u{F00DE}" : "\u{F00DD}") + "  Brightness"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                    color: Colors.foreground
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: root.brightness + "%"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.color6
                }
            }
            HSlider {
                width: parent.width; value: root.brightness
                onMoved: function(v) {
                    root.brightness = v
                    _brightSet.command = ["brightnessctl","set","-d","amdgpu_bl1",v+"%"]
                    _brightSet.running = false; _brightSet.running = true
                }
            }
        }

        // Network
        Column {
            width: parent.width; spacing: 3
            Item {
                width: parent.width; height: 18
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: (root.connType === "ethernet" ? "\u{F0200}" : root.wifiOn ? "\u{F0928}" : "\u{F092D}") +
                          "  " + (root.wifiName !== "" ? root.wifiName : (root.wifiOn ? "Connected" : "Disconnected"))
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                    color: root.wifiName !== "" ? Colors.foreground : Colors.color6
                    elide: Text.ElideRight; width: parent.width - 48
                }
                TogglePill {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    active: root.wifiOn
                    onToggled: {
                        root.wifiOn = !root.wifiOn
                        root._lockNet = true; _netLock.restart()
                        _wifiToggle.command = root.wifiOn ? ["rfkill","unblock","wifi"] : ["rfkill","block","wifi"]
                        _wifiToggle.running = false; _wifiToggle.running = true
                    }
                }
            }
            Text {
                visible: root.wifiIP !== ""
                text: root.wifiIP
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: Colors.color6
            }
        }

        // Bluetooth
        Column {
            width: parent.width; spacing: 3
            Item {
                width: parent.width; height: 18
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: (root.btOn ? (root.btConn ? "\u{F00B1}" : "\u{F00AF}") : "\u{F00B2}") +
                          "  " + (root.btDevice !== "" ? root.btDevice : "Bluetooth")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                    color: root.btOn ? Colors.foreground : Colors.color6
                    elide: Text.ElideRight; width: parent.width - 48
                }
                TogglePill {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    active: root.btOn
                    onToggled: {
                        root.btOn = !root.btOn; root.btConn = false; root.btDevice = ""
                        root._lockBt = true; _btLock.restart()
                        _btToggle.command = root.btOn ? ["rfkill","unblock","bluetooth"] : ["rfkill","block","bluetooth"]
                        _btToggle.running = false; _btToggle.running = true
                    }
                }
            }
            Text {
                visible: root.btDevice !== ""
                text: "Connected"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: Colors.color6
            }
        }

        // Eye Health
        Column {
            width: parent.width; spacing: 3
            Item {
                width: parent.width; height: 18
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "\u{F0290}  Eye Health"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                    color: root.eyeHealth ? Colors.color3 : Colors.foreground
                }
                TogglePill {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    active: root.eyeHealth
                    onToggled: {
                        root.eyeHealth = !root.eyeHealth
                        if (root.eyeHealth) { _eyeOn.running = false; _eyeOn.running = true }
                        else { _eyeOff.running = false; _eyeOff.running = true }
                    }
                }
            }
            Text {
                visible: root.eyeHealth
                text: "Auto night light"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: Colors.color6
            }
        }

        // Do Not Disturb
        Item {
            width: parent.width; height: 18
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "\u{F1F6}  Do Not Disturb"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                color: NotifState.dnd ? Colors.color1 : Colors.foreground
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            TogglePill {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                active: NotifState.dnd
                onToggled: NotifState.dnd = !NotifState.dnd
            }
        }
    }
}
