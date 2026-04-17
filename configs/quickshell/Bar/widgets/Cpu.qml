import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44; height: 44
    property real cpuPercent: 0
    property var  _prev: null
    Text {
        anchors { centerIn: parent; verticalCenterOffset: -6 }
        text: "󰻠"
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
        color: ma.containsMouse ? Colors.color4
             : root.cpuPercent > 80 ? Colors.color1
             : root.cpuPercent > 50 ? Colors.color3
             : Colors.color2
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 5 }
        text: Math.round(root.cpuPercent) + "%"; font.pixelSize: 9; color: Colors.foreground
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: htopProc.running = true }
    Process { id: htopProc; command: ["sh", "-c", "ghostty -e htop"] }
    readonly property FileView statFile: FileView { path: "/proc/stat"; watchChanges: false }
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: {
            root.statFile.reload()
            const text = root.statFile.text()
            if (!text) return
            const parts = text.split("\n")[0].split(/\s+/).slice(1).map(Number)
            const idle  = parts[3] + parts[4]
            const total = parts.reduce((a, b) => a + b, 0)
            if (root._prev) {
                const dT = total - root._prev.total
                const dI = idle  - root._prev.idle
                root.cpuPercent = dT > 0 ? (1 - dI / dT) * 100 : 0
            }
            root._prev = { total, idle }
        }
    }
}
