import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    property var barScreen
    width: 44; height: 44
    property real diskPercent: 0
    Text {
        anchors { centerIn: parent; verticalCenterOffset: -6 }
        text: "󰋊"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
        color: ma.containsMouse ? Colors.color4
             : root.diskPercent > 90 ? Colors.color1
             : root.diskPercent > 70 ? Colors.color3
             : Colors.color2
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 5 }
        text: Math.round(root.diskPercent) + "%"; font.pixelSize: 9; color: Colors.foreground
    }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true
        onClicked: htopProc.running = true
        onEntered: TooltipState.show(
            "Disk  " + Math.round(root.diskPercent) + "%  ·  click for htop",
            mapToGlobal(0, height / 2).y, root.barScreen)
        onExited: TooltipState.hide()
    }
    Process { id: htopProc; command: ["sh", "-c", "ghostty -e htop"] }
    readonly property Process dfProc: Process {
        command: ["df", "-BG", "/home", "--output=size,used"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                if (lines.length < 2) return
                const p = lines[1].trim().split(/\s+/)
                const size = parseInt(p[0])
                const used = parseInt(p[1])
                if (size > 0) root.diskPercent = (used / size) * 100
            }
        }
    }
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: { root.dfProc.running = false; root.dfProc.running = true }
    }
}
