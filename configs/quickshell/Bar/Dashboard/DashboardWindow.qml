import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    visible: DashboardState.activeScreenName === root.modelData.name || DashboardState.volPanelScreen === root.modelData.name
    color: "transparent"
    anchors { left: true; top: true; bottom: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: panel.activeTab === 5 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    // ── Horizontal slider (used by volume panel) ──────────────────────────
    component HSlider: Item {
        id: hs
        height: 20
        signal moved(int v)
        property int   value:  0
        property color accent: Colors.color4

        Rectangle {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 4; radius: 2
            color: Qt.lighter(Colors.background, 1.5)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, hs.value / 100))
                height: 4; radius: 2; color: hs.accent
                Behavior on width { NumberAnimation { duration: 80 } }
            }
        }
        Rectangle {
            x: Math.max(0, (hs.width - 12) * Math.max(0, Math.min(1, hs.value / 100)))
            y: 4; width: 12; height: 12; radius: 6
            color: hs.accent
        }
        MouseArea {
            anchors.fill: parent
            function calc(mx) { return Math.max(0, Math.min(100, Math.round(mx / width * 100))) }
            onPressed:         hs.moved(calc(mouseX))
            onPositionChanged: if (pressed) hs.moved(calc(mouseX))
        }
    }

    // ── Bottom volume/brightness panel ────────────────────────────────────
    Item {
        id: volPanelArea
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        width: Math.min(420, Math.max(340, Math.round(parent.width * 0.22))) + 40
        height: volPanelRect.height + 20

        HoverHandler {
            onHoveredChanged: {
                if (hovered && DashboardState.activeScreenName !== root.modelData.name)
                    DashboardState.showVolPanel(root.modelData.name)
                else if (!hovered)
                    DashboardState.scheduleHideVolPanel()
            }
        }

        Rectangle {
            id: volPanelRect
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
            width: Math.min(420, Math.max(340, Math.round(parent.width * 0.22)))
            height: 124
            radius: 14
            color: Qt.darker(Colors.background, 1.07)
            border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.35)
            border.width: 1
            opacity: DashboardState.volPanelScreen === root.modelData.name ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Column {
                anchors {
                    left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                    leftMargin: 16; rightMargin: 16
                }
                spacing: 14

                // Volume
                Column {
                    width: parent.width; spacing: 6
                    Item {
                        width: parent.width; height: 18
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: (quickControls.muted ? "\u{F075F}"
                                : quickControls.volume > 66 ? "\u{F057E}"
                                : quickControls.volume > 33 ? "\u{F0580}" : "\u{F057F}") + "  Volume"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                            color: quickControls.muted ? Colors.color1 : Colors.foreground
                        }
                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: quickControls.muted ? "MUTED" : quickControls.volume + "%"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                color: quickControls.muted ? Colors.color1 : Colors.color6
                            }
                            // Mic mute button — only affects microphone
                            Rectangle {
                                width: 24; height: 16; radius: 8
                                color: quickControls.micMuted
                                    ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.3)
                                    : Qt.lighter(Colors.background, 1.5)
                                Text {
                                    anchors.centerIn: parent
                                    text: quickControls.micMuted ? "\u{F036D}" : "\u{F036C}"
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                                    color: quickControls.micMuted ? Colors.color1 : Colors.color6
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: quickControls.toggleMicMute()
                                }
                            }
                        }
                    }
                    HSlider {
                        width: parent.width; value: quickControls.volume
                        onMoved: function(v) { quickControls.setVolume(v) }
                    }
                }

                // Brightness
                Column {
                    width: parent.width; spacing: 6
                    Item {
                        width: parent.width; height: 18
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: (quickControls.brightness > 66 ? "\u{F00DF}"
                                : quickControls.brightness > 33 ? "\u{F00DE}" : "\u{F00DD}") + "  Brightness"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                            color: Colors.foreground
                        }
                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: quickControls.brightness + "%"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                            color: Colors.color6
                        }
                    }
                    HSlider {
                        width: parent.width; value: quickControls.brightness
                        accent: Colors.color3
                        onMoved: function(v) { quickControls.setBrightness(v) }
                    }
                }
            }
        }
    }

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
            x: 10
            y: DashboardState.activeScreenName === root.modelData.name ? 8 : -14
            width: hoverWrapper.panelW; height: 700
            radius: 14
            color: Qt.darker(Colors.background, 1.07)
            border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.35)
            border.width: 1
            opacity: DashboardState.activeScreenName === root.modelData.name ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            property int activeTab: 0

            // ── Header: greeting + clock + date + power ───────────────
            Item {
                id: headerBar
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors { leftMargin: 18; rightMargin: 18; topMargin: 14 }
                height: 56

                // Greeting (top-left)
                Text {
                    id: greetingText
                    anchors { left: parent.left; top: parent.top }
                    text: {
                        const h = parseInt(Qt.formatTime(new Date(), "hh"))
                        return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
                    }
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.color8
                    Timer { interval: 60000; running: true; repeat: true
                            onTriggered: {
                                const h = parseInt(Qt.formatTime(new Date(), "hh"))
                                greetingText.text = h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
                            }
                    }
                }

                // Large time (bottom-left)
                Text {
                    id: headerTime
                    anchors { left: parent.left; bottom: parent.bottom }
                    text: Qt.formatTime(new Date(), "hh:mm")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 24; font.bold: true
                    color: Colors.foreground
                    Timer { interval: 10000; running: true; repeat: true
                            onTriggered: headerTime.text = Qt.formatTime(new Date(), "hh:mm") }
                }

                // Date (bottom-right)
                Text {
                    anchors { right: parent.right; bottom: parent.bottom }
                    text: Qt.formatDate(new Date(), "ddd, d MMM yyyy")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
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
                    model: ["\uF200", "\uF001", "\uF03E", "\uF0A2", "\uF085", "\uF253"]
                    delegate: Rectangle {
                        required property int    index
                        required property string modelData
                        width: (tabRow.width - 20) / 6
                        height: 44; radius: 8
                        color: tabBtnMa.containsMouse && panel.activeTab !== index
                             ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.1)
                             : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                                color: panel.activeTab === parent.parent.index ? Colors.color4 : Colors.color8
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (["ctrl","media","wall","notif","sys","pomo"])[parent.parent.index]
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 7
                                color: panel.activeTab === parent.parent.index ? Colors.color4 : Colors.color6
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
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
                property real tabW: (tabRow.width - 20) / 6
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

                // Tab 0 — Controls
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
                        QuickControls { id: quickControls; width: parent.width }
                    }
                }

                // Tab 1 — Media player
                Item {
                    anchors.fill: parent
                    opacity: panel.activeTab === 1 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    // Ambient album-art tint behind media content
                    Image {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 110
                        source: mediaSection.artUrl
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0.13
                        smooth: true; mipmap: true; asynchronous: true
                        visible: status === Image.Ready
                        // Fade to panel background at the bottom
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: parent.height
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.darker(Colors.background, 1.07) }
                            }
                        }
                    }

                    MediaSection {
                        id: mediaSection
                        anchors.fill: parent
                    }
                }

                // Tab 2 — Wallpaper chooser
                WallpaperSection {
                    anchors.fill: parent
                    opacity: panel.activeTab === 2 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }

                // Tab 3 — Notifications + Clipboard
                Item {
                    anchors.fill: parent
                    opacity: panel.activeTab === 3 ? 1 : 0
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

                // Tab 4 — System Info + Network + Bluetooth
                Item {
                    anchors.fill: parent
                    opacity: panel.activeTab === 4 ? 1 : 0
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

                            Row {
                                spacing: 6
                                Rectangle { width: 3; height: 10; radius: 1.5; color: Colors.color2; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "PERFORMANCE"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true; color: Colors.color6 }
                            }
                            Performance { width: parent.width }
                        }
                    }
                }

                // Tab 5 — Pomodoro + Tasks
                Item {
                    anchors.fill: parent
                    opacity: panel.activeTab === 5 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Flickable {
                        anchors.fill: parent
                        contentHeight: pomoTaskCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: pomoTaskCol
                            width: parent.width; spacing: 10

                            Row {
                                spacing: 6
                                Rectangle { width: 3; height: 10; radius: 1.5; color: Colors.color1; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "POMODORO"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true; color: Colors.color6 }
                            }
                            PomodoroTimer { width: parent.width }

                            Rectangle { width: parent.width; height: 1; color: Colors.color8; opacity: 0.3 }

                            Row {
                                spacing: 6
                                Rectangle { width: 3; height: 10; radius: 1.5; color: Colors.color5; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "TASKS"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true; color: Colors.color6 }
                            }
                            TodoList { width: parent.width }
                        }
                    }
                }
            }
        }
    }
}
