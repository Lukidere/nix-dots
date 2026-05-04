import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    property var barScreen
    width: 44
    height: col.implicitHeight

    // CPU
    property real cpuPct:   0
    property var  _cpuPrev: null
    readonly property FileView statFile: FileView { path: "/proc/stat"; watchChanges: false }
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: {
            root.statFile.reload()
            const t = root.statFile.text()
            if (!t) return
            const parts = t.split("\n")[0].split(/\s+/).slice(1).map(Number)
            const idle  = parts[3] + parts[4]
            const total = parts.reduce((a, b) => a + b, 0)
            if (root._cpuPrev) {
                const dT = total - root._cpuPrev.total
                const dI = idle  - root._cpuPrev.idle
                root.cpuPct = dT > 0 ? (1 - dI / dT) * 100 : 0
            }
            root._cpuPrev = { total, idle }
        }
    }

    // RAM
    property real   ramPct:   0
    property string ramLabel: ""
    readonly property FileView memFile: FileView { path: "/proc/meminfo"; watchChanges: false }
    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: {
            root.memFile.reload()
            const t = root.memFile.text()
            if (!t) return
            const total = parseInt(t.match(/MemTotal:\s+(\d+)/)?.[1] || 0)
            const avail = parseInt(t.match(/MemAvailable:\s+(\d+)/)?.[1] || 0)
            const used  = total - avail
            root.ramPct   = total > 0 ? (used / total) * 100 : 0
            root.ramLabel = (used / 1048576).toFixed(1) + "/" + (total / 1048576).toFixed(1) + "G"
        }
    }

    // Disk
    property real   diskPct:   0
    property string diskLabel: ""
    readonly property Process dfProc: Process {
        command: ["df", "-BG", "/home", "--output=size,used"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                if (lines.length < 2) return
                const p    = lines[1].trim().split(/\s+/)
                const size = parseInt(p[0])
                const used = parseInt(p[1])
                if (size > 0) {
                    root.diskPct   = (used / size) * 100
                    root.diskLabel = used + "/" + size + "G"
                }
            }
        }
    }
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: { root.dfProc.running = false; root.dfProc.running = true }
    }

    Process { id: htopProc; command: ["sh", "-c", "ghostty -e htop"]; running: false }

    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true
        onClicked: { htopProc.running = false; htopProc.running = true }
        onEntered: TooltipState.show(
            "CPU " + Math.round(root.cpuPct) + "%  |  RAM " + Math.round(root.ramPct) + "% (" + root.ramLabel + ")  |  Disk " + Math.round(root.diskPct) + "% (" + root.diskLabel + ")  |  click for htop",
            mapToGlobal(0, height / 2).y, root.barScreen)
        onExited: TooltipState.hide()
    }

    Column {
        id: col
        width: parent.width
        spacing: 3

        // CPU row
        Item {
            id: cpuRow
            width: 44; height: 18
            property color barClr: root.cpuPct > 80 ? Colors.color1
                                 : root.cpuPct > 50 ? Colors.color3 : Colors.color2
            Text {
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter; verticalCenterOffset: -2 }
                text: "\uF85A"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                color: ma.containsMouse ? Colors.color4 : cpuRow.barClr
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter; verticalCenterOffset: -2 }
                text: Math.round(root.cpuPct) + "%"
                font.pixelSize: 8; color: Colors.color6
            }
        }

        // RAM row
        Item {
            id: ramRow
            width: 44; height: 18
            property color barClr: root.ramPct > 80 ? Colors.color1
                                 : root.ramPct > 50 ? Colors.color3 : Colors.color4
            Text {
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter; verticalCenterOffset: -2 }
                text: "\uF2DB"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                color: ma.containsMouse ? Colors.color4 : ramRow.barClr
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter; verticalCenterOffset: -2 }
                text: Math.round(root.ramPct) + "%"
                font.pixelSize: 8; color: Colors.color6
            }
        }

        // Disk row
        Item {
            id: diskRow
            width: 44; height: 18
            property color barClr: root.diskPct > 90 ? Colors.color1
                                 : root.diskPct > 70 ? Colors.color3 : Colors.color5
            Text {
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter; verticalCenterOffset: -2 }
                text: "\uF0A0"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                color: ma.containsMouse ? Colors.color4 : diskRow.barClr
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Text {
                anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter; verticalCenterOffset: -2 }
                text: Math.round(root.diskPct) + "%"
                font.pixelSize: 8; color: Colors.color6
            }
        }
    }
}
