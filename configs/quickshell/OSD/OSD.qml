import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../Theme"
import "../Notifications"
import "../Bar/Dashboard"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    visible: _windowVisible

    // ── State ────────────────────────────────────────────────────────
    property string osdType:    ""   // "volume" | "brightness"
    property int    osdValue:   0
    property bool   osdMuted:   false
    property bool   osdVisible: false
    property bool   _windowVisible: false

    // Keep window alive long enough for the 180ms fade-out to finish
    Timer { id: _closeTimer; interval: 300; onTriggered: root._windowVisible = false }
    onOsdVisibleChanged: {
        if (osdVisible) { _closeTimer.stop(); _windowVisible = true }
        else _closeTimer.restart()
    }

    // Brightness OSD removed (no bottom-of-screen popup on brightness change).

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.osdVisible = false
    }

    // ── Pill UI ──────────────────────────────────────────────────────
    Rectangle {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom; bottomMargin: 28
        }
        width: 256; height: 52; radius: 26
        color: Qt.darker(Colors.background, 1.12)
        border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.25)
        border.width: 1

        opacity: root.osdVisible ? 1 : 0
        scale:   root.osdVisible ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (root.osdType === "brightness")
                        return root.osdValue > 66 ? "\u{F00DF}" : root.osdValue > 33 ? "\u{F00DE}" : "\u{F00DD}"
                    if (root.osdMuted) return "\u{F075F}"
                    return root.osdValue > 66 ? "\u{F057E}" : root.osdValue > 33 ? "\u{F0580}" : "\u{F057F}"
                }
                font.family: "Iosevka Nerd Font"; font.pixelSize: 22
                color: root.osdType === "brightness" ? Colors.color3
                     : root.osdMuted ? Colors.color1
                     : Colors.foreground
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 148; height: 4; radius: 2
                color: Qt.lighter(Colors.background, 1.5)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.osdValue / 100))
                    height: 4; radius: 2
                    color: root.osdType === "brightness" ? Colors.color3
                         : root.osdMuted ? Colors.color1
                         : Colors.color4
                    Behavior on width { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.osdMuted ? "\u2014" : root.osdValue + "%"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                color: Colors.color6
            }
        }
    }
}
