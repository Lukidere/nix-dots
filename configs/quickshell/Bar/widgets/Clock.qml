import QtQuick
import "../../Theme"

Item {
    id: root
    width: 44; height: 52
    property bool showDate: false
    property date currentTime: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.currentTime = new Date() }
    Column {
        anchors.centerIn: parent; spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.showDate ? Qt.formatDate(root.currentTime,"dd") : Qt.formatTime(root.currentTime,"hh")
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.bold: true
            color: Colors.foreground
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.showDate ? Qt.formatDate(root.currentTime,"MM") : Qt.formatTime(root.currentTime,"mm")
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.bold: true
            color: Colors.color4
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.showDate = !root.showDate }
}
