import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: 44; height: 44
    property string icon:    "󰤭"
    property color  clr:     Colors.color1
    property bool   wifiOn:  true
    Text {
        anchors.centerIn: parent; text: root.icon
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
        color: ma.containsMouse ? Qt.lighter(root.clr, 1.4) : root.clr
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                nmProc.running = false; nmProc.running = true
            } else {
                root.wifiOn = !root.wifiOn
                if (root.wifiOn) {
                    root.icon = "󰤨"; root.clr = Colors.color8
                    wifiToggle.command = ["rfkill", "unblock", "wifi"]
                } else {
                    root.icon = "󰤮"; root.clr = Colors.color1
                    wifiToggle.command = ["rfkill", "block", "wifi"]
                }
                wifiToggle.running = false; wifiToggle.running = true
            }
        }
    }
    Process { id: nmProc;     command: ["nm-connection-editor"] }
    Process { id: wifiToggle; running: false }
    readonly property Process netProc: Process {
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION,SIGNAL", "device"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                let wifi = null, eth = null, wifiSeen = false
                for (const line of lines) {
                    const p = line.split(":")
                    if (p[0]==="wifi") wifiSeen = true
                    if (p[0]==="wifi"     && p[1]==="connected") wifi={name:p[2],signal:parseInt(p[3])||0}
                    if (p[0]==="ethernet" && p[1]==="connected") eth={name:p[2]}
                }
                if (eth) {
                    root.icon="󰈀"; root.clr=Colors.color2
                } else if (wifi) {
                    const s=wifi.signal
                    root.icon=s>75?"󰤨":s>50?"󰤥":s>25?"󰤢":"󰤟"
                    root.clr=Colors.color2
                } else if (!wifiSeen) {
                    root.icon="󰤮"; root.clr=Colors.color8; root.wifiOn=false
                } else {
                    root.icon="󰤭"; root.clr=Colors.color1
                }
            }
        }
    }
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: { root.netProc.running=false; root.netProc.running=true }
    }
}
