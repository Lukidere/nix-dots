import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44; height: 52

    property real rxSpeed: 0
    property real txSpeed: 0
    property real _rxPrev: 0
    property real _txPrev: 0
    property bool _init:   false

    function formatSpeed(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + "M"
        if (bps >= 1024)    return Math.round(bps / 1024) + "K"
        return Math.round(bps) + "B"
    }

    readonly property FileView _netFile: FileView {
        path: "/proc/net/dev"
        watchChanges: false
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root._netFile.reload()
            const text = root._netFile.text()
            if (!text) return

            // Skip 2 header lines; rx_bytes=col[1], tx_bytes=col[9]
            const lines = text.split("\n").slice(2)
            let totalRx = 0, totalTx = 0
            for (const line of lines) {
                const parts = line.trim().split(/\s+/)
                if (parts.length < 10) continue
                const iface = parts[0].replace(":", "")
                if (iface === "lo" || iface.startsWith("docker")
                    || iface.startsWith("br-") || iface.startsWith("veth")) continue
                totalRx += parseInt(parts[1]) || 0
                totalTx += parseInt(parts[9]) || 0
            }

            if (root._init) {
                root.rxSpeed = Math.max(0, totalRx - root._rxPrev)
                root.txSpeed = Math.max(0, totalTx - root._txPrev)
            }
            root._rxPrev = totalRx
            root._txPrev = totalTx
            root._init   = true
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 4

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            Text {
                text: "\u2191"
                font.pixelSize: 8; color: Colors.color4
            }
            Text {
                text: root.formatSpeed(root.txSpeed)
                font.family: "Iosevka Nerd Font"; font.pixelSize: 8
                color: Colors.foreground
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            Text {
                text: "\u2193"
                font.pixelSize: 8; color: Colors.color2
            }
            Text {
                text: root.formatSpeed(root.rxSpeed)
                font.family: "Iosevka Nerd Font"; font.pixelSize: 8
                color: Colors.foreground
            }
        }
    }
}
