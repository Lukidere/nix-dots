import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    property var barScreen
    width: 44; height: 44
    property real ramPercent: 0
    Text {
        anchors { centerIn: parent; verticalCenterOffset: -6 }
        text: "󰍛"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
        color: ma.containsMouse ? Colors.color4
             : root.ramPercent > 80 ? Colors.color1
             : root.ramPercent > 50 ? Colors.color3
             : Colors.color2
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 5 }
        text: Math.round(root.ramPercent) + "%"; font.pixelSize: 9; color: Colors.foreground
    }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true
        onClicked: htopProc.running = true
        onEntered: TooltipState.show(
            "RAM  " + Math.round(root.ramPercent) + "%  ·  click for htop",
            mapToGlobal(0, height / 2).y, root.barScreen)
        onExited: TooltipState.hide()
    }
    Process { id: htopProc; command: ["sh", "-c", "ghostty -e htop"] }
    readonly property FileView memFile: FileView { path: "/proc/meminfo"; watchChanges: false }
    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: {
            root.memFile.reload()
            const text = root.memFile.text()
            if (!text) return
            const total = parseInt(text.match(/MemTotal:\s+(\d+)/)?.[1] || 0)
            const avail = parseInt(text.match(/MemAvailable:\s+(\d+)/)?.[1] || 0)
            if (total > 0)
                root.ramPercent = ((total - avail) / total) * 100
        }
    }
}
