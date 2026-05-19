pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string status:   "Stopped"
    property string title:    "Nothing playing"
    property string artist:   ""
    property string album:    ""
    property string artUrl:   ""
    property string player:   ""
    property real   position: 0
    property real   duration: 0
    readonly property bool active:  status === "Playing" || status === "Paused"
    readonly property bool playing: status === "Playing"

    readonly property Process _metaProc: Process {
        command: ["sh", "-c",
            "playerctl status --format '{{playerName}}|{{status}}' 2>/dev/null; echo '---';" +
            "playerctl metadata --format '{{title}}|{{artist}}|{{album}}|{{mpris:artUrl}}|{{mpris:length}}' 2>/dev/null; echo '---';" +
            "playerctl position 2>/dev/null"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("---\n")
                const hdr = (parts[0] || "").trim().split("|")
                if (hdr[0]) root.player = hdr[0]
                const s = hdr[1] || ""
                root.status = s === "Playing" ? "Playing" : s === "Paused" ? "Paused" : "Stopped"
                if (parts.length > 1) {
                    const f = (parts[1] || "").trim().split("|")
                    root.title    = f[0] || "Nothing playing"
                    root.artist   = f[1] || ""
                    root.album    = f[2] || ""
                    root.artUrl   = f[3] || ""
                    const len = parseInt(f[4] || "0")
                    root.duration = len > 0 ? len / 1000000 : 0
                }
                if (parts.length > 2) {
                    const p = parseFloat((parts[2] || "").trim())
                    if (!isNaN(p)) root.position = p
                }
            }
        }
    }

    readonly property Timer _poll: Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: { root._metaProc.running = false; root._metaProc.running = true }
    }


    function playPause() {
        root.status = root.playing ? "Paused" : "Playing"
        _ppProc.running = false; _ppProc.running = true
    }
    function previous() {
        _prevProc.command = root.player !== ""
            ? ["playerctl", "-p", root.player, "previous"] : ["playerctl", "previous"]
        _prevProc.running = false; _prevProc.running = true
    }
    function next() {
        _nextProc.command = root.player !== ""
            ? ["playerctl", "-p", root.player, "next"] : ["playerctl", "next"]
        _nextProc.running = false; _nextProc.running = true
    }

    property Process _ppProc:   Process { command: ["playerctl", "play-pause"]; running: false }
    property Process _prevProc: Process { running: false }
    property Process _nextProc: Process { running: false }
}
