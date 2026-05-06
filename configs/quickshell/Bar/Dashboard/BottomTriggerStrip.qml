import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    color: "transparent"
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 6
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    Item {
        x: Math.round((parent.width - 400) / 2)
        y: 0
        width: 400
        height: parent.height

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: VolumePanelState.show(root.modelData.name)
            onExited: VolumePanelState.scheduleHide()
        }
    }
}
