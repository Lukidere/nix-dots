import QtQuick
import "../../Theme"

Item {
    id: root
    height: col.implicitHeight

    property int workMinutes:  25
    property int breakMinutes: 5
    property int secondsLeft:  25 * 60
    property int session:      0      // 0 = work, 1 = break
    property bool running:     false

    function formatTime(s) {
        return String(Math.floor(s / 60)).padStart(2, "0") + ":"
             + String(s % 60).padStart(2, "0")
    }

    Timer {
        interval: 1000; running: root.running; repeat: true
        onTriggered: {
            if (root.secondsLeft > 0) {
                root.secondsLeft--
            } else {
                root.running = false
                root.session = root.session === 0 ? 1 : 0
                root.secondsLeft = root.session === 0
                    ? root.workMinutes  * 60
                    : root.breakMinutes * 60
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 14

        // Timer display
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.formatTime(root.secondsLeft)
            font.family: "Iosevka Nerd Font"; font.pixelSize: 40; font.bold: true
            color: root.session === 0 ? Colors.color4 : Colors.color2
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Session label
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.session === 0 ? "\uF017  Work" : "\uF0F4  Break"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
            color: Colors.color8
        }

        // Progress bar
        Rectangle {
            width: parent.width; height: 4; radius: 2
            color: Qt.lighter(Colors.background, 1.4)
            Rectangle {
                property int totalSecs: root.session === 0
                    ? root.workMinutes * 60 : root.breakMinutes * 60
                width: totalSecs > 0
                    ? parent.width * (1 - root.secondsLeft / totalSecs)
                    : 0
                height: 4; radius: 2
                color: root.session === 0 ? Colors.color4 : Colors.color2
                Behavior on width { NumberAnimation { duration: 800 } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        // Controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            // Reset
            Rectangle {
                width: 48; height: 30; radius: 8
                color: resetMa.containsMouse
                    ? Qt.lighter(Colors.background, 1.5)
                    : Qt.lighter(Colors.background, 1.3)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: "\uF01E"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                    color: Colors.foreground
                }
                MouseArea {
                    id: resetMa; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        root.running     = false
                        root.session     = 0
                        root.secondsLeft = root.workMinutes * 60
                    }
                }
            }

            // Play / Pause
            Rectangle {
                width: 72; height: 30; radius: 8
                color: root.running ? Colors.color1 : Colors.color4
                Behavior on color { ColorAnimation { duration: 200 } }
                Text {
                    anchors.centerIn: parent
                    text: root.running ? "\uF04C" : "\uF04B"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                    color: Colors.background
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.running = !root.running
                }
            }

            // Skip to next session
            Rectangle {
                width: 48; height: 30; radius: 8
                color: skipMa.containsMouse
                    ? Qt.lighter(Colors.background, 1.5)
                    : Qt.lighter(Colors.background, 1.3)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: "\uF051"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                    color: Colors.foreground
                }
                MouseArea {
                    id: skipMa; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        root.running = false
                        root.session = root.session === 0 ? 1 : 0
                        root.secondsLeft = root.session === 0
                            ? root.workMinutes  * 60
                            : root.breakMinutes * 60
                    }
                }
            }
        }
    }
}
