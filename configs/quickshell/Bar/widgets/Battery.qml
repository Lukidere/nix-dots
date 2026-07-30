import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    property var barScreen
    width: 44; height: 44
    property bool   menuOpen: false
    property int    pct:    0
    property string status: "Unknown"
    property bool   ready:  false
    readonly property string icon: {
        if (!ready) return "󰂑"
        if (status === "Charging")     return "󰂄"
        if (status === "Full")         return "󰁹"
        if (pct > 90) return "󰁹"; if (pct > 80) return "󰂂"; if (pct > 70) return "󰂁"
        if (pct > 60) return "󰂀"; if (pct > 50) return "󰁿"; if (pct > 40) return "󰁾"
        if (pct > 30) return "󰁽"; if (pct > 20) return "󰁼"; if (pct > 10) return "󰁻"
        return "󰁺"
    }
    readonly property color batColor: {
        if (!ready)                  return Colors.color8
        if (status === "Charging")   return Colors.color2
        if (pct <= 15)               return Colors.color1
        if (pct <= 30)               return Colors.color3
        return Colors.foreground
    }
    Text {
        anchors { centerIn: parent; verticalCenterOffset: -6 }
        text: root.icon
        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
        color: root.batColor
        Behavior on color { ColorAnimation { duration: 300 } }
    }
    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 5 }
        text: root.ready ? root.pct + "%" : "?"
        font.pixelSize: 9; color: root.batColor
    }
    MouseArea {
        anchors.fill: parent; hoverEnabled: true
        onClicked: root.menuOpen = !root.menuOpen
        onEntered: TooltipState.show(
            (root.ready ? root.pct + "%" : "?") + "  ·  " + root.status,
            mapToGlobal(0, height / 2).y, root.barScreen)
        onExited: TooltipState.hide()
    }
    readonly property Process batProc: Process {
        command: ["sh", "-c",
            "f=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); " +
            "s=$(ls /sys/class/power_supply/BAT*/status   2>/dev/null | head -1); " +
            "[ -f \"$f\" ] && cat \"$f\"; echo; [ -f \"$s\" ] && cat \"$s\""
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const p = parseInt(lines[0])
                if (!isNaN(p)) { root.pct = p; root.ready = true }
                if (lines[1]) root.status = lines[1].trim()
            }
        }
    }
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: { root.batProc.running = false; root.batProc.running = true }
    }

    // ── Low-battery warnings (once per threshold crossing) ──────────
    property bool _warnedLow:  false
    property bool _warnedCrit: false
    onPctChanged: {
        const discharging = root.status !== "Charging" && root.status !== "Full"
        if (!discharging) { root._warnedLow = false; root._warnedCrit = false; return }
        if (pct <= 5 && !_warnedCrit) {
            _warnedCrit = true
            _notify.command = ["notify-send", "-u", "critical", "-i", "battery-caution",
                "Battery critical", pct + "% - suspending soon"]
            _notify.running = false; _notify.running = true
            _suspend.running = false; _suspend.running = true
        } else if (pct <= 15 && !_warnedLow) {
            _warnedLow = true
            _notify.command = ["notify-send", "-u", "critical", "-i", "battery-low",
                "Battery low", pct + "% - plug in soon"]
            _notify.running = false; _notify.running = true
        }
    }
    Process { id: _notify;  running: false }
    // 20s grace so the notification is seen; re-check status before sleeping
    Process { id: _suspend; running: false
        command: ["sh", "-c", "sleep 20; b=$(cat /sys/class/power_supply/BAT*/status | head -1); [ \"$b\" != Charging ] && systemctl suspend"] }
}
