pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared Gmail state - one IMAP backend for all screens.
Item {
    id: root
    visible: false; width: 0; height: 0

    property bool configured: false
    property bool loading:    false
    property string error:    ""
    property int  unreadCount: 0
    property var  mails:      []

    // opened mail
    property bool   readOpen: false
    property string readFrom: ""
    property string readSubject: ""
    property string readDate: ""
    property string readBody: ""

    readonly property string _script: Quickshell.env("HOME") + "/.config/quickshell/scripts/qs-gmail.py"

    function checkStatus() { _run(["status"]) }
    function refresh()     { _run(["list"]) }
    function openMail(uid) { root.readOpen = true; root.readBody = ""; _run(["read", uid]) }
    function closeMail()   { root.readOpen = false }

    function _run(args) {
        root.error = ""
        root.loading = true
        _proc.running = false
        _proc.command = ["python3", _script].concat(args)
        _proc._cmd = args.length > 1 ? args[0] + ":" + args[1] : args[0]
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
                const cmd = _proc._cmd.split(":")[0]
                if (cmd === "status") {
                    root.configured = data.configured === true
                    if (root.configured) _count.running = true
                } else if (cmd === "list") {
                    root.mails = data
                    root.unreadCount = data.filter(x => x.unread).length
                } else if (cmd === "read") {
                    const uid = _proc._cmd.split(":")[1]
                    root.readFrom = data.from
                    root.readSubject = data.subject
                    root.readDate = data.date
                    root.readBody = data.body
                    // reflect the \Seen flag locally
                    root.mails = root.mails.map(x => x.uid === uid ? Object.assign({}, x, {unread: false}) : x)
                    root.unreadCount = root.mails.filter(x => x.unread).length
                }
            }
        }
    }

    // Unread badge poll - light IMAP query every 3 min
    readonly property Process _count: Process {
        command: ["python3", root._script, "count"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    if (d.unread !== undefined) root.unreadCount = d.unread
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 180000; repeat: true; running: root.configured
        onTriggered: { _count.running = false; _count.running = true }
    }

    Component.onCompleted: checkStatus()
}
