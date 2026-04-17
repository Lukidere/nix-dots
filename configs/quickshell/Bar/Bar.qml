import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme"
import "./widgets"

PanelWindow {
    id: root

    // 1. Odbieramy dane o konkretnym monitorze od komponentu Variants
    required property var modelData

    // 2. Przypisujemy ten pasek do tego konkretnego ekranu
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
        Clock {}
        Cpu {}
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
        Network {}
        Bluetooth {}
        AudioGroup {}
        BrightnessGroup {}
        Battery {}
    }
}
