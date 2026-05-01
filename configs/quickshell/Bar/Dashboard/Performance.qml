import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    height: col.implicitHeight

    property real   cpuPct:    0
    property var    _cpuPrev:  null
    property real   gpuPct:    0
    property bool   gpuReady:  false
    property real   ramPct:    0
    property string ramLabel:  "-- / -- GiB"
    property real   diskPct:   0
    property string diskLabel: "-- / -- GiB"
    property string loadAvg:   "-- -- --"
    property string uptimeStr: "--"

    readonly property FileView _statFile: FileView { path: "/proc/stat"; watchChanges: false }
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: {
            root._statFile.reload()
            const t = root._statFile.text()
            if (!t) return
            const p = t.split("\n")[0].split(/\s+/).slice(1).map(Number)
            const idle = p[3] + p[4]
            const total = p.reduce((a,b) => a+b, 0)
            if (root._cpuPrev) {
                const dT = total - root._cpuPrev.total
                const dI = idle  - root._cpuPrev.idle
                root.cpuPct = dT > 0 ? (1 - dI/dT)*100 : 0
            }
            root._cpuPrev = {total, idle}
        }
    }

    readonly property Process _gpuProc: Process {
        command: ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim())
                if (!isNaN(v)) { root.gpuPct = v; root.gpuReady = true }
            }
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: { root._gpuProc.running = false; root._gpuProc.running = true }
    }

    readonly property FileView _memFile: FileView { path: "/proc/meminfo"; watchChanges: false }
    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: {
            root._memFile.reload()
            const t = root._memFile.text()
            if (!t) return
            const total = parseInt(t.match(/MemTotal:\s+(\d+)/)?.[1] || 0)
            const avail = parseInt(t.match(/MemAvailable:\s+(\d+)/)?.[1] || 0)
            const used  = total - avail
            root.ramPct   = total > 0 ? (used/total)*100 : 0
            root.ramLabel = (used/1048576).toFixed(1) + " / " + (total/1048576).toFixed(1) + " GiB"
        }
    }

    readonly property Process _diskProc: Process {
        command: ["df", "-BM", "/home", "--output=size,used"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                if (lines.length < 2) return
                const p = lines[1].trim().split(/\s+/)
                const size = parseInt(p[0])
                const used = parseInt(p[1])
                root.diskPct   = size > 0 ? (used/size)*100 : 0
                root.diskLabel = (used/1024).toFixed(0) + " / " + (size/1024).toFixed(0) + " GiB"
            }
        }
    }
    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: { root._diskProc.running = false; root._diskProc.running = true }
    }

    readonly property FileView _loadFile:   FileView { path: "/proc/loadavg"; watchChanges: false }
    readonly property FileView _uptimeFile: FileView { path: "/proc/uptime";  watchChanges: false }
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            root._loadFile.reload()
            const lt = root._loadFile.text()
            if (lt) {
                const p = lt.trim().split(" ")
                root.loadAvg = p[0] + " " + p[1] + " " + p[2]
            }
            root._uptimeFile.reload()
            const ut = root._uptimeFile.text()
            if (ut) {
                let s = parseInt(ut.trim().split(" ")[0])
                const d = Math.floor(s/86400); s %= 86400
                const h = Math.floor(s/3600);  s %= 3600
                const m = Math.floor(s/60)
                root.uptimeStr = (d > 0 ? d+"d " : "") + h+"h "+m+"m"
            }
        }
    }

    component MetricRow: Column {
        id: mr
        property string label: ""
        property string value: ""
        property real   pct:   0
        property color  clr:   Colors.color4
        spacing: 4

        Item {
            width: mr.width; height: 14
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: mr.label
                font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                color: Colors.foreground
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: mr.value
                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                color: Colors.color6
            }
        }
        Rectangle {
            width: mr.width; height: 4; radius: 2
            color: Qt.lighter(Colors.background, 1.4)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, mr.pct/100))
                height: 4; radius: 2; color: mr.clr
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        MetricRow {
            width: col.width; label: "CPU"
            value: Math.round(root.cpuPct) + "%"; pct: root.cpuPct
            clr: root.cpuPct > 80 ? Colors.color1 : root.cpuPct > 50 ? Colors.color3 : Colors.color2
        }
        MetricRow {
            width: col.width; label: "GPU"
            value: root.gpuReady ? Math.round(root.gpuPct) + "%" : "N/A"
            pct: root.gpuReady ? root.gpuPct : 0
            clr: root.gpuPct > 80 ? Colors.color1 : root.gpuPct > 50 ? Colors.color3 : Colors.color2
            visible: root.gpuReady
        }
        MetricRow { width: col.width; label: "Memory"; value: root.ramLabel;  pct: root.ramPct;  clr: Colors.color4 }
        MetricRow { width: col.width; label: "Disk";   value: root.diskLabel; pct: root.diskPct; clr: Colors.color5 }

        Text {
            text: "Load  " + root.loadAvg + "   ·   Up " + root.uptimeStr
            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
            color: Colors.color6
        }
    }
}
