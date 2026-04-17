import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44
    property bool active: false
    property bool isPlaying: false
    property bool expanded: hoverArea.containsMouse

    height: active ? (expanded ? 130 : 44) : 0
    visible: active
    clip: true
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }

    MouseArea { id: hoverArea; anchors.fill: parent; hoverEnabled: true }

    Component.onCompleted: { statusProc.running = false; statusProc.running = true }

    readonly property Timer _poll: Timer {
        interval: 500; running: true; repeat: true
        onTriggered: { statusProc.running = false; statusProc.running = true }
    }

    Process {
        id: statusProc
        running: false
        command: ["playerctl", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim()
                root.active    = (s === "Playing" || s === "Paused")
                root.isPlaying = (s === "Playing")
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uF048"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
            color: Colors.foreground
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            MouseArea { anchors.fill: parent; onClicked: { prevProc.running = false; prevProc.running = true } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.isPlaying ? "\uF04C" : "\uF04B"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: Colors.color4
            Behavior on color { ColorAnimation { duration: 150 } }
            MouseArea { anchors.fill: parent; onClicked: { ppProc.running = false; ppProc.running = true } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uF051"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
            color: Colors.foreground
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            MouseArea { anchors.fill: parent; onClicked: { nextProc.running = false; nextProc.running = true } }
        }
    }

    Process { id: prevProc; command: ["playerctl", "previous"];   running: false }
    Process { id: ppProc;   command: ["playerctl", "play-pause"]; running: false }
    Process { id: nextProc; command: ["playerctl", "next"];       running: false }
}
