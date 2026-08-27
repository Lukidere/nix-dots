import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    property var barScreen
    width: 44
    height: col.implicitHeight

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

    property real gpuPct: 0
    property string _gpuPath: ""
    // resolve the amdgpu busy-percent sysfs path once, then read it via FileView
    // each tick - avoids spawning `cat ... | head` every 2s in an always-on widget
    readonly property Process _gpuFind: Process {
        command: ["sh", "-c", "ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector { onStreamFinished: root._gpuPath = this.text.trim() }
    }
    readonly property FileView _gpuFile: FileView { path: root._gpuPath; watchChanges: false }
    Timer {
        interval: 2000; running: root._gpuPath !== ""; repeat: true
        onTriggered: {
            root._gpuFile.reload()
            const t = root._gpuFile.text().trim()
            if (t) root.gpuPct = Math.min(100, Math.max(0, parseInt(t) || 0))
        }
    }

    Process { id: htopProc; command: ["sh", "-c", "ghostty -e htop"]; running: false }

    // hover expands `flyout` - horizontal usage bars aligned to each ring
    property bool statsHovered: false
    Timer { id: _statsHide; interval: 180; onTriggered: root.statsHovered = false }

    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true
        onClicked: { htopProc.running = false; htopProc.running = true }
        onEntered: { root.statsHovered = true; _statsHide.stop() }
        onExited:  _statsHide.restart()
    }

    Column {
        id: col
        width: parent.width
        spacing: 2

        ArcRing {
            pct: root.cpuPct; icon: "\uF0E4"
            ringColor: root.cpuPct > 80 ? Colors.color1 : root.cpuPct > 50 ? Colors.color3 : Colors.color2
            hovered: ma.containsMouse
        }
        ArcRing {
            pct: root.ramPct; icon: "\uF1C0"
            ringColor: root.ramPct > 80 ? Colors.color1 : root.ramPct > 50 ? Colors.color3 : Colors.color4
            hovered: ma.containsMouse
        }
        ArcRing {
            pct: root.diskPct; icon: "\uF0A0"
            ringColor: root.diskPct > 90 ? Colors.color1 : root.diskPct > 70 ? Colors.color3 : Colors.color5
            hovered: ma.containsMouse
        }
        ArcRing {
            pct: root.gpuPct; icon: "\u{F43F}"
            ringColor: root.gpuPct > 80 ? Colors.color1 : root.gpuPct > 50 ? Colors.color3 : Colors.color6
            hovered: ma.containsMouse
        }
    }

    // ── hover flyout: horizontal usage bars, one per ring, at matching height ──
    Item {
        id: flyout
        x: root.width + 8
        y: 0
        width: 210
        height: col.height
        opacity: root.statsHovered ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) { root.statsHovered = true; _statsHide.stop() }
                else _statsHide.restart()
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: 12
            color: Qt.lighter(Colors.background, 1.25)
            border.width: 1
            border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.25)
        }

        Column {
            anchors.fill: parent
            spacing: 2
            StatBar { label: "CPU";  pct: root.cpuPct;  accent: root.cpuPct  > 80 ? Colors.color1 : root.cpuPct  > 50 ? Colors.color3 : Colors.color2 }
            StatBar { label: "RAM";  pct: root.ramPct;  accent: root.ramPct  > 80 ? Colors.color1 : root.ramPct  > 50 ? Colors.color3 : Colors.color4 }
            StatBar { label: "DISK"; pct: root.diskPct; accent: root.diskPct > 90 ? Colors.color1 : root.diskPct > 70 ? Colors.color3 : Colors.color5 }
            StatBar { label: "GPU";  pct: root.gpuPct;  accent: root.gpuPct  > 80 ? Colors.color1 : root.gpuPct  > 50 ? Colors.color3 : Colors.color6 }
        }
    }

    // one row: LABEL [====== ] NN%  - height matches an ArcRing so rows line up
    component StatBar: Item {
        id: sb
        property string label:  ""
        property real   pct:    0
        property color  accent: Colors.color4
        width: 210; height: 38

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                width: 34; height: sb.height
                text: sb.label
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true
                color: Colors.foreground
                verticalAlignment: Text.AlignVCenter
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 118; height: 6; radius: 3
                color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.2)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, sb.pct / 100))
                    height: parent.height; radius: 3; color: sb.accent
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
            Text {
                width: 34; height: sb.height
                text: Math.round(sb.pct) + "%"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: sb.accent
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    component ArcRing: Item {
        id: ring
        width: 44; height: 38

        property real   pct:       0
        property string icon:      ""
        property color  ringColor: Colors.color4
        property bool   hovered:   false

        onPctChanged:       arc.requestPaint()
        onRingColorChanged: arc.requestPaint()

        Canvas {
            id: arc
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 2 }
            width: 36; height: 36

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const cx = width / 2, cy = height / 2, r = 14
                const start = -Math.PI / 2

                // Background track
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.strokeStyle = Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.18)
                ctx.lineWidth = 3
                ctx.stroke()

                // Value arc
                const clamped = Math.max(0, Math.min(100, ring.pct))
                if (clamped > 0) {
                    const end = start + (clamped / 100) * 2 * Math.PI
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, start, end)
                    ctx.strokeStyle = ring.ringColor
                    ctx.lineWidth = 3
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }
        }

        Text {
            anchors.centerIn: arc
            text: ring.icon
            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
            color: ring.hovered ? Colors.color4 : ring.ringColor
            Behavior on color { ColorAnimation { duration: 200 } }
        }

    }
}
