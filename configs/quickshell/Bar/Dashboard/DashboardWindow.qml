import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    property bool _shouldShow: DashboardState.activeScreenName === root.modelData.name || DashboardState.volPanelScreen === root.modelData.name
    // stay mapped so the heavy panel content isn't rebuilt on every hover
    // (mask limits input to the hover strips; opacity 0 draws nothing when closed)
    visible: true
    color: "transparent"
    anchors { left: true; top: true; bottom: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (panel.activeTab === 1 || panel.activeTab === 2) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    // mask limits input to hover/panel rects - rest of screen click-through
    mask: Region {
        item: hoverWrapper
        Region { item: volPanelArea }
    }

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
                Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
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

    // vertical twin of HSlider - bottom = 0%, top = 100%
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
                Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
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
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        // KEEP-OPEN zone only: collapses to 0 while the panel is closed so it
        // never catches hover (opening is solely the narrow TriggerStrip). When
        // open it hugs the panel so moving cursor into it cancels the pending hide.
        readonly property bool _open: volPanelRect._open
        width:  _open ? volPanelRect.width + 16 : 0
        height: _open ? volPanelRect.height + 16 : 0

        HoverHandler {
            onHoveredChanged: {
                // only fires when the zone is non-zero, i.e. panel already open
                if (hovered)
                    DashboardState.showVolPanel(root.modelData.name)  // cancel hide
                else
                    DashboardState.scheduleHideVolPanel()
            }
        }

        // faux shadow - three offset rects behind panel, no Qt5Compat dep
        Repeater {
            model: [
                { off: 10, op: 0.10, rad: 22 },
                { off:  6, op: 0.18, rad: 20 },
                { off:  2, op: 0.28, rad: 18 }
            ]
            delegate: Rectangle {
                required property var modelData
                x: volPanelRect.x - modelData.off
                y: volPanelRect.y + modelData.off
                width:  volPanelRect.width  + modelData.off
                height: volPanelRect.height
                radius: modelData.rad
                color: Qt.rgba(0, 0, 0, modelData.op)
                opacity: volPanelRect.opacity
                visible: opacity > 0
            }
        }

        Rectangle {
            id: volPanelRect
            // narrow vertical pill, slides in from right edge with drop-shadow
            readonly property bool _open: DashboardState.volPanelScreen === root.modelData.name
            // per-app mixer expands the pill leftwards; volPanelArea tracks our
            // width so its keep-open/input mask grows with us automatically
            property bool mixerOpen: false
            on_OpenChanged: if (!_open) mixerOpen = false
            onMixerOpenChanged: if (mixerOpen) AppVolState.refresh()
            Timer {
                interval: 2000; running: volPanelRect.mixerOpen; triggeredOnStart: true; repeat: true
                onTriggered: AppVolState.refresh()
            }
            anchors { verticalCenter: parent.verticalCenter }
            x: _open ? (parent.width - width - Space.xs) : parent.width - 4
            width: _open ? (mixerOpen ? 112 + 220 : 112) : 112
            height: 380
            radius: 16
            color: Qt.darker(Colors.background, 1.07)
            border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.35)
            border.width: 1
            opacity: _open ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Space.fast } }
            Behavior on x       { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on width   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }


            // per-app mixer, revealed on the left when mixerOpen
            AppMixer {
                id: appMixer
                anchors {
                    top: parent.top; bottom: parent.bottom; left: parent.left; right: ctlCol.left
                    topMargin: Space.md; bottomMargin: Space.md; leftMargin: Space.sm; rightMargin: Space.sm
                }
                visible: volPanelRect.mixerOpen && width > 20
                opacity: volPanelRect.mixerOpen ? 1 : 0
                clip: true
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            Column {
                id: ctlCol
                anchors {
                    top: parent.top; bottom: parent.bottom; right: parent.right
                    topMargin: Space.md; bottomMargin: Space.md; rightMargin: Space.sm
                }
                width: 96
                spacing: Space.sm

                // Header doubles as the per-app mixer toggle (tap it)
                Item {
                    width: parent.width; height: 16
                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{F0234}"
                            font.family: Type.face; font.pixelSize: Type.sm
                            color: volPanelRect.mixerOpen ? Colors.color4 : Colors.color8
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "VOL · BRT"
                            font.family: Type.face; font.pixelSize: Type.xs
                            color: volPanelRect.mixerOpen ? Colors.color4 : Colors.color8
                        }
                    }
                    MouseArea { anchors.fill: parent; anchors.margins: -4
                        onClicked: volPanelRect.mixerOpen = !volPanelRect.mixerOpen }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - Space.sm; height: 1
                    color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.25)
                }

                Row {
                    width: parent.width
                    height: parent.height - 24 - Space.sm * 3
                    spacing: Space.sm

                    // Volume column
                    Column {
                        width: (parent.width - Space.sm) / 2
                        height: parent.height
                        spacing: Space.sm

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: quickControls.muted ? "\u{F075F}"
                                : quickControls.volume > 66 ? "\u{F057E}"
                                : quickControls.volume > 33 ? "\u{F0580}" : "\u{F057F}"
                            font.family: Type.face; font.pixelSize: Type.xl
                            color: quickControls.muted ? Colors.color1 : Colors.foreground
                        }
                        VSlider {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 20
                            height: parent.height - 86
                            value: quickControls.volume
                            accent: quickControls.muted ? Colors.color1 : Colors.color4
                            onMoved: function(v) { quickControls.setVolume(v) }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: quickControls.muted ? "-" : quickControls.volume + "%"
                            font.family: Type.face; font.pixelSize: Type.xs
                            color: quickControls.muted ? Colors.color1 : Colors.color6
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 36; height: 24; radius: 12
                            color: quickControls.micMuted
                                ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.3)
                                : Qt.lighter(Colors.background, 1.5)
                            Behavior on color { ColorAnimation { duration: Space.fast } }
                            Text {
                                anchors.centerIn: parent
                                text: quickControls.micMuted ? "\u{F036D}" : "\u{F036C}"
                                font.family: Type.face; font.pixelSize: Type.md
                                color: quickControls.micMuted ? Colors.color1 : Colors.color6
                            }
                            MouseArea { anchors.fill: parent; onClicked: quickControls.toggleMicMute() }
                        }
                    }

                    // Brightness column
                    Column {
                        width: (parent.width - Space.sm) / 2
                        height: parent.height
                        spacing: Space.sm

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: quickControls.brightness > 66 ? "\u{F00DF}"
                                : quickControls.brightness > 33 ? "\u{F00DE}" : "\u{F00DD}"
                            font.family: Type.face; font.pixelSize: Type.xl
                            color: Colors.foreground
                        }
                        VSlider {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 20
                            height: parent.height - 86
                            value: quickControls.brightness
                            accent: Colors.color3
                            onMoved: function(v) { quickControls.setBrightness(v) }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: quickControls.brightness + "%"
                            font.family: Type.face; font.pixelSize: Type.xs
                            color: Colors.color6
                        }
                    }
                }
            }
        }
    }

    // Hover wrapper - wide catch zone above panel
    Item {
        id: hoverWrapper
        // catchW == panelW - strip hitW uses same formula, perfect overlap, no overflow
        x: Math.round((parent.width - catchW) / 2)
        y: 0
        width: catchW
        height: DashboardState.activeScreenName === root.modelData.name ? panel.y + panel.height + 16 : 22

        // bumped 22% → 26% to accommodate 56 px sidebar rail
        readonly property int panelW: Math.min(680, Math.max(560, Math.round(parent.width * 0.34)))
        readonly property int catchW: panelW

        HoverHandler {
            onHoveredChanged: {
                if (hovered) DashboardState.show(root.modelData.name)
                else DashboardState.scheduleHide()
            }
        }

        Rectangle {
            id: panel
            // center inside wider catch zone (catchW), wrapper no longer hugs panel
            x: Math.round((hoverWrapper.catchW - hoverWrapper.panelW) / 2)
            y: DashboardState.activeScreenName === root.modelData.name ? 8 : -14
            width: hoverWrapper.panelW; height: 620
            radius: 14
            color: Qt.darker(Colors.background, 1.07)
            border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.35)
            border.width: 1
            opacity: DashboardState.activeScreenName === root.modelData.name ? 1 : 0
            visible: opacity > 0
            // snappier entrance
            Behavior on opacity { NumberAnimation { duration: 60 } }
            Behavior on y       { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }

            property int activeTab: 0
            // per-tab accent - sweeps across panel on tab switch
            property color accent: Tab.accent(activeTab)
            Behavior on accent { ColorAnimation { duration: Space.med } }

            // ── HERO HEADER: weather left, time right ────────────────
            Item {
                id: heroHeader
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors { leftMargin: Space.lg; rightMargin: Space.lg; topMargin: Space.md }
                height: 110

                // Left half - weather (reuses wxData inside QuickControls)
                Item {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: parent.width / 2
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Space.md
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: quickControls.weatherIcon
                            font.family: Type.face; font.pixelSize: 48
                            // fixed sun-yellow regardless of active tab
                            color: Colors.color3
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: quickControls.weatherTemp
                                font.family: Type.face; font.pixelSize: 32; font.bold: true
                                color: Colors.foreground
                            }
                            Text {
                                text: quickControls.weatherDesc
                                font.family: Type.face; font.pixelSize: Type.sm
                                color: Colors.color8
                                width: Math.max(60, heroHeader.width / 2 - 80)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Right half - greeting + time + date
                Item {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: parent.width / 2
                    Column {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text {
                            id: greetingText
                            anchors.right: parent.right
                            text: {
                                const h = parseInt(Qt.formatTime(new Date(), "hh"))
                                return (h < 12 ? "GOOD MORNING" : h < 18 ? "GOOD AFTERNOON" : "GOOD EVENING")
                            }
                            font.family: Type.face; font.pixelSize: Type.xs; font.letterSpacing: 1.6
                            color: Colors.color8
                            Timer { interval: 60000; running: true; repeat: true
                                    onTriggered: {
                                        const h = parseInt(Qt.formatTime(new Date(), "hh"))
                                        greetingText.text = (h < 12 ? "GOOD MORNING" : h < 18 ? "GOOD AFTERNOON" : "GOOD EVENING")
                                    }
                            }
                        }
                        Text {
                            id: headerTime
                            anchors.right: parent.right
                            text: Qt.formatTime(new Date(), "hh:mm")
                            font.family: Type.face; font.pixelSize: 42; font.bold: true
                            color: Colors.foreground
                            Timer { interval: 10000; running: true; repeat: true
                                    onTriggered: headerTime.text = Qt.formatTime(new Date(), "hh:mm") }
                        }
                        Text {
                            anchors.right: parent.right
                            text: Qt.formatDate(new Date(), "ddd, d MMM yyyy")
                            font.family: Type.face; font.pixelSize: Type.sm
                            color: Colors.color8
                        }
                    }
                }
            }

            // Hairline gradient under hero (accent → transparent)
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: heroHeader.bottom }
                anchors { leftMargin: Space.lg; rightMargin: Space.lg; topMargin: Space.xs }
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.55) }
                    GradientStop { position: 0.6; color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.15) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // \u2500\u2500 SIDEBAR RAIL (icon-only nav, 56 px wide) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
            Item {
                id: sidebar
                anchors {
                    left: parent.left; top: heroHeader.bottom; bottom: parent.bottom
                    leftMargin: Space.sm; topMargin: Space.md; bottomMargin: Space.md
                }
                width: 56
                readonly property int slotH: Math.floor(height / 7)

                // Animated active indicator
                Rectangle {
                    width: 4; height: sidebar.slotH - 16; radius: 2
                    x: 0
                    y: panel.activeTab * sidebar.slotH + 8
                    color: panel.accent
                    Behavior on y     { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation  { duration: Space.med } }
                }

                Repeater {
                    model: 7
                    delegate: Item {
                        id: railSlot
                        required property int index
                        width: sidebar.width; height: sidebar.slotH
                        y: index * sidebar.slotH

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 10
                            color: panel.activeTab === railSlot.index
                                ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.12)
                                : railMa.containsMouse
                                    ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.08)
                                    : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: Tab.icon(railSlot.index)
                            font.family: Type.face; font.pixelSize: Type.xl
                            color: panel.activeTab === railSlot.index ? panel.accent : Colors.color8
                            Behavior on color { ColorAnimation { duration: Space.med } }
                        }
                        Rectangle {
                            visible: railSlot.index === 5 && GmailState.unreadCount > 0
                            anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
                            width: Math.max(14, badgeCount.implicitWidth + 6); height: 14; radius: 7
                            color: Tab.accent(5)
                            Text {
                                id: badgeCount
                                anchors.centerIn: parent
                                text: GmailState.unreadCount > 99 ? "99+" : GmailState.unreadCount
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 8; font.bold: true
                                color: Colors.background
                            }
                        }
                        MouseArea {
                            id: railMa
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                panel.activeTab = railSlot.index
                                if (railSlot.index === 5) GmailState.refresh()
                            }
                        }
                    }
                }
            }

            Item {
                id: contentArea
                anchors {
                    left: sidebar.right; right: parent.right
                    top: heroHeader.bottom; bottom: parent.bottom
                    leftMargin: Space.md; rightMargin: Space.md
                    topMargin: Space.md + Space.sm; bottomMargin: Space.md
                }
                clip: true

                // Warm the lazy tabs in the background (staggered) so the first
                // visit to a heavy tab is instant instead of building on open.
                Timer { interval: 1200; running: true; onTriggered: tab2._loaded = true }
                Timer { interval: 2000; running: true; onTriggered: tab4._loaded = true }
                Timer { interval: 2800; running: true; onTriggered: tab5._loaded = true }
                Timer { interval: 3600; running: true; onTriggered: tab6._loaded = true }

                // Tab 0 - Controls
                Item {
                    anchors.fill: parent
                    opacity: panel.activeTab === 0 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: Space.fast; easing.type: Easing.OutCubic } }
                    Column {
                        width: parent.width; spacing: Space.md

                        SectionHead { label: "CONTROLS"; ico: Tab.icon(0); accent: panel.accent }
                        QuickControls { id: quickControls; width: parent.width; screenName: root.modelData.name }
                    }
                }

                // Tab 1 - Media player
                Item {
                    anchors.fill: parent
                    opacity: panel.activeTab === 1 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Space.fast; easing.type: Easing.OutCubic } }

                    MediaSection {
                        id: mediaSection
                        anchors.fill: parent
                        accent: panel.accent
                    }
                }

                // Tab 2 - Wallpaper chooser (lazy-loaded)
                Item {
                    id: tab2
                    anchors.fill: parent
                    opacity: panel.activeTab === 2 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Space.fast; easing.type: Easing.OutCubic } }
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
                    Behavior on opacity { NumberAnimation { duration: Space.fast; easing.type: Easing.OutCubic } }
                    Row {
                        anchors.fill: parent; spacing: Space.md
                        Column {
                            width: (parent.width - Space.md) / 2; height: parent.height
                            spacing: Space.sm
                            SectionHead { label: "NOTIFICATIONS"; ico: ""; accent: panel.accent }
                            NotificationCenter { width: parent.width; height: parent.height - 36 - Space.sm }
                        }
                        Column {
                            width: (parent.width - Space.md) / 2; height: parent.height
                            spacing: Space.sm
                            SectionHead { label: "CLIPBOARD"; ico: ""; accent: panel.accent }
                            ClipboardHistory { width: parent.width; height: parent.height - 36 - Space.sm }
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
                    Behavior on opacity { NumberAnimation { duration: Space.fast; easing.type: Easing.OutCubic } }
                    property bool _loaded: false
                    onOpacityChanged: if (opacity > 0 && !_loaded) _loaded = true
                    Loader {
                        anchors.fill: parent
                        active: tab4._loaded
                        sourceComponent: Component {
                            Row {
                                spacing: Space.md
                                Column {
                                    width: Math.round((tab4.width - Space.md) * 0.46); height: tab4.height
                                    spacing: Space.sm
                                    SectionHead { label: "OVERVIEW"; ico: ""; accent: panel.accent }
                                    Flickable {
                                        width: parent.width; height: parent.height - 36 - Space.sm
                                        contentHeight: sysCol.implicitHeight; clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        Column { id: sysCol; width: parent.width
                                            SystemInfo { width: parent.width }
                                        }
                                    }
                                }
                                Column {
                                    width: tab4.width - Math.round((tab4.width - Space.md) * 0.46) - Space.md; height: tab4.height
                                    spacing: Space.sm
                                    SectionHead { label: "PERFORMANCE"; ico: ""; accent: panel.accent }
                                    Flickable {
                                        width: parent.width; height: parent.height - 36 - Space.sm
                                        contentHeight: perfCol.implicitHeight; clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        Column { id: perfCol; width: parent.width
                                            Performance { width: parent.width }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Tab 5 - Mail (lazy-loaded)
                Item {
                    id: tab5
                    anchors.fill: parent
                    opacity: panel.activeTab === 5 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: Space.fast; easing.type: Easing.OutCubic } }
                    property bool _loaded: false
                    onOpacityChanged: if (opacity > 0 && !_loaded) _loaded = true
                    Loader {
                        anchors.fill: parent
                        active: tab5._loaded
                        sourceComponent: Component {
                            Column {
                                spacing: Space.sm
                                SectionHead { label: "MAIL"; ico: "\uF0E0"; accent: panel.accent }
                                MailSection {
                                    width: tab5.width
                                    height: tab5.height - 36 - Space.sm
                                    accent: panel.accent
                                }
                            }
                        }
                    }
                }

                // Tab 6 - News / RSS (lazy-loaded)
                Item {
                    id: tab6
                    anchors.fill: parent
                    opacity: panel.activeTab === 6 ? 1 : 0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: Space.fast; easing.type: Easing.OutCubic } }
                    property bool _loaded: false
                    onOpacityChanged: if (opacity > 0 && !_loaded) _loaded = true
                    Loader {
                        anchors.fill: parent
                        active: tab6._loaded
                        sourceComponent: Component {
                            Column {
                                spacing: Space.sm
                                SectionHead { label: "NEWS"; ico: ""; accent: panel.accent }
                                RssSection {
                                    width: tab6.width
                                    height: tab6.height - 36 - Space.sm
                                    accent: panel.accent
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
