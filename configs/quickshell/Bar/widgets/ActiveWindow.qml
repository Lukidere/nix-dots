import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44
    height: windowTitle !== "" ? 80 : 0
    clip: true
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    property var    barScreen
    property string windowTitle: ""
    property string windowFullId: ""

    readonly property Process _proc: Process {
        command: ["niri", "msg", "-j", "focused-window"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(this.text)
                    if (!w || !w.app_id) { root.windowTitle = ""; return }
                    const id = w.app_id
                    root.windowFullId = id
                    // Use last segment of reverse-domain (e.g. com.mitchellh.ghostty → ghostty)
                    root.windowTitle = id.includes(".") ? id.split(".").pop() : id
                } catch(e) { root.windowTitle = ""; root.windowFullId = "" }
            }
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: { root._proc.running = false; root._proc.running = true }
    }

    Text {
        anchors.centerIn: parent
        text: root.windowTitle
        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
        color: Colors.color8
        rotation: 270
        width: 72
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    MouseArea {
        anchors.fill: parent; hoverEnabled: true
        onEntered: if (root.windowFullId !== "")
            TooltipState.show(root.windowFullId, mapToGlobal(0, height / 2).y, root.barScreen)
        onExited: TooltipState.hide()
    }
}
