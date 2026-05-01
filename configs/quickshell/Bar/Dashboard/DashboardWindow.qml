import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    visible: DashboardState.activeScreenName === root.modelData.name
    color: "transparent"
    anchors { left: true; top: true; bottom: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    // Hover wrapper — sized to panel + small buffer above/around
    Item {
        id: hoverWrapper
        x: Math.round((parent.width - panelW - 20) / 2)
        y: 0
        width: panelW + 20
        height: panel.y + panel.height + 12

        readonly property int panelW: 380

        HoverHandler {
            onHoveredChanged: {
                if (hovered) DashboardState.show(root.modelData.name)
                else DashboardState.scheduleHide()
            }
        }

        Rectangle {
            id: panel
            x: 10; y: 8
            width: hoverWrapper.panelW; height: 640
            radius: 14
            color: Qt.darker(Colors.background, 1.07)
            border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.3)
            border.width: 1
            opacity: DashboardState.activeScreenName === root.modelData.name ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            property int activeTab: 0

            // ── Tab bar ──────────────────────────────────────────────
            Row {
                id: tabRow
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors { leftMargin: 14; rightMargin: 14; topMargin: 12 }
                spacing: 4

                Repeater {
                    model: ["\uF200", "\uF001", "\uF073", "\uF03E", "\uF0A2", "\uF085"]
                    delegate: Rectangle {
                        required property int    index
                        required property string modelData
                        width: (tabRow.width - 20) / 6
                        height: 36; radius: 8
                        color: panel.activeTab === index ? Colors.color4
                             : (tabBtnMa.containsMouse ? Qt.lighter(Colors.background, 1.5)
                                                       : Qt.lighter(Colors.background, 1.3))
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 15
                            color: panel.activeTab === index ? Colors.background : Colors.foreground
                        }
                        MouseArea {
                            id: tabBtnMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: panel.activeTab = index
                        }
                    }
                }
            }

            // ── Content area ─────────────────────────────────────────
            Item {
                id: contentArea
                anchors {
                    left: parent.left; right: parent.right
                    top: tabRow.bottom; bottom: parent.bottom
                    leftMargin: 14; rightMargin: 14
                    topMargin: 10; bottomMargin: 14
                }
                clip: true

                // Tab 0 — Controls + Performance
                Item {
                    anchors.fill: parent
                    visible: panel.activeTab === 0
                    clip: true
                    Column {
                        width: parent.width; spacing: 10

                        Text {
                            text: "CONTROLS"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                            color: Colors.color6
                        }
                        QuickControls { width: parent.width }

                        Rectangle { width: parent.width; height: 1; color: Colors.color8; opacity: 0.3 }

                        Text {
                            text: "PERFORMANCE"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                            color: Colors.color6
                        }
                        Performance { width: parent.width }
                    }
                }

                // Tab 1 — Media player
                MediaSection {
                    anchors.fill: parent
                    visible: panel.activeTab === 1
                }

                // Tab 2 — Calendar + Weather
                Item {
                    anchors.fill: parent
                    visible: panel.activeTab === 2
                    clip: true
                    Column {
                        width: parent.width; spacing: 12

                        WeatherWidget { width: parent.width }
                        Rectangle { width: parent.width; height: 1; color: Colors.color8; opacity: 0.3 }
                        CalendarWidget { width: parent.width }
                    }
                }

                // Tab 3 — Wallpaper chooser
                WallpaperSection {
                    anchors.fill: parent
                    visible: panel.activeTab === 3
                }

                // Tab 4 — Notifications + Clipboard
                Item {
                    anchors.fill: parent
                    visible: panel.activeTab === 4
                    clip: true
                    Column {
                        width: parent.width; spacing: 10

                        NotificationCenter {
                            width: parent.width
                            height: Math.round(contentArea.height * 0.55)
                        }

                        Rectangle { width: parent.width; height: 1; color: Colors.color8; opacity: 0.3 }

                        ClipboardHistory {
                            width: parent.width
                            height: Math.round(contentArea.height * 0.35)
                        }
                    }
                }

                // Tab 5 — System Info + Network + Bluetooth
                Item {
                    anchors.fill: parent
                    visible: panel.activeTab === 5
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        contentHeight: sysCol.implicitHeight
                        clip: true

                        Column {
                            id: sysCol
                            width: parent.width; spacing: 10

                            Text {
                                text: "SYSTEM"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                                color: Colors.color6
                            }
                            SystemInfo { width: parent.width }

                            Rectangle { width: parent.width; height: 1; color: Colors.color8; opacity: 0.3 }

                            NetworkPanel { width: parent.width }

                            Rectangle { width: parent.width; height: 1; color: Colors.color8; opacity: 0.3 }

                            BluetoothPanel { width: parent.width }
                        }
                    }
                }
            }
        }
    }
}
