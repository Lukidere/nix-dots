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
    WlrLayershell.keyboardFocus: panel.activeTab === 7 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    // Hover wrapper — sized to panel + small buffer above/around
    Item {
        id: hoverWrapper
        x: Math.round((parent.width - panelW - 20) / 2)
        y: 0
        width: panelW + 20
        height: panel.y + panel.height + 12

        readonly property int panelW: Math.min(420, Math.max(340, Math.round(parent.width * 0.22)))

        HoverHandler {
            onHoveredChanged: {
                if (hovered) DashboardState.show(root.modelData.name)
                else DashboardState.scheduleHide()
            }
        }

        Rectangle {
            id: panel
            x: 10; y: 8
            width: hoverWrapper.panelW; height: 700
            radius: 14
            color: Qt.darker(Colors.background, 1.07)
            border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.35)
            border.width: 1
            opacity: DashboardState.activeScreenName === root.modelData.name ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            property int activeTab: 0

            // ── Header: clock + date ──────────────────────────────────
            Item {
                id: headerBar
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors { leftMargin: 18; rightMargin: 18; topMargin: 14 }
                height: 36

                Text {
                    id: headerTime
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: Qt.formatTime(new Date(), "hh:mm")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 20; font.bold: true
                    color: Colors.foreground
                    Timer { interval: 10000; running: true; repeat: true
                            onTriggered: headerTime.text = Qt.formatTime(new Date(), "hh:mm") }
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: Qt.formatDate(new Date(), "ddd d MMM")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.color8
                }
            }

            // Subtle top gradient accent
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 100; radius: 14
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // ── Tab bar ──────────────────────────────────────────────
            Row {
                id: tabRow
                anchors { left: parent.left; right: parent.right; top: headerBar.bottom }
                anchors { leftMargin: 14; rightMargin: 14; topMargin: 8 }
                spacing: 4

                Repeater {
                    model: ["\uF200", "\uF001", "\uF073", "\uF03E", "\uF0A2", "\uF085", "\uF253", "\uF0AE"]
                    delegate: Rectangle {
                        required property int    index
                        required property string modelData
                        width: (tabRow.width - 28) / 8
                        height: 36; radius: 8
                        color: tabBtnMa.containsMouse && panel.activeTab !== index
                             ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.1)
                             : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 15
                            color: panel.activeTab === index ? Colors.color4 : Colors.color8
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        MouseArea {
                            id: tabBtnMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: panel.activeTab = index
                        }
                    }
                }
            }

            // Sliding active-tab underline
            Rectangle {
                property real tabW: (tabRow.width - 28) / 8
                x: tabRow.x + panel.activeTab * (tabW + 4)
                y: tabRow.y + tabRow.height - 2
                width: tabW; height: 2; radius: 1
                color: Colors.color4
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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
                    opacity: panel.activeTab === 0 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    Column {
                        width: parent.width; spacing: 10

                        Row {
                            spacing: 6
                            Rectangle { width: 3; height: 10; radius: 1.5; color: Colors.color4; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "CONTROLS"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true; color: Colors.color6 }
                        }
                        QuickControls { width: parent.width }

                        Rectangle { width: parent.width; height: 1; color: Colors.color8; opacity: 0.3 }

                        Row {
                            spacing: 6
                            Rectangle { width: 3; height: 10; radius: 1.5; color: Colors.color2; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "PERFORMANCE"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true; color: Colors.color6 }
                        }
                        Performance { width: parent.width }
                    }
                }

                // Tab 1 — Media player
                MediaSection {
                    anchors.fill: parent
                    opacity: panel.activeTab === 1 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }

                // Tab 2 — Calendar + Weather
                Item {
                    anchors.fill: parent
                    opacity: panel.activeTab === 2 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: 140 } }
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
                    opacity: panel.activeTab === 3 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }

                // Tab 4 — Notifications + Clipboard
                Item {
                    anchors.fill: parent
                    opacity: panel.activeTab === 4 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: 140 } }
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
                    opacity: panel.activeTab === 5 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Flickable {
                        anchors.fill: parent
                        contentHeight: sysCol.implicitHeight
                        clip: true

                        Column {
                            id: sysCol
                            width: parent.width; spacing: 10

                            Row {
                                spacing: 6
                                Rectangle { width: 3; height: 10; radius: 1.5; color: Colors.color3; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "SYSTEM"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true; color: Colors.color6 }
                            }
                            SystemInfo { width: parent.width }

                            Rectangle { width: parent.width; height: 1; color: Colors.color8; opacity: 0.3 }

                            NetworkPanel { width: parent.width }

                            Rectangle { width: parent.width; height: 1; color: Colors.color8; opacity: 0.3 }

                            BluetoothPanel { width: parent.width }
                        }
                    }
                }

                // Tab 6 — Pomodoro timer
                Item {
                    anchors.fill: parent
                    opacity: panel.activeTab === 6 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Column {
                        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 20 }
                        spacing: 10

                        Row {
                            spacing: 6
                            Rectangle { width: 3; height: 10; radius: 1.5; color: Colors.color1; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "POMODORO"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true; color: Colors.color6 }
                        }
                        PomodoroTimer { width: parent.width }
                    }
                }

                // Tab 7 — Todo list
                Item {
                    anchors.fill: parent
                    opacity: panel.activeTab === 7 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Column {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        spacing: 10

                        Row {
                            spacing: 6
                            Rectangle { width: 3; height: 10; radius: 1.5; color: Colors.color5; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "TASKS"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true; color: Colors.color6 }
                        }

                        Flickable {
                            width: parent.width
                            height: contentArea.height - 24
                            contentHeight: todoInner.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            TodoList {
                                id: todoInner
                                width: parent.width
                            }
                        }
                    }
                }
            }
        }
    }
}
