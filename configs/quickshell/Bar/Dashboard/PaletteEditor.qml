import QtQuick
import "../../Theme"

// Clickable palette creator: a mock bar preview + a swatch grid; click a swatch,
// edit it with a hex field or R/G/B sliders, watch the preview recolour live.
// Apply writes the map to wallust's colors.json so the whole shell adopts it.
Item {
    id: root
    property color accent: Colors.color4
    implicitHeight: col.implicitHeight

    // editable snapshot of the live palette
    property var pal: root._snap()
    property string sel: "color4"

    function _snap() {
        return {
            background: Colors.background, foreground: Colors.foreground, cursor: Colors.cursor,
            color0: Colors.color0,  color1: Colors.color1,  color2: Colors.color2,  color3: Colors.color3,
            color4: Colors.color4,  color5: Colors.color5,  color6: Colors.color6,  color7: Colors.color7,
            color8: Colors.color8,  color9: Colors.color9,  color10: Colors.color10, color11: Colors.color11,
            color12: Colors.color12, color13: Colors.color13, color14: Colors.color14, color15: Colors.color15
        }
    }

    readonly property var slots: [
        { k: "background", l: "bg" }, { k: "foreground", l: "fg" },
        { k: "color0", l: "0" },  { k: "color1", l: "1" },  { k: "color2", l: "2" },  { k: "color3", l: "3" },
        { k: "color4", l: "4" },  { k: "color5", l: "5" },  { k: "color6", l: "6" },  { k: "color7", l: "7" },
        { k: "color8", l: "8" },  { k: "color9", l: "9" },  { k: "color10", l: "10" }, { k: "color11", l: "11" },
        { k: "color12", l: "12" }, { k: "color13", l: "13" }, { k: "color14", l: "14" }, { k: "color15", l: "15" }
    ]

    // color <-> hex helpers
    function _h2(n) { n = Math.max(0, Math.min(255, Math.round(n))); var s = n.toString(16); return (s.length < 2 ? "0" : "") + s }
    function hexOf(c) { return "#" + _h2(c.r * 255) + _h2(c.g * 255) + _h2(c.b * 255) }
    function chan(c, i) { return Math.round((i === 0 ? c.r : i === 1 ? c.g : c.b) * 255) }

    function _setSel(c) { var p = Object.assign({}, pal); p[sel] = c; pal = p; hexField.text = hexOf(c) }
    function setChan(i, v) {
        var c = pal[sel], r = chan(c, 0), g = chan(c, 1), b = chan(c, 2)
        if (i === 0) r = v; else if (i === 1) g = v; else b = v
        _setSel(Qt.rgba(r / 255, g / 255, b / 255, 1))
    }
    function setHex(s) {
        s = s.trim().replace(/^#/, "")
        if (!/^[0-9a-fA-F]{6}$/.test(s)) { hexField.text = hexOf(pal[sel]); return }
        _setSel(Qt.rgba(parseInt(s.substr(0, 2), 16) / 255, parseInt(s.substr(2, 2), 16) / 255, parseInt(s.substr(4, 2), 16) / 255, 1))
    }

    function apply() {
        var o = { special: { background: hexOf(pal.background), foreground: hexOf(pal.foreground), cursor: hexOf(pal.cursor) }, colors: {} }
        for (var i = 0; i < 16; i++) o.colors["color" + i] = hexOf(pal["color" + i])
        SettingsState.applyCustomPalette(o)
    }

    onSelChanged: hexField.text = hexOf(pal[sel])
    Component.onCompleted: hexField.text = hexOf(pal[sel])

    // one R/G/B channel row
    component Chan: Item {
        property string label: ""
        property int value: 0
        property color tint: Colors.color8
        signal moved(int v)
        width: parent ? parent.width : 0
        height: 18
        Text {
            id: lbl
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 14; text: parent.label
            font.family: Type.face; font.pixelSize: Type.xs; color: Colors.color8
        }
        Rectangle {
            id: tk
            anchors { left: lbl.right; right: vt.left; leftMargin: 6; rightMargin: 6; verticalCenter: parent.verticalCenter }
            height: 5; radius: 2.5; color: Qt.lighter(Colors.background, 1.6)
            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: parent.width * (parent.parent.value / 255); height: parent.height; radius: parent.radius
                color: parent.parent.tint
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -6; preventStealing: true
                onPressed: e => parent.parent.moved(Math.round(Math.max(0, Math.min(1, e.x / parent.width)) * 255))
                onPositionChanged: e => { if (pressed) parent.parent.moved(Math.round(Math.max(0, Math.min(1, e.x / parent.width)) * 255)) }
            }
        }
        Text {
            id: vt
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 26; horizontalAlignment: Text.AlignRight; text: parent.value
            font.family: Type.face; font.pixelSize: Type.xs; color: Colors.foreground
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Space.sm

        // ── mock bar preview ──
        Rectangle {
            width: parent.width; height: 46; radius: 10
            color: root.pal.background
            border.width: 1
            border.color: Qt.rgba(root.pal.foreground.r, root.pal.foreground.g, root.pal.foreground.b, 0.15)
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 6
                Repeater {
                    model: ["color2", "color4", "color6"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 10; height: 10; radius: 5; color: root.pal[modelData]
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: "12:34   legion"
                font.family: Type.face; font.pixelSize: Type.sm; color: root.pal.foreground
            }
            Row {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 6
                Repeater {
                    model: ["color1", "color3", "color5"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 22; height: 14; radius: 7
                        color: Qt.rgba(root.pal[modelData].r, root.pal[modelData].g, root.pal[modelData].b, 0.35)
                        border.width: 1; border.color: root.pal[modelData]
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ── swatch grid ──
        Grid {
            width: parent.width
            columns: 9
            spacing: 5
            Repeater {
                model: root.slots
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: root.sel === modelData.k
                    width: (root.width - 5 * 8) / 9
                    height: width
                    radius: 6
                    color: root.pal[modelData.k]
                    border.width: active ? 2 : 1
                    border.color: active ? root.accent : Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.2)
                    Text {
                        anchors.centerIn: parent
                        text: modelData.l
                        font.family: Type.face; font.pixelSize: 8
                        // contrast label against the swatch
                        color: parent.color.hslLightness > 0.5 ? "#000000" : "#ffffff"
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.sel = modelData.k }
                }
            }
        }

        // ── selected-colour editor ──
        Row {
            width: parent.width; spacing: Space.sm
            Rectangle {
                width: 40; height: 40; radius: 8
                color: root.pal[root.sel]
                border.width: 1; border.color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.2)
            }
            Column {
                width: parent.width - 40 - Space.sm
                spacing: 4
                Row {
                    spacing: Space.sm
                    Text {
                        text: root.sel; width: 74
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Type.face; font.pixelSize: Type.xs; color: Colors.color8
                    }
                    Rectangle {
                        width: 96; height: 22; radius: 6; color: Qt.lighter(Colors.background, 1.5)
                        TextInput {
                            id: hexField
                            anchors { fill: parent; leftMargin: 7; rightMargin: 7 }
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Type.face; font.pixelSize: Type.sm; color: Colors.foreground
                            selectByMouse: true; maximumLength: 7
                            onEditingFinished: root.setHex(text)
                            Keys.onReturnPressed: root.setHex(text)
                        }
                    }
                }
                Chan { label: "R"; value: root.chan(root.pal[root.sel], 0); tint: "#e06c75"; onMoved: v => root.setChan(0, v) }
                Chan { label: "G"; value: root.chan(root.pal[root.sel], 1); tint: "#98c379"; onMoved: v => root.setChan(1, v) }
                Chan { label: "B"; value: root.chan(root.pal[root.sel], 2); tint: "#61afef"; onMoved: v => root.setChan(2, v) }
            }
        }

        // ── actions ──
        Row {
            spacing: Space.sm
            Rectangle {
                width: 88; height: 28; radius: 8
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                border.width: 1; border.color: root.accent
                Text { anchors.centerIn: parent; text: "Apply"; font.family: Type.face; font.pixelSize: Type.sm; color: root.accent }
                MouseArea { anchors.fill: parent; onClicked: root.apply() }
            }
            Rectangle {
                width: 88; height: 28; radius: 8
                color: Qt.lighter(Colors.background, 1.6)
                Text { anchors.centerIn: parent; text: "Reset"; font.family: Type.face; font.pixelSize: Type.sm; color: Colors.foreground }
                MouseArea { anchors.fill: parent; onClicked: { root.pal = root._snap(); root.sel = root.sel } }
            }
        }
    }
}
