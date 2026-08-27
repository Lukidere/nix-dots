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

                        // dynamic slider (music-tab feel): thin pill, grows and
                        // brightens on hover, fill glides smoothly, instant on drag
                        Item {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 12
                            Rectangle {
                                id: track
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                height: (sliderMa.containsMouse || sliderMa.pressed) ? 7 : 4
                                radius: height / 2
                                color: Qt.lighter(Colors.background, 1.5)
                                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, modelData.volume / 100))
                                    height: parent.height; radius: parent.radius
                                    color: modelData.muted ? Colors.color1
                                         : (sliderMa.containsMouse || sliderMa.pressed) ? Qt.lighter(root.accent, 1.15) : root.accent
                                    Behavior on width { NumberAnimation { duration: sliderMa.pressed ? 0 : 220; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }
                            MouseArea {
                                id: sliderMa
                                anchors.fill: parent
                                hoverEnabled: true
                                function calc(mx) { return Math.max(0, Math.min(100, Math.round(mx / track.width * 100))) }
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
