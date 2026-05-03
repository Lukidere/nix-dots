import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"
import "./widgets"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors { left: true; top: true; bottom: true }
    implicitWidth: 56
    exclusiveZone: width

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: Colors.background

    Item {
        id: barContent
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: startupAnim.start()
        NumberAnimation { id: startupAnim; target: barContent; property: "opacity"; from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }

        Column {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
            spacing: 4
            Cachy {}
            Clock { barScreen: root.modelData }
            Cpu { barScreen: root.modelData }
            Ram { barScreen: root.modelData }
            Disk { barScreen: root.modelData }
        }

        Rectangle {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            anchors.verticalCenterOffset: -54
            width: 20; height: 1; color: Colors.color8; opacity: 0.25
        }
        Rectangle {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            anchors.verticalCenterOffset: 54
            width: 20; height: 1; color: Colors.color8; opacity: 0.25
        }

        Column {
            anchors { centerIn: parent }
            spacing: 4
            Mpris {}
            Workspaces {}
            ActiveWindow { barScreen: root.modelData }
            Privacy {}
        }

        Column {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 }
            spacing: 4
            AudioGroup {}
            BrightnessGroup {}
            Battery { barScreen: root.modelData }
            PowerButton { barScreen: root.modelData }
        }
    }
}
