import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44
    height: expanded ? 44 + 8 + 80 + 8 + 44 : 44
    clip: true
    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    property bool expanded:  hoverArea.containsMouse
    property int  volume:    50
    property bool muted:     false
    property bool micMuted:  false
    MouseArea {
        id: hoverArea; anchors.fill: parent; hoverEnabled: true
        propagateComposedEvents: true
        onClicked: mouse => mouse.accepted = false
        onWheel: event => {
            const d = event.angleDelta.y > 0 ? 5 : -5
            const v = Math.max(0, Math.min(100, root.volume + d))
            root.volume = v
            volSetProc.command = ["wpctl","set-volume","@DEFAULT_AUDIO_SINK@",(v/100).toFixed(2)]
            volSetProc.running = false; volSetProc.running = true
        }
    }
    Item {
        id: volBtn; width: 44; height: 44
        Text {
            anchors.centerIn: parent
            text: root.muted ? "󰝟" : root.volume>66 ? "󰕾" : root.volume>33 ? "󰖀" : "󰕿"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 18
            color: root.muted ? Colors.color1 : Colors.foreground
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: { root.muted = !root.muted; muteProc.running = false; muteProc.running = true }
        }
    }
    Rectangle {
        anchors { top: volBtn.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
        width: 8; height: 80; radius: 4
        color: Qt.darker(Colors.color8, 1.4)
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Rectangle {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: 8; height: parent.height * (root.volume / 100); radius: 4; color: Colors.color4
            Behavior on height { NumberAnimation { duration: 100 } }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: mouse => {
                const v = Math.max(0, Math.min(100, Math.round((1 - mouse.y / height) * 100)))
                root.volume = v
                volSetProc.command = ["wpctl","set-volume","@DEFAULT_AUDIO_SINK@",(v/100).toFixed(2)]
                volSetProc.running = false; volSetProc.running = true
            }
        }
    }
    Item {
        anchors { top: volBtn.bottom; topMargin: 8+80+8; horizontalCenter: parent.horizontalCenter }
        width: 44; height: 44
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Text {
            anchors.centerIn: parent
            text: root.micMuted ? "󰍭" : "󰍬"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 18
            color: root.micMuted ? Colors.color1 : Colors.foreground
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: { root.micMuted = !root.micMuted; micToggleProc.running = false; micToggleProc.running = true }
        }
    }
    Process { id: volSetProc;    running: false }
    Process { id: muteProc;      command: ["wpctl","set-mute","@DEFAULT_AUDIO_SINK@","toggle"]; running: false }
    Process { id: micToggleProc; command: ["wpctl","set-mute","@DEFAULT_AUDIO_SOURCE@","toggle"]; running: false }
    readonly property Process audioProc: Process {
        command: ["sh","-c","wpctl get-volume @DEFAULT_AUDIO_SINK@ && wpctl get-volume @DEFAULT_AUDIO_SOURCE@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
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
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: { root.audioProc.running=false; root.audioProc.running=true }
    }
}
