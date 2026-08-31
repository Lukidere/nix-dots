import QtQuick
import QtCore
import Quickshell.Io
import "../../Theme"
import "../../Notifications"

// GUI for the Settings tab. Renders grouped controls that drive SettingsState
// (runtime commands + JSON persistence). No config file is written directly.
Item {
    id: root
    property color accent: Colors.color4
    readonly property var st: SettingsState

    readonly property string _home: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")

    // ── reusable bits ────────────────────────────────────────────────
    component GroupCard: Rectangle {
        default property alias content: inner.data
        property string title: ""
        width: rows.width
        implicitHeight: inner.implicitHeight + head.implicitHeight + Space.md * 2 + Space.sm
        radius: 10
        color: Qt.lighter(Colors.background, 1.18)
        Column {
            anchors { fill: parent; margins: Space.md }
            spacing: Space.sm
            Text {
                id: head
                text: parent.parent.title
                font.family: Type.face; font.pixelSize: Type.xs; font.bold: true
                color: Colors.color8
            }
            Column { id: inner; width: parent.width; spacing: Space.sm }
        }
    }

    component Toggle: Rectangle {
        property bool on: false
        signal toggled()
        width: 40; height: 22; radius: 11
        color: on ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.9)
                  : Qt.lighter(Colors.background, 1.6)
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 16; height: 16; radius: 8; y: 3
            x: parent.on ? parent.width - width - 3 : 3
            color: Colors.foreground
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; onClicked: parent.toggled() }
    }

    component ToggleRow: Item {
        property string label: ""
        property bool on: false
        signal toggled()
        width: parent ? parent.width : 0
        height: 26
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: parent.label
            font.family: Type.face; font.pixelSize: Type.sm; color: Colors.foreground
        }
        Toggle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            on: parent.on
            onToggled: parent.toggled()
        }
    }

    // horizontal slider matching the app-mixer/VSlider handle feel
    component HSlider: Item {
        property real from: 0
        property real to: 100
        property real value: 0
        signal moved(real v)
        readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
        readonly property bool active: sma.containsMouse || sma.pressed
        width: parent ? parent.width : 0
        height: 16
        Rectangle {
            id: trk
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: parent.active ? 7 : 4; radius: height / 2
            color: Qt.lighter(Colors.background, 1.6)
            Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: parent.width * parent.parent.frac; height: parent.height; radius: parent.radius
                color: parent.parent.active ? Qt.lighter(root.accent, 1.15) : root.accent
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
        Rectangle {
            readonly property int sz: parent.active ? 14 : 11
            width: sz; height: sz; radius: sz / 2
            y: (parent.height - sz) / 2
            x: Math.max(0, Math.min(parent.width - sz, parent.width * parent.frac - sz / 2))
            color: parent.active ? Qt.lighter(root.accent, 1.15) : root.accent
            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: sma
            anchors.fill: parent; hoverEnabled: true; preventStealing: true
            function calc(mx) {
                var f = Math.max(0, Math.min(1, mx / width))
                return parent.from + f * (parent.to - parent.from)
            }
            onPressed:         e => parent.moved(calc(e.x))
            onPositionChanged: e => { if (pressed) parent.moved(calc(e.x)) }
        }
    }

    component Stepper: Row {
        property int value: 0
        property int from: 0
        property int to: 23
        signal changed(int v)
        spacing: Space.sm
        Rectangle {
            width: 22; height: 22; radius: 6; color: Qt.lighter(Colors.background, 1.6)
            Text { anchors.centerIn: parent; text: "−"; font.family: Type.face; font.pixelSize: Type.md; color: Colors.foreground }
            MouseArea { anchors.fill: parent; onClicked: { var v = Math.max(parent.parent.from, parent.parent.value - 1); parent.parent.changed(v) } }
        }
        Text {
            width: 44; horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            text: String(parent.value).padStart(2, "0") + ":00"
            font.family: Type.face; font.pixelSize: Type.sm; color: Colors.foreground
        }
        Rectangle {
            width: 22; height: 22; radius: 6; color: Qt.lighter(Colors.background, 1.6)
            Text { anchors.centerIn: parent; text: "+"; font.family: Type.face; font.pixelSize: Type.md; color: Colors.foreground }
            MouseArea { anchors.fill: parent; onClicked: { var v = Math.min(parent.parent.to, parent.parent.value + 1); parent.parent.changed(v) } }
        }
    }

    // ── keybind cheatsheet source ────────────────────────────────────
    property var keybinds: []
    property string kbFilter: ""
    readonly property var filteredBinds: kbFilter === "" ? keybinds
        : keybinds.filter(function (b) { return (b.key + " " + b.action).toLowerCase().indexOf(kbFilter.toLowerCase()) >= 0 })
    property FileView _kdl: FileView {
        path: root._home + "/.config/niri/config.kdl"
        onLoaded: root._parseBinds(root._kdl.text())
    }
    function _parseBinds(txt) {
        var out = []
        var inBinds = false
        var lines = txt.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i]
            if (!inBinds) { if (/^\s*binds\s*\{/.test(l)) inBinds = true; continue }
            if (/^\s*\}/.test(l)) break
            var m = l.match(/^\s*([A-Za-z0-9+]+)\s*\{\s*(.+?)\s*;?\s*\}/)
            if (m) out.push({ key: m[1], action: m[2].replace(/;\s*$/, "").trim() })
        }
        root.keybinds = out
    }

    // ── layout ───────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        contentHeight: rows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: rows
            width: root.width
            spacing: Space.sm

            // AUDIO — default sink
            GroupCard {
                title: "AUDIO OUTPUT"
                Repeater {
                    model: root.st.sinks
                    delegate: Item {
                        required property var modelData
                        width: parent.width; height: 26
                        Rectangle {
                            anchors.fill: parent; radius: 6
                            color: modelData.active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15) : "transparent"
                        }
                        Text {
                            anchors { left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: (modelData.active ? "✔  " : "") + modelData.name
                            font.family: Type.face; font.pixelSize: Type.sm
                            color: modelData.active ? root.accent : Colors.foreground
                            elide: Text.ElideRight
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.st.setDefaultSink(modelData.id) }
                    }
                }
                Text {
                    visible: root.st.sinks.length === 0
                    text: "No sinks"; font.family: Type.face; font.pixelSize: Type.xs; color: Colors.color8
                }
            }

            // NIGHT LIGHT — temperature + schedule
            GroupCard {
                title: "NIGHT LIGHT"
                Text {
                    text: "Temperature  " + root.st.nightTemp + "K"
                    font.family: Type.face; font.pixelSize: Type.sm; color: Colors.foreground
                }
                HSlider {
                    from: 2500; to: 6500; value: root.st.nightTemp
                    onMoved: v => root.st.setNightTemp(Math.round(v / 100) * 100)
                }
                Item {
                    width: parent.width; height: 24
                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "Auto on"; font.family: Type.face; font.pixelSize: Type.sm; color: Colors.foreground
                    }
                    Stepper {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        from: 0; to: 23; value: root.st.nightStart
                        onChanged: v => root.st.setNightSchedule(v, root.st.nightEnd)
                    }
                }
                Item {
                    width: parent.width; height: 24
                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "Auto off"; font.family: Type.face; font.pixelSize: Type.sm; color: Colors.foreground
                    }
                    Stepper {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        from: 0; to: 23; value: root.st.nightEnd
                        onChanged: v => root.st.setNightSchedule(root.st.nightStart, v)
                    }
                }
            }

            // APPEARANCE — wallust palette
            GroupCard {
                title: "PALETTE (wallust)"
                Flow {
                    width: parent.width; spacing: Space.xs
                    Repeater {
                        model: ["harddark", "dark", "softdark", "dark16", "light"]
                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool sel: root.st.wallustPalette === modelData
                            radius: 8; height: 26
                            width: pl.implicitWidth + 20
                            color: sel ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                                       : Qt.lighter(Colors.background, 1.6)
                            border.width: 1
                            border.color: sel ? root.accent : "transparent"
                            Text {
                                id: pl; anchors.centerIn: parent; text: modelData
                                font.family: Type.face; font.pixelSize: Type.xs
                                color: sel ? root.accent : Colors.foreground
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.st.setWallustPalette(modelData) }
                        }
                    }
                }
            }

            // APPEARANCE — hand-edited palette creator (preview + hex/RGB)
            GroupCard {
                title: "PALETTE EDITOR"
                PaletteEditor { width: parent.width; accent: root.accent }
            }

            // DISPLAY — per-output scale (discrete, click to apply; niri reflows
            // logical positions on a scale change so a live slider jumps around)
            GroupCard {
                title: "DISPLAY SCALE"
                Repeater {
                    model: root.st.outputs
                    delegate: Column {
                        id: orow
                        required property var modelData
                        width: parent.width; spacing: 4
                        readonly property real curScale: root.st.outputScales[modelData.name] !== undefined
                            ? root.st.outputScales[modelData.name] : modelData.scale
                        Text {
                            text: orow.modelData.name + "   " + orow.curScale.toFixed(2) + "x"
                            font.family: Type.face; font.pixelSize: Type.sm; color: Colors.foreground
                        }
                        Flow {
                            width: parent.width; spacing: Space.xs
                            Repeater {
                                model: [1.0, 1.25, 1.5, 1.75, 2.0]
                                delegate: Rectangle {
                                    id: sbtn
                                    required property real modelData
                                    readonly property bool sel: Math.abs(orow.curScale - modelData) < 0.01
                                    width: 48; height: 24; radius: 6
                                    color: sel ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                                               : Qt.lighter(Colors.background, 1.6)
                                    border.width: 1; border.color: sel ? root.accent : "transparent"
                                    Text {
                                        anchors.centerIn: parent; text: sbtn.modelData.toFixed(2) + "x"
                                        font.family: Type.face; font.pixelSize: Type.xs
                                        color: sbtn.sel ? root.accent : Colors.foreground
                                    }
                                    MouseArea { anchors.fill: parent
                                        onClicked: root.st.setOutputScale(orow.modelData.name, sbtn.modelData) }
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: root.st.outputs.length === 0
                    text: "No outputs"; font.family: Type.face; font.pixelSize: Type.xs; color: Colors.color8
                }
            }

            // MISC toggles
            GroupCard {
                title: "MISC"
                ToggleRow {
                    label: "Mic loopback (monitor)"
                    on: root.st.micLoopback
                    onToggled: root.st.toggleMicLoopback()
                }
                ToggleRow {
                    label: "Persist Do Not Disturb"
                    on: root.st.dndPersist
                    onToggled: root.st.setDndPersist(!root.st.dndPersist)
                }
            }

            // KEYBINDS — read-only cheatsheet from niri config, with search filter
            GroupCard {
                title: "KEYBINDS (read-only)"
                Rectangle {
                    width: parent.width; height: 26; radius: 6; color: Qt.lighter(Colors.background, 1.6)
                    TextInput {
                        id: kbSearch
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Type.face; font.pixelSize: Type.xs; color: Colors.foreground
                        selectByMouse: true; clip: true
                        onTextChanged: root.kbFilter = text
                        Text {
                            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                            visible: kbSearch.text === ""
                            text: "  search keybinds…"
                            font.family: Type.face; font.pixelSize: Type.xs; color: Colors.color8
                        }
                    }
                }
                Repeater {
                    model: root.filteredBinds
                    delegate: Item {
                        required property var modelData
                        width: parent.width; height: 20
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: parent.width * 0.42
                            text: modelData.key
                            font.family: Type.face; font.pixelSize: Type.xs; color: root.accent
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: parent.width * 0.44; right: parent.right; verticalCenter: parent.verticalCenter }
                            text: modelData.action
                            font.family: Type.face; font.pixelSize: Type.xs; color: Colors.color8
                            elide: Text.ElideRight
                        }
                    }
                }
                Text {
                    visible: root.keybinds.length === 0
                    text: "config.kdl not read"; font.family: Type.face; font.pixelSize: Type.xs; color: Colors.color8
                }
            }
        }
    }
}
