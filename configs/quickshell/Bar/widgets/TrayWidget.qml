import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../Theme"

Item {
    id: root
    width: 44
    implicitHeight: trayCol.implicitHeight

    required property var barWindow
    required property var barScreen

    Column {
        id: trayCol
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        Repeater {
            model: SystemTray.items
            delegate: Item {
                id: trayBtn
                required property SystemTrayItem modelData

                width: 44; height: 36

                Rectangle {
                    anchors.centerIn: parent
                    width: 32; height: 32; radius: 8
                    color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b,
                                   trayMa.containsMouse ? 0.15 : 0)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Image {
                    anchors.centerIn: parent
                    width: 22; height: 22
                    source: trayBtn.modelData.icon
                    sourceSize.width: 32
                    sourceSize.height: 32
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                }
                // fallback letter only when no icon source at all
                Text {
                    anchors.centerIn: parent
                    visible: !trayBtn.modelData.icon || trayBtn.modelData.icon === ""
                    text: (trayBtn.modelData.title || trayBtn.modelData.id || "?").charAt(0).toUpperCase()
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                    color: Colors.color4
                }

                MouseArea {
                    id: trayMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onEntered: {
                        const tip = trayBtn.modelData.tooltipTitle
                                 || trayBtn.modelData.title
                                 || trayBtn.modelData.id
                        if (tip) TooltipState.show(tip, mapToItem(null, 0, 0).y + height / 2, root.barScreen)
                    }
                    onExited: TooltipState.hide()

                    onClicked: function(mouse) {
                        TooltipState.hide()
                        const mapped = mapToItem(null, 0, 0)
                        const menuY  = mapped.y + height / 2

                        if (mouse.button === Qt.MiddleButton) {
                            trayBtn.modelData.secondaryActivate()
                        } else if (mouse.button === Qt.RightButton) {
                            if (trayBtn.modelData.hasMenu)
                                trayBtn.modelData.display(root.barWindow, 58, menuY)
                        } else {
                            if (trayBtn.modelData.onlyMenu) {
                                if (trayBtn.modelData.hasMenu)
                                    trayBtn.modelData.display(root.barWindow, 58, menuY)
                            } else {
                                trayBtn.modelData.activate()
                            }
                        }
                    }

                    onWheel: function(wheel) {
                        trayBtn.modelData.scroll(wheel.angleDelta.y, false)
                    }
                }
            }
        }
    }
}
