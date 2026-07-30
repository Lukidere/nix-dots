pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared clipboard history - ONE wl-paste watcher for all screens.
// (Instantiating the watcher per-monitor caused competing clipboard reads
//  and Qt DataOffer timeouts that stalled the UI.)
Item {
    id: root
    visible: false; width: 0; height: 0

    property var entries: []
    property string _lastClip: ""

    function copy(text) {
        root._lastClip = text
        _clipCopy.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", text]
        _clipCopy.running = false; _clipCopy.running = true
    }
    function clear() { root.entries = [] }

    property Timer _restart: Timer {
        interval: 2000; repeat: false
        onTriggered: _watcher.running = true
    }

    // watcher only signals "changed"; content fetched by a one-shot read
    property Process _watcher: Process {
        command: ["wl-paste", "--watch", "echo"]
        running: true
        onRunningChanged: if (!running) root._restart.start()
        stdout: SplitParser {
            onRead: { root._read.running = false; root._read.running = true }
        }
    }
    property Process _read: Process {
        command: ["wl-paste", "--no-newline"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const clip = this.text.trim()
                if (clip !== "" && clip !== root._lastClip) {
                    root._lastClip = clip
                    const entry = { text: clip, timestamp: Qt.formatTime(new Date(), "hh:mm") }
                    const filtered = root.entries.filter(e => e.text !== clip)
                    root.entries = [entry].concat(filtered).slice(0, 50)
                }
            }
        }
    }
    property Process _clipCopy: Process { running: false }
}
