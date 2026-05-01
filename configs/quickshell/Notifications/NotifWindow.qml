import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    visible: NotifState.items.length > 0 && modelData.name === NotifState.focusedScreen
    color: "transparent"
    anchors { right: true; top: true }
    implicitWidth: 340
    implicitHeight: notifCol.implicitHeight + 20
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    property var items: []

    Connections {
        target: NotifState
        function onChanged() { root.items = NotifState.items.slice() }
    }

    Column {
        id: notifCol
        anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 10 }
        spacing: 6

        Repeater {
            model: root.items
            delegate: NotifItem {
                notifId:  modelData.id
                appName:  modelData.appName
                appIcon:  modelData.appIcon
                summary:  modelData.summary
                body:     modelData.body
                timeout:  modelData.timeout
            }
        }
    }
}
