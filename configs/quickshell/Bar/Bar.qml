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

    Column {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
        spacing: 4
        Cachy {}
        Clock { barScreen: root.modelData }
        Cpu { barScreen: root.modelData }
        Ram { barScreen: root.modelData }
        Disk { barScreen: root.modelData }
    }

    Column {
        anchors { centerIn: parent }
        spacing: 4
        Mpris {}
        Workspaces {}
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
