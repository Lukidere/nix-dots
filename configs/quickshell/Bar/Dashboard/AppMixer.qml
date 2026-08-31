import QtQuick
import "../../Theme"

// Per-app volume mixer: every app currently playing audio with its own slider.
Item {
    id: root
    property color accent: Colors.color4
    readonly property var av: AppVolState

    Column {
        anchors.fill: parent
        spacing: 6

        Text {
            text: "APP VOLUME"
            font.family: Type.face; font.pixelSize: Type.xs
            color: Colors.color8
        }
        Rectangle {
            width: parent.width; height: 1
            color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.25)
        }

        Text {
            visible: root.av.streams.length === 0
            width: parent.width
            text: "No apps playing"
            font.family: Type.face; font.pixelSize: Type.sm
            color: Colors.color8; horizontalAlignment: Text.AlignHCenter
        }

        Flickable {
            width: parent.width
            height: parent.height - 20
            contentHeight: rows.implicitHeight; clip: true
            boundsBehavior: Flickable.StopAtBounds
            // vertical-only so horizontal slider drags are never stolen for a flick
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: rows
                width: parent.width; spacing: 8

                Repeater {
                    model: root.av.streams
                    delegate: Item {
                        required property var modelData
                        width: rows.width; height: 40

                        // first-letter badge (no freedesktop icon rendering here)
                        Rectangle {
                            id: badge
                            anchors { left: parent.left; top: parent.top }
                            width: 18; height: 18; radius: 9
                            color: modelData.muted
                                ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.3)
                                : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                            Text {
                                anchors.centerIn: parent
                                text: (modelData.label || "?").charAt(0).toUpperCase()
                                font.family: Type.face; font.pixelSize: 10; font.bold: true
                                color: modelData.muted ? Colors.color1 : root.accent
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.av.toggleMute(modelData.id) }
                        }
                        Text {
                            anchors { left: badge.right; leftMargin: 6; right: pct.left; rightMargin: 6; verticalCenter: badge.verticalCenter }
                            text: modelData.label
                            font.family: Type.face; font.pixelSize: Type.sm
                            color: modelData.muted ? Colors.color8 : Colors.foreground
                            elide: Text.ElideRight
                        }
                        Text {
                            id: pct
                            anchors { right: parent.right; verticalCenter: badge.verticalCenter }
                            text: modelData.volume + "%"
                            font.family: Type.face; font.pixelSize: Type.xs
                            color: Colors.color6
                        }

                        // horizontal take on the main VSlider: thin accent-filled
                        // track with a round thumb that follows the value; track
                        // thickens + thumb grows on hover, fill glides, instant on drag
                        Item {
                            id: sld
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 14
                            readonly property real frac: Math.max(0, Math.min(1, modelData.volume / 100))
                            readonly property bool active: sliderMa.containsMouse || sliderMa.pressed
                            readonly property color fillColor: modelData.muted ? Colors.color1
                                : sld.active ? Qt.lighter(root.accent, 1.15) : root.accent

                            Rectangle {
                                id: track
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                height: sld.active ? 7 : 4
                                radius: height / 2
                                color: Qt.lighter(Colors.background, 1.5)
                                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                Rectangle {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    width: parent.width * sld.frac
                                    height: parent.height; radius: parent.radius
                                    color: sld.fillColor
                                    Behavior on width { NumberAnimation { duration: sliderMa.pressed ? 0 : 220; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }
                            // round thumb, mirrors the VSlider handle
                            Rectangle {
                                readonly property int sz: sld.active ? 14 : 11
                                width: sz; height: sz; radius: sz / 2
                                y: (sld.height - sz) / 2
                                x: Math.max(0, Math.min(sld.width - sz, sld.width * sld.frac - sz / 2))
                                color: sld.fillColor
                                Behavior on x      { NumberAnimation { duration: sliderMa.pressed ? 0 : 220; easing.type: Easing.OutCubic } }
                                Behavior on width  { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                Behavior on color  { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                id: sliderMa
                                anchors.fill: parent
                                hoverEnabled: true
                                // stop the enclosing Flickable from stealing the
                                // drag gesture, otherwise only the initial click lands
                                preventStealing: true
                                function calc(mx) { return Math.max(0, Math.min(100, Math.round(mx / sld.width * 100))) }
                                onPressed: e => root.av.setVolume(modelData.id, calc(e.x))
                                onPositionChanged: e => { if (pressed) root.av.setVolume(modelData.id, calc(e.x)) }
                            }
                        }
                    }
                }
            }
        }
    }
}
