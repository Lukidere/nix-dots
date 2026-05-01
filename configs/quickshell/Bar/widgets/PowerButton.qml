import QtQuick
import "../../Theme"

Item {
    id: root
    property var barScreen
    width: 44; height: 44
    Text {
        anchors.centerIn: parent; text: "\uF011"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 16
        color: ma.containsMouse ? Colors.color1 : Colors.color8
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true
        onClicked: PowerState.toggle(root.barScreen ? root.barScreen.name : "")
    }
}
