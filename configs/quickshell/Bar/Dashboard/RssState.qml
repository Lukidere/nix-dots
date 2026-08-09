pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared RSS state - one feed fetcher for all screens.
Item {
    id: root
    visible: false; width: 0; height: 0

    property bool configured: false
    property bool loading:    false
    property string error:    ""
    property var  items:      []

    readonly property string _script: Quickshell.env("HOME") + "/.config/quickshell/scripts/qs-rss.py"

    function checkStatus() { _run(["status"]) }
    function refresh()     { _run(["list"]) }

    function _run(args) {
        root.error = ""
        root.loading = true
        _proc.running = false
        _proc.command = ["python3", _script].concat(args)
        _proc._cmd = args[0]
        _proc.running = true
    }

    readonly property Process _proc: Process {
        property string _cmd: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                let data
                try { data = JSON.parse(this.text) } catch (e) { root.error = "bad response"; return }
                if (data && data.error !== undefined) { root.error = data.error; return }
                if (_proc._cmd === "status") {
                    root.configured = data.configured === true
                    if (root.configured) root.refresh()
                } else if (_proc._cmd === "list") {
                    root.items = data
                }
            }
        }
    }

    // Refresh feeds every 15 min while configured
    Timer {
        interval: 900000; repeat: true; running: root.configured
        onTriggered: root.refresh()
    }

    Component.onCompleted: checkStatus()
}
