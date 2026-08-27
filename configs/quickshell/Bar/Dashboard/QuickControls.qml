import QtQuick
import Quickshell.Io
import "../../Theme"
import "../../Notifications"

Item {
    id: root
    height: col.implicitHeight

    property int  volume:     50
    property bool muted:      false
    property bool micMuted:   false
    property int  brightness: 50
    property bool eyeHealth:  false

    // which monitor this instance controls; eDP-2 is the laptop panel
    // (brightnessctl), everything else is the external MSI over DDC/CI (ddcutil)
    property string screenName: ""
    // laptop panel connector is eDP-* (here eDP-1); anything else is external
    readonly property bool _isInternal: screenName.indexOf("eDP") === 0
    onScreenNameChanged: {
        if (_isInternal) { _brightProc.running = false; _brightProc.running = true }
        else             { _ddcGet.running = false;     _ddcGet.running = true }
    }

    // expose weather data so the dashboard hero can reuse it
    property alias weatherIcon: wxData.wIcon
    property alias weatherTemp: wxData.temp
    property alias weatherDesc: wxData.desc

    // Poll-lock flags: ignore poll results for a few seconds after a manual toggle
    property bool _lockAudio: false
    property bool _lockEye:   false
    Timer { id: _audioLock; interval: 3000; onTriggered: root._lockAudio = false }
    Timer { id: _eyeLock;   interval: 4000; onTriggered: root._lockEye   = false }

    readonly property Process _audioProc: Process {
        command: ["sh","-c","wpctl get-volume @DEFAULT_AUDIO_SINK@ && sh \"$HOME/.config/quickshell/scripts/qs-micmute.sh\" status"]
        running: false
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
    // only poll while this screen's volume panel is open - the audio read spawns
    // wpctl + a pw-dump (mic mute), so running it 24/7 per screen is wasteful
    readonly property bool _panelOpen: DashboardState.volPanelScreen === root.screenName
    Timer { interval: 2000; running: root._panelOpen; triggeredOnStart: true; repeat: true
            onTriggered: { root._audioProc.running=false; root._audioProc.running=true } }

    readonly property Process _brightProc: Process {
        command: ["sh","-c","echo $(( $(brightnessctl get -d amdgpu_bl1) * 100 / $(brightnessctl max -d amdgpu_bl1) ))"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim())
                if (!isNaN(v)) root.brightness = v
            }
        }
    }
    // only the laptop panel polls brightnessctl, and only while the panel is open
    Timer { interval: 3000; running: root._isInternal && root._panelOpen; triggeredOnStart: true; repeat: true
            onTriggered: { root._brightProc.running=false; root._brightProc.running=true } }

    Process { id: _volSet;     running: false }
    Process { id: _muteToggle; command: ["wpctl","set-mute","@DEFAULT_AUDIO_SINK@","toggle"];   running: false }
    Process { id: _micToggle;  command: ["sh","-c","sh \"$HOME/.config/quickshell/scripts/qs-micmute.sh\" toggle"]; running: false }
    Process { id: _brightSet;  running: false }

    // external monitor (MSI MAG271R) brightness over DDC/CI - debounced because
    // ddcutil is slow (~200ms/call) and slider drags fire setBrightness rapidly
    property int _ddcPending: -1
    Process { id: _ddcSet; running: false }
    Timer {
        id: _ddcTimer; interval: 250
        onTriggered: {
            if (root._ddcPending < 0) return
            _ddcSet.command = ["ddcutil", "--model", "MSI MAG271R", "--noverify",
                               "setvcp", "10", String(root._ddcPending)]
            _ddcSet.running = false; _ddcSet.running = true
        }
    }
    // read the external monitor's current brightness (once, on this screen)
    Process {
        id: _ddcGet
        command: ["ddcutil", "--model", "MSI MAG271R", "--brief", "getvcp", "10"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // brief format: "VCP 10 C <current> <max>"
                const p = this.text.trim().split(/\s+/)
                const cur = parseInt(p[3]); const max = parseInt(p[4])
                if (!isNaN(cur) && max > 0) root.brightness = Math.round(cur / max * 100)
            }
        }
    }

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
        if (root._isInternal) {
            _brightSet.command = ["brightnessctl","set","-d","amdgpu_bl1",v+"%"]
            _brightSet.running = false; _brightSet.running = true
        } else {
            // external MSI monitor, throttled via _ddcTimer (ddcutil is slow)
            root._ddcPending = v
            _ddcTimer.restart()
        }
    }
    Process { id: _eyeOn;      command: ["sh", "-c", "gammastep &"]; running: false }
    Process { id: _eyeOff;     command: ["sh","-c", "pkill -f [g]ammastep"]; running: false }

    // auto night mode - on 18:00–06:00, off otherwise. Respects manual override (_lockEye).
    function _autoNight() {
        if (root._lockEye) return
        const h = new Date().getHours()
        const shouldBeOn = (h >= 18 || h < 6)
        if (shouldBeOn && !root.eyeHealth) {
            root.eyeHealth = true
            _eyeOn.running = false; _eyeOn.running = true
        } else if (!shouldBeOn && root.eyeHealth) {
            root.eyeHealth = false
            _eyeOff.running = false; _eyeOff.running = true
        }
    }
    Component.onCompleted: _autoNight()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root._autoNight() }
    readonly property Process _eyeProc: Process {
        command: ["sh", "-c", "pgrep -f '[g]ammastep'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { if (!root._lockEye) root.eyeHealth = this.text.trim() !== "" }
        }
    }
    Timer { interval: 5000; running: true; repeat: true
            onTriggered: { root._eyeProc.running=false; root._eyeProc.running=true } }

    Row {
        id: col
        width: parent.width
        spacing: 12

        // ── Left column: toggles + calendar (always open) ───────────
        Column {
            width: Math.round((parent.width - 12) * 0.54)
            spacing: 10

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 8; rowSpacing: 8

            Rectangle {
                id: netCard
                readonly property bool _connected: NetworkState.connType !== ""
                readonly property bool _isEther:   NetworkState.connType === "ethernet"
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
                Rectangle {
                    anchors { fill: parent; margins: -3 }
                    radius: parent.radius + 3; z: -1; color: "transparent"
                    border.width: 3
                    border.color: Qt.rgba(netCard._accent.r, netCard._accent.g, netCard._accent.b, netCard._connected ? 0.18 : 0)
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                }
                Column {
                    anchors { left: parent.left; top: parent.top; margins: 10 }
                    spacing: 3
                    Text {
                        text: netCard._isEther ? "\u{F0200}"
                            : NetworkState.wifiOn ? "\u{F0928}" : "\u{F092D}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                        color: netCard._connected ? netCard._accent : Colors.color8
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: netCard._isEther ? "Ethernet"
                            : NetworkState.wifiName !== "" ? NetworkState.wifiName
                            : NetworkState.wifiOn ? "Wi-Fi on" : "Wi-Fi off"
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
                    onClicked: NetworkState.toggleWifi()
                }
            }

            Rectangle {
                id: btCard
                width: (parent.width - 8) / 2; height: 68; radius: 10
                color: NetworkState.btOn
                    ? Qt.rgba(Colors.color5.r, Colors.color5.g, Colors.color5.b, 0.13)
                    : Qt.lighter(Colors.background, 1.25)
                Behavior on color { ColorAnimation { duration: 150 } }
                border.color: NetworkState.btOn
                    ? Qt.rgba(Colors.color5.r, Colors.color5.g, Colors.color5.b, 0.4)
                    : "transparent"
                border.width: 1
                Rectangle {
                    anchors { fill: parent; margins: -3 }
                    radius: parent.radius + 3; z: -1; color: "transparent"
                    border.width: 3
                    border.color: Qt.rgba(Colors.color5.r, Colors.color5.g, Colors.color5.b, NetworkState.btOn ? 0.18 : 0)
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                }
                Column {
                    anchors { left: parent.left; top: parent.top; margins: 10 }
                    spacing: 3
                    Text {
                        text: NetworkState.btOn ? (NetworkState.btConn ? "\u{F00B1}" : "\u{F00AF}") : "\u{F00B2}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                        color: NetworkState.btOn ? Colors.color5 : Colors.color8
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: NetworkState.btDevice !== "" ? NetworkState.btDevice : "Bluetooth"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                        color: Colors.color6; elide: Text.ElideRight; width: 80
                    }
                }
                Rectangle {
                    anchors { right: parent.right; top: parent.top; margins: 8 }
                    width: 7; height: 7; radius: 4
                    color: NetworkState.btOn ? Colors.color2 : Qt.lighter(Colors.background, 1.6)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: NetworkState.toggleBluetooth()
                }
            }

            Rectangle {
                id: eyeCard
                width: (parent.width - 8) / 2; height: 68; radius: 10
                color: root.eyeHealth
                    ? Qt.rgba(Colors.color3.r, Colors.color3.g, Colors.color3.b, 0.13)
                    : Qt.lighter(Colors.background, 1.25)
                Behavior on color { ColorAnimation { duration: 150 } }
                border.color: root.eyeHealth
                    ? Qt.rgba(Colors.color3.r, Colors.color3.g, Colors.color3.b, 0.4)
                    : "transparent"
                border.width: 1
                Rectangle {
                    anchors { fill: parent; margins: -3 }
                    radius: parent.radius + 3; z: -1; color: "transparent"
                    border.width: 3
                    border.color: Qt.rgba(Colors.color3.r, Colors.color3.g, Colors.color3.b, root.eyeHealth ? 0.18 : 0)
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                }
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

            Rectangle {
                id: dndCard
                width: (parent.width - 8) / 2; height: 68; radius: 10
                color: NotifState.dnd
                    ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.13)
                    : Qt.lighter(Colors.background, 1.25)
                Behavior on color { ColorAnimation { duration: 150 } }
                border.color: NotifState.dnd
                    ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.4)
                    : "transparent"
                border.width: 1
                Rectangle {
                    anchors { fill: parent; margins: -3 }
                    radius: parent.radius + 3; z: -1; color: "transparent"
                    border.width: 3
                    border.color: Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, NotifState.dnd ? 0.18 : 0)
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                }
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

            CalendarWidget {
                width: parent.width
            }
        }

        // ── Right column: weather, always expanded, compact ─────────
        Column {
            width: parent.width - Math.round((parent.width - 12) * 0.54) - 12
            spacing: 8

            // Hidden data driver
            WeatherWidget {
                id: wxData
                width: 1; height: 1
                visible: false
                active: DashboardState.activeScreenName !== ""
            }

            Rectangle {
                width: parent.width
                height: wxCol.implicitHeight + 20
                radius: 10
                color: Qt.rgba(Colors.color3.r, Colors.color3.g, Colors.color3.b, 0.08)
                border.color: Qt.rgba(Colors.color3.r, Colors.color3.g, Colors.color3.b, 0.25)
                border.width: 1

                Column {
                    id: wxCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    spacing: 6

                    Row {
                        spacing: 8
                        Text {
                            text: wxData.wIcon
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 26
                            color: Colors.color3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            spacing: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: wxData.temp
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 16; font.bold: true
                                color: Colors.foreground
                            }
                            Text {
                                text: wxData.desc
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                                color: Colors.color6
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(Colors.color3.r, Colors.color3.g, Colors.color3.b, 0.2) }

                    Repeater {
                        model: wxData.forecast
                        delegate: Item {
                            required property var modelData
                            width: wxCol.width; height: 20
                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: modelData.day
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                                color: Colors.color8
                            }
                            Text {
                                anchors { left: parent.left; leftMargin: 30; verticalCenter: parent.verticalCenter }
                                text: modelData.icon
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                                color: Colors.foreground
                            }
                            Text {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: modelData.high + "\u00B0/" + modelData.low + "\u00B0"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                                color: Colors.color6
                            }
                        }
                    }
                }
            }
        }
    }
}
