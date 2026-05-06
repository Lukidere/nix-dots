import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var modelData
    property bool isBottom: false
    screen: modelData
    color: "transparent"
    anchors {
        top:    !root.isBottom
        bottom:  root.isBottom
        left: true; right: true
    }
    implicitHeight: 6
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    Item {
        x: Math.round((parent.width - 400) / 2)
        y: 0
        width: 400
        height: parent.height

        Timer {
            id: _showDelay; interval: 220
            onTriggered: DashboardState.showVolPanel(root.modelData.name)
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                if (root.isBottom) _showDelay.restart()
                else DashboardState.show(root.modelData.name)
            }
            onExited: {
                _showDelay.stop()
                if (root.isBottom) DashboardState.scheduleHideVolPanel()
                else DashboardState.scheduleHide()
            }
        }
    }
}
