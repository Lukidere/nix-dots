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
    property real   trackPos:  0
    property real   trackLen:  0

    // Collapsed: only play/pause visible (44px).
    // Expanded: track info + prev above, next below (152px).
    // +3px at bottom for progress bar.
    height: active ? (expanded ? 155 : 47) : 0
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

    // ── Track progress ────────────────────────────────────────────────
    readonly property Timer _posPoll: Timer {
        interval: 1000; running: root.active && root.isPlaying; repeat: true
        onTriggered: { posProc.running = false; posProc.running = true }
    }
    Process {
        id: posProc; running: false
        command: ["sh", "-c", "playerctl position 2>/dev/null; echo; playerctl metadata mpris:length 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const pos = parseFloat(lines[0])
                const len = parseInt(lines[1])
                if (!isNaN(pos)) root.trackPos = pos
                if (!isNaN(len) && len > 0) root.trackLen = len / 1000000
            }
        }
    }

    // Thin progress bar at bottom (always visible when active)
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 3
        visible: root.active
        color: Qt.lighter(Colors.background, 1.5)
        Rectangle {
            width: root.trackLen > 0
                ? parent.width * Math.min(1, root.trackPos / root.trackLen)
                : 0
            height: 3; color: Colors.color4
            Behavior on width { NumberAnimation { duration: 800 } }
        }
    }
}
