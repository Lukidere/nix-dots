pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Per-app playback volumes for the dashboard mixer (one backend for all screens).
Item {
    id: root
    visible: false; width: 0; height: 0

    property var  streams: []
    property bool loading: false

    readonly property string _script: Quickshell.env("HOME") + "/.config/quickshell/scripts/qs-appvol.py"

    function refresh() {
        root.loading = true
        _list.running = false; _list.running = true
    }
    function setVolume(id, v) {
        _set.command = ["wpctl", "set-volume", String(id), (v / 100).toFixed(2)]
        _set.running = false; _set.running = true
        // reflect immediately so the slider is responsive
        root.streams = root.streams.map(s => s.id === id ? Object.assign({}, s, { volume: v }) : s)
    }
    function toggleMute(id) {
        _mute.command = ["wpctl", "set-mute", String(id), "toggle"]
        _mute.running = false; _mute.running = true
        root.streams = root.streams.map(s => s.id === id ? Object.assign({}, s, { muted: !s.muted }) : s)
    }

    Process { id: _set;  running: false }
    Process { id: _mute; running: false }

    readonly property Process _list: Process {
        command: ["python3", root._script, "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                try { root.streams = JSON.parse(this.text) } catch (e) { root.streams = [] }
            }
        }
    }
}
