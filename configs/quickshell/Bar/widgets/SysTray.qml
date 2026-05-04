import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../Theme"

// System tray widget — displays StatusNotifierItem apps in the bar.
// Left-click activates the item; right-click opens its context menu.
Item {
    id: root
    property var barScreen
    width: 44
    height: trayCol.implicitHeight

    Column {
        id: trayCol
        width: parent.width
        spacing: 2

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayEntry
                required property SystemTrayItem modelData

                width: 44; height: 36
                // Hide Passive items (apps that request to be invisible)
                visible: modelData.status !== SystemTrayItemStatus.Passive

                Image {
                    anchors.centerIn: parent
                    source: modelData.icon
                    width: 20; height: 20
                    smooth: true; mipmap: true
                    asynchronous: true
                    opacity: trayMa.containsMouse ? 1.0 : 0.7
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // Attention indicator dot
                Rectangle {
                    anchors { right: parent.right; top: parent.top; margins: 5 }
                    width: 5; height: 5; radius: 3
                    color: Colors.color1
                    visible: modelData.status === SystemTrayItemStatus.NeedsAttention
                }

                QsMenuHandle {
                    id: menuHandle
                    menu: modelData.menu
                }

                MouseArea {
                    id: trayMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton)
                            modelData.activate()
                        else if (mouse.button === Qt.RightButton)
                            menuHandle.show(mapToGlobal(width + 4, height / 2))
                    }
                    onEntered: TooltipState.show(
                        modelData.title,
                        mapToGlobal(0, height / 2).y,
                        root.barScreen)
                    onExited: TooltipState.hide()
                }
            }
        }
    }
}
