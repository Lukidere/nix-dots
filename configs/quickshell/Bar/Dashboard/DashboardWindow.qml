import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    property bool _shouldShow: DashboardState.activeScreenName === root.modelData.name || DashboardState.volPanelScreen === root.modelData.name
    visible: _shouldShow || panel.opacity > 0 || volPanelRect.opacity > 0
    color: "transparent"
    anchors { left: true; top: true; bottom: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: panel.activeTab === 5 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

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

    // ponytail: vertical twin of HSlider - bottom = 0%, top = 100%
    component VSlider: Item {
        id: vs
        width: 20
        signal moved(int v)
        property int   value:  0
        property color accent: Colors.color4
        readonly property real frac: Math.max(0, Math.min(1, vs.value / 100))

        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: 4; radius: 2
            color: Qt.lighter(Colors.background, 1.5)
            Rectangle {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                width: 4; radius: 2
                height: parent.height * vs.frac
                color: vs.accent
                Behavior on height { NumberAnimation { duration: 80 } }
            }
        }
        Rectangle {
            x: (vs.width - 12) / 2
            y: Math.max(0, (vs.height - 12) * (1 - vs.frac))
            width: 12; height: 12; radius: 6
            color: vs.accent
        }
        MouseArea {
            anchors.fill: parent
            function calc(my) { return Math.max(0, Math.min(100, Math.round((1 - my / height) * 100))) }
            onPressed:         vs.moved(calc(mouseY))
            onPositionChanged: if (pressed) vs.moved(calc(mouseY))
        }
    }

    Item {
        id: volPanelArea
        // ponytail: wide hover catch zone - panel ~108 wide, zone ~180
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: volPanelRect.width + 80
        height: volPanelRect.height + 60

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
            // ponytail: narrow vertical pill, slides in from right edge
            readonly property bool _open: DashboardState.volPanelScreen === root.modelData.name
            anchors { verticalCenter: parent.verticalCenter }
            x: _open ? (parent.width - width) : parent.width - 4
            width: 108
            height: 360
            radius: 14
            color: Qt.darker(Colors.background, 1.07)
            border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.35)
            border.width: 1
            opacity: _open ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on x       { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Row {
                anchors {
                    top: parent.top; bottom: parent.bottom; left: parent.left; right: parent.right
                    topMargin: 14; bottomMargin: 14; leftMargin: 10; rightMargin: 10
                }
                spacing: 8

                // Volume column
                Column {
                    width: (parent.width - 8) / 2
                    height: parent.height
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: quickControls.muted ? "\u{F075F}"
                            : quickControls.volume > 66 ? "\u{F057E}"
                            : quickControls.volume > 33 ? "\u{F0580}" : "\u{F057F}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                        color: quickControls.muted ? Colors.color1 : Colors.foreground
                    }
                    VSlider {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 20
                        height: parent.height - 78
                        value: quickControls.volume
                        accent: quickControls.muted ? Colors.color1 : Colors.color4
                        onMoved: function(v) { quickControls.setVolume(v) }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: quickControls.muted ? "-" : quickControls.volume + "%"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                        color: quickControls.muted ? Colors.color1 : Colors.color6
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 28; height: 18; radius: 9
                        color: quickControls.micMuted
                            ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.3)
                            : Qt.lighter(Colors.background, 1.5)
                        Text {
                            anchors.centerIn: parent
                            text: quickControls.micMuted ? "\u{F036D}" : "\u{F036C}"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                            color: quickControls.micMuted ? Colors.color1 : Colors.color6
                        }
                        MouseArea { anchors.fill: parent; onClicked: quickControls.toggleMicMute() }
                    }
                }

                // Brightness column
                Column {
                    width: (parent.width - 8) / 2
                    height: parent.height
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: quickControls.brightness > 66 ? "\u{F00DF}"
                            : quickControls.brightness > 33 ? "\u{F00DE}" : "\u{F00DD}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                        color: Colors.foreground
                    }
                    VSlider {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 20
                        height: parent.height - 78
                        value: quickControls.brightness
                        accent: Colors.color3
                        onMoved: function(v) { quickControls.setBrightness(v) }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: quickControls.brightness + "%"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                        color: Colors.color6
                    }
                }
            }
        }
    }

    // Hover wrapper - wide catch zone above panel
    Item {
        id: hoverWrapper
        // ponytail: wider buffer (40 px) so mouse catches easily near top edge
        x: Math.round((parent.width - panelW - 80) / 2)
        y: 0
        width: panelW + 80
        height: DashboardState.activeScreenName === root.modelData.name ? panel.y + panel.height + 16 : 22

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
            // ponytail: snappier entrance - 120/140 vs 180/200
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on y       { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            property int activeTab: 0

            Item {
                id: headerBar
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors { leftMargin: 18; rightMargin: 18; topMargin: 14 }
                height: 56

                // Greeting (top-left) with user icon
                Row {
                    anchors { left: parent.left; top: parent.top }
                    spacing: 5
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{F0004}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                        color: Colors.color4
                    }
                    Text {
                        id: greetingText
                        anchors.verticalCenter: parent.verticalCenter
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
                }

                // Large time (bottom-left)
                Text {
                    id: headerTime
                    anchors { left: parent.left; bottom: parent.bottom }
                    text: Qt.formatTime(new Date(), "hh:mm")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 28; font.bold: true
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

            // Accent underline below header
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: headerBar.bottom }
                anchors { leftMargin: 18; rightMargin: 18; topMargin: 6 }
                height: 1
                color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.35)
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

            Item {
                id: contentArea
                anchors {
                    left: parent.left; right: parent.right
                    top: tabRow.bottom; bottom: parent.bottom
                    leftMargin: 14; rightMargin: 14
                    topMargin: 10; bottomMargin: 14
                }
                clip: true

                // Tab 0 - Controls
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

                // Tab 1 - Media player
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

                // Tab 2 - Wallpaper chooser (lazy-loaded)
                Item {
                    id: tab2
                    anchors.fill: parent
                    opacity: panel.activeTab === 2 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    property bool _loaded: false
                    onOpacityChanged: if (opacity > 0 && !_loaded) _loaded = true
                    Loader {
                        anchors.fill: parent
                        active: tab2._loaded
                        sourceComponent: Component { WallpaperSection { anchors.fill: parent } }
                    }
                }

                // Tab 3 - Notifications + Clipboard
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

                // Tab 4 - System Info + Performance (lazy-loaded)
                Item {
                    id: tab4
                    anchors.fill: parent
                    opacity: panel.activeTab === 4 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    property bool _loaded: false
                    onOpacityChanged: if (opacity > 0 && !_loaded) _loaded = true
                    Loader {
                        anchors.fill: parent
                        active: tab4._loaded
                        sourceComponent: Component {
                            Flickable {
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
                    }
                }

                // Tab 5 - Pomodoro + Tasks (lazy-loaded)
                Item {
                    id: tab5
                    anchors.fill: parent
                    opacity: panel.activeTab === 5 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    property bool _loaded: false
                    onOpacityChanged: if (opacity > 0 && !_loaded) _loaded = true
                    Loader {
                        anchors.fill: parent
                        active: tab5._loaded
                        sourceComponent: Component {
                            Flickable {
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
    }
}
