import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../Theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    visible: PowerState.open && PowerState.screenName === modelData.name
    color: "transparent"
    anchors { left: true; top: true; bottom: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: PowerState.close()
    }

    Rectangle {
        x: 60
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: 180
        height: menuCol.implicitHeight + 20
        radius: 12
        color: Qt.darker(Colors.background, 1.1)
        border.color: Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.25)
        border.width: 1

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Column {
            id: menuCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 2
            topPadding: 4

            component PowerRow: Rectangle {
                id: pr
                property string icon: ""
                property string label: ""
                property string cmd: ""
                property color  iconClr: Colors.foreground

                width: parent.width; height: 38; radius: 8
                color: rowMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: pr.icon
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                        color: pr.iconClr
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: pr.label
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                        color: Colors.foreground
                    }
                }
                MouseArea {
                    id: rowMa; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        PowerState.close()
                        actionProc.command = ["sh", "-c", pr.cmd]
                        actionProc.running = false; actionProc.running = true
                    }
                }
            }

            PowerRow { icon: "\uF023"; label: "Lock";     cmd: "gtklock -d" }
            PowerRow { icon: "\uF186"; label: "Sleep";    cmd: "systemctl suspend" }
            PowerRow { icon: "\uF08B"; label: "Logout";   cmd: "niri msg action quit" }
            Rectangle { width: parent.width; height: 1; color: Colors.color8; opacity: 0.3 }
            PowerRow { icon: "\uF021"; label: "Reboot";   cmd: "systemctl reboot";  iconClr: Colors.color3 }
            PowerRow { icon: "\uF011"; label: "Shutdown"; cmd: "systemctl poweroff"; iconClr: Colors.color1 }
        }
    }

    Process { id: actionProc; running: false }
}
