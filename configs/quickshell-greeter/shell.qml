import QtQuick
import Quickshell
import Quickshell.Io

// Lean quickshell greeter: clock + password for user dhm + power, themed from the
// wallust palette mirrored to /var/lib/greeter/colors.json (Rose Pine fallback).
// Runs as the sole client under cage (xdg-toplevel -> auto-fullscreen), so it uses
// FloatingWindow rather than layer-shell, which cage does not implement.
ShellRoot {
    id: root

    // ── palette (mirror written by the greeter-palette-sync unit) ──
    property string _raw: ""
    readonly property var _d: { try { return JSON.parse(_raw) } catch (e) { return {} } }
    function _col(k, fb) { return (_d.colors && _d.colors[k]) ? _d.colors[k] : fb }
    readonly property color bg: (_d.special && _d.special.background) ? _d.special.background : "#191724"
    readonly property color fg: (_d.special && _d.special.foreground) ? _d.special.foreground : "#e0def4"
    readonly property color accent: _col("color4", "#31748f")
    readonly property color errColor: _col("color1", "#eb6f92")

    FileView {
        id: palette
        path: "/var/lib/greeter/colors.json"
        watchChanges: true
        onTextChanged: root._raw = palette.text()
    }
    Component.onCompleted: root._raw = palette.text()

    // ── greetd IPC via the python bridge ──
    property string status: ""
    property bool busy: false
    property string _phase: "idle"   // idle -> creating -> starting
    property string _pw: ""

    Process {
        id: bridge
        // GREETD_BRIDGE="python3 /etc/quickshell-greeter/qs-greetd-bridge.py [--mock]"
        command: (Quickshell.env("GREETD_BRIDGE") || "python3 /etc/quickshell-greeter/qs-greetd-bridge.py").split(" ")
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: line => root._onMsg(line) }
    }
    function _send(obj) { bridge.write(JSON.stringify(obj) + "\n") }

    function submit(pw) {
        if (busy || pw === "") return
        root.busy = true; root.status = ""; root._pw = pw; root._phase = "creating"
        root._send({ type: "create_session", username: "dhm" })
    }

    function _onMsg(line) {
        var m
        try { m = JSON.parse(line) } catch (e) { return }
        if (m.type === "auth_message") {
            root._send({ type: "post_auth_message_response",
                         response: m.auth_message_type === "secret" ? root._pw : "" })
        } else if (m.type === "success") {
            if (root._phase !== "starting") {
                root._phase = "starting"
                root._send({ type: "start_session", cmd: ["niri-session"] })
            }
            // else: session is launching, nothing more to do
        } else if (m.type === "error") {
            root._pw = ""; root.busy = false; root._phase = "idle"
            root.status = m.description || "Authentication failed"
            root._send({ type: "cancel_session" })   // greetd needs this before a retry
        }
    }

    function power(cmd) { powerProc.command = cmd; powerProc.running = false; powerProc.running = true }
    Process { id: powerProc }

    FloatingWindow {
        id: win
        color: root.bg   // cage fullscreens the sole toplevel

        Item {
            anchors.fill: parent

            Column {
                anchors.centerIn: parent
                spacing: 22

                Text {
                    id: clock
                    anchors.horizontalCenter: parent.horizontalCenter
                    property var now: new Date()
                    text: Qt.formatDateTime(now, "HH:mm")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 76; font.weight: Font.Light
                    color: root.fg
                    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.now, "dddd, d MMMM")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.7)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "  dhm"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 16
                    color: root.accent
                    topPadding: 10
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 320; height: 46; radius: 12
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.width: 2
                    border.color: pwInput.activeFocus
                        ? root.accent
                        : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4)
                    opacity: root.busy ? 0.6 : 1.0

                    TextInput {
                        id: pwInput
                        anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 16
                        color: root.fg
                        enabled: !root.busy
                        focus: true
                        onAccepted: { root.submit(text); text = "" }
                        Component.onCompleted: forceActiveFocus()
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                        visible: pwInput.text === "" && !pwInput.activeFocus
                        text: "Password"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 15
                        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.4)
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.status
                    visible: root.status !== ""
                    color: root.errColor
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                }
            }

            // power row (bottom-center)
            Row {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 44 }
                spacing: 20
                Repeater {
                    model: [
                        { ico: "", cmd: ["systemctl", "poweroff"] },
                        { ico: "", cmd: ["systemctl", "reboot"] }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 50; height: 50; radius: 25
                        color: pma.containsMouse
                            ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                            : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent; text: modelData.ico
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 20; color: root.fg
                        }
                        MouseArea {
                            id: pma; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.power(modelData.cmd)
                        }
                    }
                }
            }
        }
    }
}
