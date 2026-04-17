import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44; height: 44
    property bool btOn:   false
    property bool btConn: false
    readonly property color btClr: root.btConn ? Colors.color4 : root.btOn ? Colors.foreground : Colors.color8
    Text {
        anchors.centerIn: parent
        text: root.btOn ? (root.btConn ? "\u{F00B1}" : "\u{F00AF}") : "\u{F00B2}"
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
        color: ma.containsMouse ? Qt.lighter(root.btClr, 1.4) : root.btClr
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                bmProc.running = false; bmProc.running = true
            } else {
                root.btOn = !root.btOn; root.btConn = false
                btToggle.command = root.btOn
                    ? ["rfkill", "unblock", "bluetooth"]
                    : ["rfkill", "block", "bluetooth"]
                btToggle.running = false; btToggle.running = true
            }
        }
    }
    Process { id: bmProc;   command: ["blueman-manager"] }
    Process { id: btToggle; running: false }
    readonly property Process btProc: Process {
        command: ["sh", "-c", "bluetoothctl show; bluetoothctl info 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.btOn   = /Powered: yes/.test(this.text)
                root.btConn = /Connected: yes/.test(this.text)
            }
        }
    }
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { root.btProc.running=false; root.btProc.running=true }
    }
}
