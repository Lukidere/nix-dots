import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    visible: root.items.length > 0
    color: "transparent"
    anchors { right: true; top: true }
    implicitWidth: 340
    implicitHeight: notifCol.implicitHeight + 20
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    // Only show notifications that were spawned while this screen was focused
    property var items: []

    Connections {
        target: NotifState
        function onChanged() {
            root.items = NotifState.items.filter(
                function(i) { return i.screen === root.modelData.name }
            )
        }
    }

    Column {
        id: notifCol
        anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 10 }
        spacing: 6

        Repeater {
            model: root.items
            delegate: NotifItem {
                notifId:   modelData.id
                appName:   modelData.appName
                appIcon:   modelData.appIcon
                summary:   modelData.summary
                body:      modelData.body
                timeout:   modelData.timeout
                createdAt: modelData.createdAt || Date.now()
            }
        }
    }
}
