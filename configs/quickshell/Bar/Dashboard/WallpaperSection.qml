import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root

    property var wallpapers: []

    function wallustThemeName(path) {
        var parts = path.split("/")
        // .../ThemeName/Variation/image.jpg
        var theme = (parts[parts.length - 3] || "").toLowerCase()
        var variation = (parts[parts.length - 2] || "").toLowerCase()
        if (theme === "osaka") theme = "solarized"

        var map = {
            "catppuccin":  { "dark": "Catppuccin-Mocha",         "light": "Catppuccin-Latte" },
            "dracula":     { "dark": "base16-dracula",           "light": "base16-default-light" },
            "everforest":  { "dark": "Everforest-Dark-Medium",   "light": "Everforest-Light-Medium" },
            "gruvbox":     { "dark": "Gruvbox-Dark",             "light": "Gruvbox" },
            "material":    { "dark": "base16-black-metal-funeral","light": "base16-default-light" },
            "nord":        { "dark": "Nord",                     "light": "Nord-Light" },
            "solarized":   { "dark": "Solarized-Dark",           "light": "Solarized-Light" },
            "rose-pine":   { "dark": "Rosé-Pine",                "light": "Rosé-Pine-Dawn" },
            "tokyo-night": { "dark": "Tokyo-Night",              "light": "Tokyo-Night-Light" },
        }

        if (map[theme] && map[theme][variation])
            return map[theme][variation]
        return ""
    }

    readonly property Process _listProc: Process {
        command: ["sh", "-c",
            "find /home/dhm/.config/wallpapers -maxdepth 3" +
            " \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \\)" +
            " 2>/dev/null | sort"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpapers = this.text.trim().split("\n").filter(Boolean)
            }
        }
    }

    Process { id: wallustProc; running: false }
    Process { id: awwwProc; running: false }

    Text {
        id: header
        anchors { left: parent.left; top: parent.top }
        text: root.wallpapers.length + " wallpapers"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
        color: Colors.color6
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: scrollBar.left; rightMargin: 4; top: header.bottom; bottom: parent.bottom; topMargin: 8 }
        contentHeight: thumbFlow.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            onWheel: function(event) {
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height,
                    flick.contentY - event.angleDelta.y))
            }
        }

        Flow {
            id: thumbFlow
            width: flick.width; spacing: 4

            Repeater {
                model: root.wallpapers
                delegate: Item {
                    required property string modelData
                    width: (thumbFlow.width - 8) / 3
                    height: width * 0.625

                    Image {
                        anchors.fill: parent
                        source: "file://" + modelData
                        sourceSize.width: 180
                        sourceSize.height: 120
                        fillMode: Image.PreserveAspectCrop
                        smooth: true; mipmap: true; asynchronous: true; clip: true
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 4; color: "transparent"
                        border.color: wMa.containsMouse ? Colors.color4 : "transparent"
                        border.width: 2
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea {
                        id: wMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            awwwProc.command = ["awww", "img", modelData]
                            awwwProc.running = false; awwwProc.running = true
                            var themeName = root.wallustThemeName(modelData)
                            if (themeName) {
                                wallustProc.command = ["sh", "-c", "sleep 0.5 && wallust theme " + JSON.stringify(themeName)]
                            } else {
                                wallustProc.command = ["sh", "-c", "sleep 0.5 && wallust run " + JSON.stringify(modelData)]
                            }
                            wallustProc.running = false; wallustProc.running = true
                        }
                    }
                }
            }
        }
    }

    // Interactive scrollbar
    Rectangle {
        id: scrollBar
        width: 6; radius: 3
        anchors { right: parent.right; top: flick.top; bottom: flick.bottom }
        color: Qt.lighter(Colors.background, 1.3)
        visible: flick.contentHeight > flick.height

        MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) {
                var ratio = Math.max(0, Math.min(1, mouse.y / scrollBar.height))
                flick.contentY = ratio * (flick.contentHeight - flick.height)
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var ratio = Math.max(0, Math.min(1, mouse.y / scrollBar.height))
                    flick.contentY = ratio * (flick.contentHeight - flick.height)
                }
            }
        }

        Rectangle {
            width: 6; radius: 3; color: Colors.color4
            height: Math.max(16, scrollBar.height * flick.height / Math.max(1, flick.contentHeight))
            y: flick.contentHeight > flick.height
             ? (scrollBar.height - height) * flick.contentY / (flick.contentHeight - flick.height)
             : 0
        }
    }
}
