import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    visible: TooltipState.visible && TooltipState.screen === modelData
    color: "transparent"
    anchors { left: true; top: true; bottom: true }
    implicitWidth: 520
    margins.left: 56
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    Rectangle {
        x: 6
        y: Math.max(4, Math.min(parent.height - height - 4, TooltipState.screenY - height / 2))
        width: tipText.implicitWidth + 20; height: 28; radius: 6
        color: Qt.darker(Colors.background, 1.15)
        border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.4)
        border.width: 1

        Text {
            id: tipText
            anchors.centerIn: parent
            text: TooltipState.text
            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
            color: Colors.foreground
        }

        opacity: TooltipState.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
