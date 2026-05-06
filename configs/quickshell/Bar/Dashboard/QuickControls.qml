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
    property bool   wifiOn:     false
    property bool   btOn:       false
    property bool   btConn:     false
    property string btDevice:   ""
    property bool   eyeHealth:  false

    // Poll-lock flags: ignore poll results for a few seconds after a manual toggle
    property bool _lockAudio: false
    property bool _lockNet:   false
    property bool _lockBt:    false
    property bool _lockEye:   false
    Timer { id: _audioLock; interval: 3000; onTriggered: root._lockAudio = false }
    Timer { id: _netLock;   interval: 6000; onTriggered: root._lockNet   = false }
    Timer { id: _btLock;    interval: 6000; onTriggered: root._lockBt    = false }
    Timer { id: _eyeLock;   interval: 4000; onTriggered: root._lockEye   = false }

    Component.onCompleted: {
        // trigger immediate network poll on startup
        _netProc.running = false
        _netProc.running = true
    }

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

    // ── Public helpers (called by DashboardWindow vol panel) ──────────────
    function setVolume(v) {
        root.volume = v
        root._lockAudio = true; _audioLock.restart()
        _volSet.command = ["wpctl","set-volume","@DEFAULT_AUDIO_SINK@",(v/100).toFixed(2)]
        _volSet.running = false; _volSet.running = true
    }
    function toggleMute() {
        root.muted = !root.muted
        root._lockAudio = true; _audioLock.restart()
        _muteToggle.running = false; _muteToggle.running = true
    }
    function toggleMicMute() {
        root.micMuted = !root.micMuted
        root._lockAudio = true; _audioLock.restart()
        _micToggle.running = false; _micToggle.running = true
    }
    function setBrightness(v) {
        root.brightness = v
        _brightSet.command = ["brightnessctl","set","-d","amdgpu_bl1",v+"%"]
        _brightSet.running = false; _brightSet.running = true
    }
    Process { id: _btToggle;   running: false }
    Process { id: _eyeOn;      command: ["sh", "-c", "gammastep &"]; running: false }
    Process { id: _eyeOff;     command: ["sh","-c", "pkill -f [g]ammastep"]; running: false }
    readonly property Process _eyeProc: Process {
        command: ["sh", "-c", "pgrep -f '[g]ammastep'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { if (!root._lockEye) root.eyeHealth = this.text.trim() !== "" }
        }
    }
    Timer { interval: 5000; running: true; repeat: true
            onTriggered: { root._eyeProc.running=false; root._eyeProc.running=true } }

    // ── Layout ────────────────────────────────────────────────────────────
    Column {
        id: col
        width: parent.width
        spacing: 10

        // Toggle card grid: Network · Bluetooth · Eye Health · DND
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 8; rowSpacing: 8

            // ── Network card (WiFi or Ethernet) ───────────────────
            Rectangle {
                id: netCard
                readonly property bool _connected: root.connType !== ""
                readonly property bool _isEther:   root.connType === "ethernet"
                readonly property color _accent:   _isEther ? Colors.color5 : Colors.color4

                width: (parent.width - 8) / 2; height: 68; radius: 10
                color: _connected
                    ? Qt.rgba(_accent.r, _accent.g, _accent.b, 0.13)
                    : Qt.lighter(Colors.background, 1.25)
                Behavior on color { ColorAnimation { duration: 150 } }
                border.color: _connected
                    ? Qt.rgba(_accent.r, _accent.g, _accent.b, 0.4)
                    : "transparent"
                border.width: 1
                Column {
                    anchors { left: parent.left; top: parent.top; margins: 10 }
                    spacing: 3
                    Text {
                        text: netCard._isEther ? "\u{F0200}"
                            : root.wifiOn ? "\u{F0928}" : "\u{F092D}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                        color: netCard._connected ? netCard._accent : Colors.color8
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: netCard._isEther ? "Ethernet"
                            : root.wifiName !== "" ? root.wifiName
                            : root.wifiOn ? "Wi-Fi on" : "Wi-Fi off"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                        color: Colors.color6; elide: Text.ElideRight; width: 80
                    }
                }
                Rectangle {
                    anchors { right: parent.right; top: parent.top; margins: 8 }
                    width: 7; height: 7; radius: 4
                    color: netCard._connected ? Colors.color2 : Qt.lighter(Colors.background, 1.6)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                // Ethernet cannot be toggled via nmcli radio wifi
                MouseArea {
                    anchors.fill: parent
                    enabled: !netCard._isEther
                    cursorShape: netCard._isEther ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        root.wifiOn = !root.wifiOn
                        root._lockNet = true; _netLock.restart()
                        _wifiToggle.command = ["nmcli","radio","wifi", root.wifiOn ? "on" : "off"]
                        _wifiToggle.running = false; _wifiToggle.running = true
                    }
                }
            }

            // ── Bluetooth card ────────────────────────────────────
            Rectangle {
                width: (parent.width - 8) / 2; height: 68; radius: 10
                color: root.btOn
                    ? Qt.rgba(Colors.color5.r, Colors.color5.g, Colors.color5.b, 0.13)
                    : Qt.lighter(Colors.background, 1.25)
                Behavior on color { ColorAnimation { duration: 150 } }
                border.color: root.btOn
                    ? Qt.rgba(Colors.color5.r, Colors.color5.g, Colors.color5.b, 0.4)
                    : "transparent"
                border.width: 1
                Column {
                    anchors { left: parent.left; top: parent.top; margins: 10 }
                    spacing: 3
                    Text {
                        text: root.btOn ? (root.btConn ? "\u{F00B1}" : "\u{F00AF}") : "\u{F00B2}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                        color: root.btOn ? Colors.color5 : Colors.color8
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: root.btDevice !== "" ? root.btDevice : "Bluetooth"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                        color: Colors.color6; elide: Text.ElideRight; width: 80
                    }
                }
                Rectangle {
                    anchors { right: parent.right; top: parent.top; margins: 8 }
                    width: 7; height: 7; radius: 4
                    color: root.btOn ? Colors.color2 : Qt.lighter(Colors.background, 1.6)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.btOn = !root.btOn; root.btConn = false; root.btDevice = ""
                        root._lockBt = true; _btLock.restart()
                        _btToggle.command = root.btOn
                            ? ["rfkill","unblock","bluetooth"]
                            : ["rfkill","block","bluetooth"]
                        _btToggle.running = false; _btToggle.running = true
                    }
                }
            }

            // ── Eye Health card ───────────────────────────────────
            Rectangle {
                width: (parent.width - 8) / 2; height: 68; radius: 10
                color: root.eyeHealth
                    ? Qt.rgba(Colors.color3.r, Colors.color3.g, Colors.color3.b, 0.13)
                    : Qt.lighter(Colors.background, 1.25)
                Behavior on color { ColorAnimation { duration: 150 } }
                border.color: root.eyeHealth
                    ? Qt.rgba(Colors.color3.r, Colors.color3.g, Colors.color3.b, 0.4)
                    : "transparent"
                border.width: 1
                Column {
                    anchors { left: parent.left; top: parent.top; margins: 10 }
                    spacing: 3
                    Text {
                        text: "\u{F0290}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                        color: root.eyeHealth ? Colors.color3 : Colors.color8
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: root.eyeHealth ? "Night light" : "Eye Health"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                        color: Colors.color6
                    }
                }
                Rectangle {
                    anchors { right: parent.right; top: parent.top; margins: 8 }
                    width: 7; height: 7; radius: 4
                    color: root.eyeHealth ? Colors.color2 : Qt.lighter(Colors.background, 1.6)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.eyeHealth = !root.eyeHealth
                        root._lockEye = true; _eyeLock.restart()
                        if (root.eyeHealth) { _eyeOn.running = false; _eyeOn.running = true }
                        else { _eyeOff.running = false; _eyeOff.running = true }
                    }
                }
            }

            // ── Do Not Disturb card ───────────────────────────────
            Rectangle {
                width: (parent.width - 8) / 2; height: 68; radius: 10
                color: NotifState.dnd
                    ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.13)
                    : Qt.lighter(Colors.background, 1.25)
                Behavior on color { ColorAnimation { duration: 150 } }
                border.color: NotifState.dnd
                    ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.4)
                    : "transparent"
                border.width: 1
                Column {
                    anchors { left: parent.left; top: parent.top; margins: 10 }
                    spacing: 3
                    Text {
                        text: "\u{F1F6}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                        color: NotifState.dnd ? Colors.color1 : Colors.color8
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: "Do Not Disturb"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                        color: Colors.color6
                    }
                }
                Rectangle {
                    anchors { right: parent.right; top: parent.top; margins: 8 }
                    width: 7; height: 7; radius: 4
                    color: NotifState.dnd ? Colors.color1 : Qt.lighter(Colors.background, 1.6)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: NotifState.dnd = !NotifState.dnd
                }
            }
        }

        // ── Compact Calendar (expandable) ─────────────────────────────────
        Item {
            id: calSection
            width: parent.width
            height: calHeader.height + calBody.height
            property bool _expanded: false

            Rectangle {
                id: calHeader
                width: parent.width; height: 34; radius: 8
                color: calSection._expanded
                    ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.1)
                    : Qt.lighter(Colors.background, 1.18)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                    text: "\uF073  " + Qt.formatDate(new Date(), "dddd, d MMMM yyyy")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.foreground
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
                    text: calSection._expanded ? "\uF0D8" : "\uF0D7"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                    color: Colors.color8
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: calSection._expanded = !calSection._expanded
                }
            }

            Item {
                id: calBody
                anchors { top: calHeader.bottom; left: parent.left; right: parent.right }
                height: calSection._expanded ? calInner.height + 8 : 0
                clip: true
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                CalendarWidget {
                    id: calInner
                    width: parent.width
                    anchors.top: parent.top
                    anchors.topMargin: 6
                }
            }
        }

        // ── Compact Weather (expandable) ──────────────────────────────────
        Item {
            id: wxSection
            width: parent.width
            height: wxHeader.height + wxBody.height
            property bool _expanded: false

            // Hidden WeatherWidget drives all the data / processes
            WeatherWidget {
                id: wxData
                width: 1; height: 1
                visible: false
            }

            Rectangle {
                id: wxHeader
                width: parent.width; height: 34; radius: 8
                color: wxSection._expanded
                    ? Qt.rgba(Colors.color3.r, Colors.color3.g, Colors.color3.b, 0.1)
                    : Qt.lighter(Colors.background, 1.18)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                    text: wxData.wIcon + "  " + wxData.temp + "  " + wxData.desc
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.foreground
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
                    text: wxSection._expanded ? "\uF0D8" : "\uF0D7"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                    color: Colors.color8
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: wxSection._expanded = !wxSection._expanded
                }
            }

            Item {
                id: wxBody
                anchors { top: wxHeader.bottom; left: parent.left; right: parent.right }
                height: wxSection._expanded ? wxForecast.implicitHeight + 8 : 0
                clip: true
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Column {
                    id: wxForecast
                    width: parent.width
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    spacing: 4

                    Repeater {
                        model: wxData.forecast
                        delegate: Item {
                            required property var modelData
                            width: wxForecast.width; height: 22
                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: modelData.day
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                                color: Colors.color8; width: 32
                            }
                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 36 }
                                text: modelData.icon
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                                color: Colors.foreground
                            }
                            Text {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: modelData.high + "\u00B0 / " + modelData.low + "\u00B0"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                                color: Colors.color6
                            }
                        }
                    }
                }
            }
        }
    }
}
