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

    // set a wallpaper: swap it via awww, then retheme via wallust (debounced)
    function setWallpaper(path) {
        awwwProc.command = ["awww", "img", path]
        awwwProc.running = false; awwwProc.running = true
        var themeName = root.wallustThemeName(path)
        wallustDelayTimer.stop()
        if (themeName) {
            wallustProc.command = ["wallust", "theme", themeName]
        } else {
            // unmapped folders derive the palette from the image; some pin a
            // wallust palette scheme (Purple/Light -> softdark, the purple look)
            var pal = root.wallustPaletteFor(path)
            wallustProc.command = pal
                ? ["wallust", "run", path, "--palette", pal]
                : ["wallust", "run", path]
        }
        wallustDelayTimer.start()
    }
    // per-folder wallust palette scheme override for image-derived themes
    function wallustPaletteFor(path) {
        var parts = path.split("/")
        var theme = (parts[parts.length - 3] || "").toLowerCase()
        // Purple (both variations) uses softdark for the vivid violet look; Indigo
        // holds the same images but stays image-derived for a deep indigo bg
        if (theme === "purple") return "softdark"
        return ""
    }
    // "Theme · Variation" label from the path
    function wallName(path) {
        var p = (path || "").split("/")
        return p.length >= 3 ? (p[p.length - 3] + "  ·  " + p[p.length - 2]) : ""
    }

    readonly property Process _listProc: Process {
        // -L follows symlinks: home-manager deploys wallpapers as store symlinks,
        // which a plain `-type f` would skip
        command: ["find", "-L", root.wallpaperRoot, "-maxdepth", "3", "-type", "f",
                  "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", ")"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // dedup same-image entries that differ only by extension: the
                // legacy ~/.config/wallpapers submodule ships .png files while
                // home-manager overlays .jpg symlinks, so each showed twice.
                // Keep the first per dir+stem (sorted -> .jpg wins over .png)
                var all = this.text.trim().split("\n").filter(Boolean).sort()
                var seen = {}, out = []
                for (var i = 0; i < all.length; i++) {
                    var key = all[i].replace(/\.[^./]+$/, "")
                    if (!seen[key]) { seen[key] = true; out.push(all[i]) }
                }
                root.wallpapers = out
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
                'find -L "$1" -maxdepth 3 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \\) ' +
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

    // after wallust: run the contrast fixer (readable accents on softdark-style
    // palettes, patches colors.json + ghostty), then reload the live palette
    Process { id: wallustProc; running: false; onExited: contrastProc.running = true }
    Process {
        id: contrastProc; running: false
        command: ["python3", root._home + "/.config/quickshell/scripts/qs-contrast.py"]
        onExited: Colors.reload()
    }
    Process { id: awwwProc; running: false }
    Timer { id: wallustDelayTimer; interval: 150; repeat: false; onTriggered: wallustProc.running = true }

    Text {
        id: header
        anchors { left: parent.left; top: parent.top }
        text: (carousel.currentIndex + 1) + " / " + root.wallpapers.length + "   ·   scroll or drag · click center to set"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
        color: Colors.color6
    }

    // ── coverflow carousel: center wallpaper large, sides small + dimmed ──
    PathView {
        id: carousel
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: nameLabel.top; topMargin: 8; bottomMargin: 8 }
        model: root.wallpapers
        pathItemCount: 7
        snapMode: PathView.SnapOneItem
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: 220
        clip: true
        dragMargin: height   // grab-drag anywhere in the strip
        focus: true          // Enter sets the centered wallpaper
        Keys.onReturnPressed: if (currentIndex >= 0) root.setWallpaper(root.wallpapers[currentIndex])
        Keys.onEnterPressed:  if (currentIndex >= 0) root.setWallpaper(root.wallpapers[currentIndex])

        path: Path {
            startX: 0; startY: carousel.height / 2
            PathAttribute { name: "iscale";   value: 0.55 }
            PathAttribute { name: "iopacity"; value: 0.25 }
            PathAttribute { name: "iz";       value: 0 }
            PathLine { x: carousel.width / 2; y: carousel.height / 2 }
            PathPercent { value: 0.5 }
            PathAttribute { name: "iscale";   value: 1.0 }
            PathAttribute { name: "iopacity"; value: 1.0 }
            PathAttribute { name: "iz";       value: 100 }
            PathLine { x: carousel.width; y: carousel.height / 2 }
            PathAttribute { name: "iscale";   value: 0.55 }
            PathAttribute { name: "iopacity"; value: 0.25 }
            PathAttribute { name: "iz";       value: 0 }
        }

        delegate: Item {
            id: card
            required property string modelData
            required property int index
            width: carousel.width * 0.46
            height: width * 0.6
            z: PathView.iz
            scale: PathView.iscale
            opacity: PathView.iopacity
            Behavior on scale { NumberAnimation { duration: 120 } }

            Image {
                id: thumbImg
                anchors.fill: parent
                source: "file://" + root.getCachedThumbPath(card.modelData)
                sourceSize.width: 330; sourceSize.height: 540
                fillMode: Image.PreserveAspectCrop
                smooth: true; mipmap: true; asynchronous: true; clip: true
                onStatusChanged: if (status === Image.Error) source = "file://" + card.modelData
            }
            Rectangle {
                anchors.fill: parent; radius: 8; color: "transparent"
                border.width: 3
                border.color: card.PathView.isCurrentItem ? Colors.color4 : "transparent"
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onClicked: {
                    carousel.currentIndex = card.index
                    root.setWallpaper(card.modelData)
                }
            }
        }

    }

    // wheel-scroll overlay: NoButton so clicks still reach the cards below
    MouseArea {
        anchors.fill: carousel
        acceptedButtons: Qt.NoButton
        onWheel: e => { if (e.angleDelta.y < 0) carousel.incrementCurrentIndex()
                        else carousel.decrementCurrentIndex() }
    }

    Text {
        id: nameLabel
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
        text: root.wallName(root.wallpapers[carousel.currentIndex] || "")
        font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true
        color: Colors.foreground
    }
}
