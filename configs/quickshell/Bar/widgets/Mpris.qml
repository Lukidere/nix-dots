import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44
    property bool active: false
    property bool isPlaying: false
    property bool expanded: hoverArea.containsMouse
    property string trackInfo: ""

    // Collapsed: only play/pause visible (44px).
    // Expanded: track info + prev above, next below (152px).
    height: active ? (expanded ? 152 : 44) : 0
    visible: active
    clip: true
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }

    // Hover tracker — acceptedButtons:NoButton so it never steals clicks
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // ── Track info ────────────────────────────────────────────────────
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
        text: root.trackInfo
        width: 40; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
        font.family: "Iosevka Nerd Font"; font.pixelSize: 9
        color: Colors.color6
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // ── Prev button (full-width hit area) ─────────────────────────────
    Item {
        width: 44; height: 36
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 22 }
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Text {
            anchors.centerIn: parent; text: "\uF048"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 14
            color: prevMa.containsMouse ? Qt.lighter(Colors.foreground, 1.5) : Colors.foreground
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: prevMa; anchors.fill: parent; hoverEnabled: true
            onClicked: { prevProc.running = false; prevProc.running = true }
        }
    }

    // ── Play/Pause (slides down when expanded) ────────────────────────
    Item {
        width: 44; height: 44
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
        anchors.topMargin: root.expanded ? 62 : 0
        Behavior on anchors.topMargin { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }
        Text {
            anchors.centerIn: parent
            text: root.isPlaying ? "\uF04C" : "\uF04B"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 18
            color: ppMa.containsMouse ? Qt.lighter(Colors.color4, 1.4) : Colors.color4
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: ppMa; anchors.fill: parent; hoverEnabled: true
            onClicked: { ppProc.running = false; ppProc.running = true }
        }
    }

    // ── Next button (full-width hit area) ─────────────────────────────
    Item {
        width: 44; height: 36
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 110 }
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Text {
            anchors.centerIn: parent; text: "\uF051"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 14
            color: nextMa.containsMouse ? Qt.lighter(Colors.foreground, 1.5) : Colors.foreground
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: nextMa; anchors.fill: parent; hoverEnabled: true
            onClicked: { nextProc.running = false; nextProc.running = true }
        }
    }

    // ── Polling ───────────────────────────────────────────────────────
    Component.onCompleted: { statusProc.running = false; statusProc.running = true }

    readonly property Timer _statusPoll: Timer {
        interval: 500; running: true; repeat: true
        onTriggered: { statusProc.running = false; statusProc.running = true }
    }
    readonly property Timer _trackPoll: Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: { if (root.active) { trackProc.running = false; trackProc.running = true } }
    }

    Process {
        id: statusProc; running: false
        command: ["playerctl", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim()
                root.active    = (s === "Playing" || s === "Paused")
                root.isPlaying = (s === "Playing")
            }
        }
    }
    Process {
        id: trackProc; running: false
        command: ["sh", "-c", "playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim()
                if (s && s !== " - " && s !== "-") root.trackInfo = s
            }
        }
    }

    Process { id: prevProc; command: ["playerctl", "previous"];   running: false }
    Process { id: ppProc;   command: ["playerctl", "play-pause"]; running: false }
    Process { id: nextProc; command: ["playerctl", "next"];       running: false }
}
