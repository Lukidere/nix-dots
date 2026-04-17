import QtQuick
import Quickshell.Io
import "../../Theme"

Column {
    id: root
    spacing: 2
    property var workspaces: []
    Repeater {
        model: root.workspaces
        delegate: Item {
            width: 44; height: 14
            Rectangle {
                width: 8; height: 8; radius: 4
                anchors.centerIn: parent
                color: modelData.is_focused ? Colors.color4 : Colors.color8
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    focusProc.command = ["niri","msg","action","focus-workspace",String(modelData.idx)]
                    focusProc.running = false; focusProc.running = true
                }
            }
        }
    }
    Process { id: focusProc; running: false }
    readonly property Process wsProc: Process {
        command: ["niri", "msg", "-j", "workspaces"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let ws = JSON.parse(this.text)
                    const focused = ws.find(w => w.is_focused)
                    const out = focused ? focused.output : (ws[0] ? ws[0].output : null)
                    if (out) ws = ws.filter(w => w.output === out)
                    ws.sort((a, b) => a.idx - b.idx)
                    while (ws.length < 2) ws.push({ idx: ws.length + 1, is_focused: false })
                    root.workspaces = ws
                } catch(e) {}
            }
        }
    }
    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: { root.wsProc.running = false; root.wsProc.running = true }
    }
}
