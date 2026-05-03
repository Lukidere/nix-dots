pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root
    property var items: []
    property var history: []
    property string focusedScreen: ""
    property bool dnd: false
    signal changed()

    readonly property Process _focusProc: Process {
        command: ["niri", "msg", "-j", "workspaces"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var ws = JSON.parse(this.text)
                    var focused = ws.find(function(w) { return w.is_focused })
                    if (focused) root.focusedScreen = focused.output
                } catch(e) {}
            }
        }
    }

    readonly property Timer _focusTimer: Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: { root._focusProc.running = false; root._focusProc.running = true }
    }

    readonly property NotificationServer _server: NotificationServer {
        keepOnReload: true
        onNotification: function(notif) {
            if (root.dnd) { try { notif.close() } catch(_) {}; return }
            const entry = {
                id:      notif.id,
                appName: notif.appName  || "Notification",
                appIcon: notif.appIcon  || "",
                summary: notif.summary  || "",
                body:    notif.body     || "",
                timeout: (notif.expireTimeout > 0) ? notif.expireTimeout : 5000,
                timestamp: new Date().toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'}),
                screen:  root.focusedScreen,
                _ref:    notif
            }
            root.items = root.items.concat([entry])
            root.history = [entry].concat(root.history)
            root.changed()
        }
    }

    function remove(id) {
        const entry = root.items.find(n => n.id === id)
        if (entry) { try { entry._ref.close() } catch(_) {} }
        root.items = root.items.filter(n => n.id !== id)
        root.changed()
    }
    function removeFromHistory(id) { root.history = root.history.filter(n => n.id !== id) }
    function clearHistory() { root.history = [] }
}
