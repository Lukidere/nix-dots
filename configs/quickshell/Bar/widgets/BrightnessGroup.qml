import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44
    height: expanded ? 44 + 8 + 80 : 44
    clip: true
    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    property bool expanded:   hoverArea.containsMouse
    property int  brightness: 50
    MouseArea {
        id: hoverArea; anchors.fill: parent; hoverEnabled: true
        propagateComposedEvents: true
        onClicked: mouse => mouse.accepted = false
        onWheel: event => {
            const d = event.angleDelta.y > 0 ? 5 : -5
            const v = Math.max(1, Math.min(100, root.brightness + d))
            root.brightness = v
            setProc.command = ["brightnessctl", "set","-d","amdgpu_bl1", v + "%"]
            setProc.running = false; setProc.running = true
        }
    }
    Item {
        id: brightBtn; width: 44; height: 44
        Text {
            anchors.centerIn: parent
            text: root.brightness>66 ? "󰃟" : root.brightness>33 ? "󰃞" : "󰃝"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: Colors.foreground
        }
    }
    Rectangle {
        anchors { top: brightBtn.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
        width: 8; height: 80; radius: 4
        color: Qt.darker(Colors.color8, 1.4)
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Rectangle {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: 8; height: parent.height*(root.brightness/100); radius: 4; color: Colors.color11
            Behavior on height { NumberAnimation { duration: 100 } }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: mouse => {
                const v = Math.max(1, Math.round((1 - mouse.y / height) * 100))
                root.brightness = v
                setProc.command = ["brightnessctl", "set","-d","amdgpu_bl1", v + "%"]
                setProc.running = false; setProc.running = true
            }
        }
    }
    Process { id: setProc; running: false }
    readonly property Process brightProc: Process {
        command: ["sh","-c","echo $(( $(brightnessctl get -d amdgpu_bl1) * 100 / $(brightnessctl max -d amdgpu_bl1) ))"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim())
                if (!isNaN(v)) root.brightness = v
            }
        }
    }
    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: { root.brightProc.running=false; root.brightProc.running=true }
    }
}
