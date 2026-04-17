import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    width: 44; height: 44
    Text {
        anchors.centerIn: parent
        text: "\uF313"
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22
        color: ma.containsMouse ? Colors.color4 : Colors.foreground
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: terminal.running = true }
    Process { id: terminal; command: ["sh", "-c", "ghostty || kitty"] }
}
