import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    height: thumbFlow.implicitHeight + 4

    property string wallDir: "/home/dhm/.config/wallpapers"
    property var    wallpapers: []

    readonly property Process _listProc: Process {
        command: ["sh", "-c",
            "find " + JSON.stringify(root.wallDir) +
            " -maxdepth 3 \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \\)" +
            " 2>/dev/null | sort | head -16"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpapers = this.text.trim().split("\n").filter(Boolean)
            }
        }
    }

    Flow {
        id: thumbFlow
        width: parent.width
        spacing: 4

        Repeater {
            model: root.wallpapers
            delegate: Item {
                property string path: modelData
                width: (thumbFlow.width - 12) / 4
                height: width * 0.625

                Image {
                    anchors.fill: parent
                    source: "file://" + path
                    fillMode: Image.PreserveAspectCrop
                    smooth: true; mipmap: true
                    asynchronous: true
                    clip: true
                }
                Rectangle {
                    anchors.fill: parent; radius: 4
                    color: "transparent"
                    border.color: thumbMa.containsMouse ? Colors.color4 : "transparent"
                    border.width: 2
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    id: thumbMa; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        wallustProc.command = ["sh", "-c",
                            "wallust run " + JSON.stringify(path)
                        ]
                        wallustProc.running = false; wallustProc.running = true
                    }
                }
            }
        }
    }

    Process { id: wallustProc; running: false }
}
