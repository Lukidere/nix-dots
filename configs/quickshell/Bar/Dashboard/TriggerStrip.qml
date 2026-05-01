import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    color: "transparent"
    anchors { top: true; left: true; right: true }
    implicitHeight: 6
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    // Only trigger on the rectangle above the dashboard, not the full width
    Item {
        x: Math.round((parent.width - 400) / 2)
        y: 0
        width: 400
        height: parent.height

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: DashboardState.show(root.modelData.name)
            onExited: DashboardState.scheduleHide()
        }
    }
}
