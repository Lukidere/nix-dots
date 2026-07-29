import QtQuick
import QtCore
import Quickshell.Io
import "../../Theme"

Item {
    id: root

    property var wallpapers: []
    readonly property string _home: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")
    readonly property string wallpaperRoot: _home + "/.config/wallpapers"
    readonly property string thumbnailCacheDir: _home + "/.cache/thumbnails/bgselector"

    function getCachedThumbPath(fullPath) {
        const relPath = fullPath.substring(wallpaperRoot.length + 1)
        const cacheName = relPath.replace(/\//g, "_").replace(/\.[^.]+$/, ".jpg")
        const thumbPath = thumbnailCacheDir + "/" + cacheName
        return thumbPath
    }

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
        command: ["find", root.wallpaperRoot, "-maxdepth", "3", "-type", "f",
                  "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", ")"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpapers = this.text.trim().split("\n").filter(Boolean).sort()
            }
        }
    }

    readonly property Process _cacheWarmProc: Process {
        running: false
    }

    Timer {
        interval: 1
        running: true
        onTriggered: {
            const wallDir = root.wallpaperRoot
            const cacheDir = root.thumbnailCacheDir
            // wallDir/cacheDir passed as $1/$2 - never concatenated into the script
            _cacheWarmProc.command = ["sh", "-c",
                'mkdir -p "$2" && ' +
                'find "$1" -maxdepth 3 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \\) ' +
                '| while read img; do ' +
                '  rel_path="${img#"$1"/}"; ' +
                '  cache_name="${rel_path//\\//_}"; ' +
                '  cache_name="${cache_name%.*}.jpg"; ' +
                '  cache_file="$2/$cache_name"; ' +
                '  [ -f "$cache_file" ] || ( ' +
                '    if [[ "$img" =~ \\.(gif|GIF)$ ]]; then ' +
                '      magick "$img[0]" -define jpeg:size=660x1080 -filter Triangle -strip -thumbnail 330x540^ -gravity center -extent 330x540 -quality 80 +repage "$cache_file" 2>/dev/null; ' +
                '    else ' +
                '      magick "$img" -define jpeg:size=660x1080 -filter Triangle -strip -thumbnail 330x540^ -gravity center -extent 330x540 -quality 80 +repage "$cache_file" 2>/dev/null; ' +
                '    fi ' +
                '  ); ' +
                'done',
                "_", wallDir, cacheDir]
            _cacheWarmProc.running = false
            _cacheWarmProc.running = true
            this.running = false
        }
    }

    Process { id: wallustProc; running: false }
    Process { id: awwwProc; running: false }
    Timer { id: wallustDelayTimer; interval: 500; repeat: false; onTriggered: wallustProc.running = true }

    Text {
        id: header
        anchors { left: parent.left; top: parent.top }
        text: root.wallpapers.length + " wallpapers"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
        color: Colors.color6
    }

    GridView {
        id: gridView
        anchors { left: parent.left; right: scrollBar.left; rightMargin: 4; top: header.bottom; bottom: parent.bottom; topMargin: 8 }
        cellWidth: Math.floor((width - 8) / 3)
        cellHeight: cellWidth * 0.625
        model: root.wallpapers
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: cellHeight * 2

        delegate: Item {
            required property string modelData
            required property int index
            width: gridView.cellWidth
            height: gridView.cellHeight

            Image {
                id: thumbImg
                anchors.fill: parent
                source: "file://" + root.getCachedThumbPath(modelData)
                sourceSize.width: 330
                sourceSize.height: 540
                fillMode: Image.PreserveAspectCrop
                smooth: true; mipmap: true; asynchronous: true; clip: true
                onStatusChanged: {
                    if (status === Image.Error) {
                        source = "file://" + modelData
                    }
                }
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
                    wallustDelayTimer.stop()
                    if (themeName) {
                        wallustProc.command = ["wallust", "theme", themeName]
                    } else {
                        wallustProc.command = ["wallust", "run", modelData]
                    }
                    wallustDelayTimer.start()
                }
            }
        }
    }

    // Interactive scrollbar
    Rectangle {
        id: scrollBar
        width: 6; radius: 3
        anchors { right: parent.right; top: gridView.top; bottom: gridView.bottom }
        color: Qt.lighter(Colors.background, 1.3)
        visible: gridView.contentHeight > gridView.height

        MouseArea {
            anchors.fill: parent
            onPressed: function(mouse) {
                var ratio = Math.max(0, Math.min(1, mouse.y / scrollBar.height))
                gridView.contentY = ratio * (gridView.contentHeight - gridView.height)
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var ratio = Math.max(0, Math.min(1, mouse.y / scrollBar.height))
                    gridView.contentY = ratio * (gridView.contentHeight - gridView.height)
                }
            }
        }

        Rectangle {
            width: 6; radius: 3; color: Colors.color4
            height: Math.max(16, scrollBar.height * gridView.height / Math.max(1, gridView.contentHeight))
            y: gridView.contentHeight > gridView.height
             ? (scrollBar.height - height) * gridView.contentY / (gridView.contentHeight - gridView.height)
             : 0
        }
    }
}
