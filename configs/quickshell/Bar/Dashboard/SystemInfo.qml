import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    height: col.implicitHeight

    property string hostname:  ""
    property string kernel:    ""
    property string uptimeStr: ""
    property string shell:     ""

    readonly property Process _infoProc: Process {
        command: ["sh", "-c", "hostname; uname -r; basename $SHELL"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                if (lines[0]) root.hostname  = lines[0]
                if (lines[1]) root.kernel    = lines[1]
                if (lines[2]) root.shell     = lines[2]
            }
        }
    }

    readonly property FileView _uptimeFile: FileView { path: "/proc/uptime"; watchChanges: false }
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: {
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
    Component.onCompleted: {
        _uptimeFile.reload()
        const ut = _uptimeFile.text()
        if (ut) {
            let s = parseInt(ut.trim().split(" ")[0])
            const d = Math.floor(s/86400); s %= 86400
            const h = Math.floor(s/3600);  s %= 3600
            const m = Math.floor(s/60)
            uptimeStr = (d > 0 ? d+"d " : "") + h+"h "+m+"m"
        }
    }

    component InfoRow: Item {
        property string label: ""
        property string value: ""
        width: parent.width; height: 16
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: parent.label
            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
            color: Colors.color6
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: parent.value
            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
            color: Colors.foreground
        }
    }

    Column {
        id: col
        width: parent.width; spacing: 6
        InfoRow { label: "Hostname"; value: root.hostname }
        InfoRow { label: "Kernel";   value: root.kernel }
        InfoRow { label: "Uptime";   value: root.uptimeStr }
        InfoRow { label: "Shell";    value: root.shell }
        InfoRow { label: "WM";       value: "Niri" }
    }
}
