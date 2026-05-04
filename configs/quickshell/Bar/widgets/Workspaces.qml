import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44
    implicitHeight: wsColumn.implicitHeight
    property var barScreen
    property var workspaces: []

    // Static background dots
    Column {
        id: wsColumn
        spacing: 2

        Repeater {
            model: root.workspaces
            delegate: Item {
                width: 44; height: 14
                Rectangle {
                    width: 8; height: 8; radius: 4
                    anchors.centerIn: parent
                    color: Colors.color8
                    opacity: 0.45
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        focusProc.command = ["niri","msg","action","focus-workspace",String(modelData.idx)]
                        focusProc.running = false; focusProc.running = true
                    }
                }
                WheelHandler {
                    onWheel: function(e) {
                        const cmd = e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down"
                        focusProc.command = ["niri","msg","action",cmd]
                        focusProc.running = false; focusProc.running = true
                    }
                }
            }
        }
    }

    // Sliding active pill — glides vertically to the focused workspace
    Rectangle {
        id: activePill
        property int focusedIndex: {
            for (let i = 0; i < root.workspaces.length; i++)
                if (root.workspaces[i].is_focused) return i
            return -1
        }
        visible: focusedIndex >= 0
        // slot = item height (14) + spacing (2) = 16; pill (h8) centering offset = 3
        y: focusedIndex >= 0 ? focusedIndex * 16 + 3 : 0
        x: (44 - 28) / 2
        width: 28; height: 8; radius: 4
        color: Colors.color4
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // Soft glow halo behind the pill
        Rectangle {
            anchors.centerIn: parent
            width: 36; height: 14; radius: 7
            color: Colors.color4
            opacity: 0.18
            z: -1
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
                    const screenName = root.barScreen ? root.barScreen.name : null
                    if (screenName) {
                        ws = ws.filter(w => w.output === screenName)
                    } else {
                        // fallback: show focused screen's workspaces
                        const focused = ws.find(w => w.is_focused)
                        const out = focused ? focused.output : (ws[0] ? ws[0].output : null)
                        if (out) ws = ws.filter(w => w.output === out)
                    }
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
