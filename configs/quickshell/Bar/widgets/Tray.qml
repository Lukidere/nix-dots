import QtQuick
import Quickshell.Services.SystemTray
import "../../Theme"

Item {
    id: root
    width: 44
    property bool expanded: hoverArea.containsMouse
    height: trayRepeater.count === 0 ? 0 : (expanded ? trayCol.implicitHeight + 24 : 24)
    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }
    clip: true

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
    }

    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 4 }
        text: "\u203A"
        font.pixelSize: 18
        color: Colors.color8
        opacity: root.expanded ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Column {
        id: trayCol
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        spacing: 4
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Repeater {
            id: trayRepeater
            model: SystemTray.items
            delegate: Item {
                width: 44; height: 44
                Image {
                    anchors.centerIn: parent; width: 22; height: 22
                    source: modelData.icon; smooth: true
                    sourceSize: Qt.size(22, 22)
                    opacity: ma.containsMouse ? 1.0 : 0.75
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: event => {
                        if (event.button === Qt.LeftButton) modelData.activate()
                        else modelData.secondaryActivate()
                    }
                }
            }
        }
    }
}
