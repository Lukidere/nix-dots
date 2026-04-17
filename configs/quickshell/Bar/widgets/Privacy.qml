import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root; width: 44; height: 44; visible: isSharing
    property bool isSharing: false
    Text {
        anchors.centerIn: parent; text: "󰐊"
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: Colors.color1
    }
    readonly property Process pwProc: Process {
        command: ["sh", "-c",
            "pw-dump --no-props 2>/dev/null | " +
            "jq -r '[.[] | select(.type==\"PipeWire:Interface:Node\") | " +
            "select(.info.props[\"media.class\"] == \"Video/Source\") | " +
            ".info.props[\"application.name\"]] | " +
            "map(select(. != null and (ascii_downcase | test(\"obs\")) | not)) | length' 2>/dev/null || echo 0"
        ]
        running: true
        stdout: StdioCollector { onStreamFinished: root.isSharing = parseInt(this.text.trim()) > 0 }
    }
    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: { root.pwProc.running = false; root.pwProc.running = true }
    }
}
