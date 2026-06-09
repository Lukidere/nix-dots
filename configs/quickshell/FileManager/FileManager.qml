import QtQuick
import Quickshell
import Quickshell.Io
import QtCore
import Quickshell.Wayland
import "../Theme"

PanelWindow {
    id: root
    visible: false
    color: "transparent"

    anchors { left: true; right: true; top: true; bottom: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: -1

    readonly property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    property string currentPath:  homeDir
    property var    items:         []
    property string searchText:    ""
    property bool   showHidden:    false
    property string selectedFile:  ""
    property string renamingFile:  ""
    property string clipboardFile: ""
    property bool   clipboardCut:  false
    property var    history:       []
    property int    historyIndex:  -1
    property var    bookmarks: [
        { name: "Home",      path: homeDir,                icon: "" },
        { name: "Documents", path: homeDir + "/Documents", icon: "" },
        { name: "Downloads", path: homeDir + "/Downloads", icon: "" },
        { name: "Music",     path: homeDir + "/Music",     icon: "" },
        { name: "Pictures",  path: homeDir + "/Pictures",  icon: "" },
        { name: "Videos",    path: homeDir + "/Videos",    icon: "" },
    ]

    readonly property var filteredItems: {
        if (!searchText) return items
        const q = searchText.toLowerCase()
        return items.filter(function(f) { return f.name.toLowerCase().includes(q) })
    }

    // --- FIFO trigger ---
    readonly property Process _setup: Process {
        command: ["sh", "-c", "rm -f /run/user/1000/qs-fm; mkfifo /run/user/1000/qs-fm"]
        running: true
        stdout: StdioCollector { onStreamFinished: root._reader.running = true }
    }
    readonly property Process _reader: Process {
        running: false
        command: ["sh", "-c", "read -r _ < /run/user/1000/qs-fm"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.visible = !root.visible
                root._reader.running = false
                root._reader.running = true
            }
        }
    }

    // --- File listing ---
    readonly property Process _lsProc: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const list = []
                lines.forEach(function(line) {
                    if (!line) return
                    const p = line.split("\t")
                    if (p.length < 5) return
                    const hidden = p[1].startsWith(".")
                    if (!root.showHidden && hidden) return
                    list.push({
                        type:  p[0],
                        name:  p[1],
                        size:  parseInt(p[2]) || 0,
                        date:  p[3] || "",
                        perms: p[4] || "",
                        isDir: p[0] === "d",
                        isLink: p[0] === "l"
                    })
                })
                list.sort(function(a, b) {
                    if (a.isDir !== b.isDir) return a.isDir ? -1 : 1
                    return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
                })
                root.items = list
            }
        }
    }

    // --- File operations ---
    Process {
        id: _opProc
        running: false
        onRunningChanged: if (!running) root.refresh()
    }

    // --- Functions ---
    function refresh() {
        _lsProc.command = ["sh", "-c",
            "find " + JSON.stringify(root.currentPath) +
            " -maxdepth 1 -mindepth 1 -printf '%y\\t%f\\t%s\\t%TY-%Tm-%Td\\t%M\\n' 2>/dev/null"
        ]
        _lsProc.running = false
        _lsProc.running = true
    }

    function navigate(path) {
        if (historyIndex < history.length - 1)
            history = history.slice(0, historyIndex + 1)
        history = history.concat([path])
        historyIndex = history.length - 1
        currentPath = path
        selectedFile = ""
        renamingFile = ""
    }

    function goBack() {
        if (historyIndex > 0) { historyIndex--; currentPath = history[historyIndex]; selectedFile = "" }
    }
    function goForward() {
        if (historyIndex < history.length - 1) { historyIndex++; currentPath = history[historyIndex]; selectedFile = "" }
    }
    function goUp() {
        const parts = currentPath.split("/").filter(p => p !== "")
        if (parts.length > 0) {
            parts.pop()
            navigate(parts.length === 0 ? "/" : "/" + parts.join("/"))
        }
    }

    function openFile(path) {
        _opProc.command = ["xdg-open", path]
        _opProc.running = false; _opProc.running = true
    }
    function deleteSelected() {
        if (!root.selectedFile) return
        _opProc.command = ["rm", "-rf", root.currentPath + "/" + root.selectedFile]
        root.selectedFile = ""
        _opProc.running = false; _opProc.running = true
    }
    function renameFile(oldName, newName) {
        if (!newName || newName === oldName) { root.renamingFile = ""; return }
        _opProc.command = ["mv",
            root.currentPath + "/" + oldName,
            root.currentPath + "/" + newName
        ]
        root.renamingFile = ""
        _opProc.running = false; _opProc.running = true
    }
    function pasteClipboard() {
        if (!root.clipboardFile) return
        if (root.clipboardCut)
            _opProc.command = ["mv", root.clipboardFile, root.currentPath + "/"]
        else
            _opProc.command = ["sh", "-c",
                "cp -r " + JSON.stringify(root.clipboardFile) + " " + JSON.stringify(root.currentPath + "/")
            ]
        root.clipboardFile = ""
        _opProc.running = false; _opProc.running = true
    }
    function newFolder() {
        _opProc.command = ["sh", "-c",
            "mkdir -p " + JSON.stringify(root.currentPath + "/New Folder")
        ]
        _opProc.running = false; _opProc.running = true
    }

    function fileIcon(item) {
        if (item.isLink) return ""
        if (item.isDir)  return ""
        const ext = item.name.toLowerCase().split(".").pop()
        if (["png","jpg","jpeg","gif","svg","webp","bmp","ico"].includes(ext)) return ""
        if (["mp4","mkv","avi","mov","webm","flv","m4v"].includes(ext))       return ""
        if (["mp3","flac","ogg","wav","aac","opus","m4a"].includes(ext))      return ""
        if (["pdf"].includes(ext))                                             return ""
        if (["zip","tar","gz","bz2","xz","7z","rar","zst"].includes(ext))    return ""
        if (["sh","bash","fish","zsh","py","js","ts","rs","go",
             "c","cpp","h","nix","lua","json","toml","yaml","md",
             "html","css","sql","vim","kt","java","rb"].includes(ext))        return ""
        if (item.perms && item.perms.length > 3 && item.perms[3] === "x")    return ""
        return ""
    }

    function fileIconColor(item) {
        if (item.isDir)  return Colors.color4
        if (item.isLink) return Colors.color6
        const ext = item.name.toLowerCase().split(".").pop()
        if (["png","jpg","jpeg","gif","svg","webp","bmp"].includes(ext)) return Colors.color3
        if (["mp4","mkv","avi","mov","webm"].includes(ext))              return Colors.color5
        if (["mp3","flac","ogg","wav","aac","opus"].includes(ext))       return Colors.color6
        if (["sh","py","js","ts","rs","go","c","cpp","nix","lua"].includes(ext)) return Colors.color2
        if (["zip","tar","gz","bz2","xz","7z","rar"].includes(ext))     return Colors.color3
        if (["pdf"].includes(ext))                                        return Colors.color1
        return Colors.foreground
    }

    function formatSize(bytes, isDir) {
        if (isDir) return "-"
        if (bytes <= 0) return "0 B"
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " K"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " M"
        return (bytes / 1073741824).toFixed(2) + " G"
    }

    onCurrentPathChanged: refresh()
    onShowHiddenChanged:  refresh()

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus()
            root.renamingFile = ""
        }
    }

    Component.onCompleted: {
        history = [currentPath]
        historyIndex = 0
    }

    // --- Keyboard shortcuts ---
    Keys.onEscapePressed: root.visible = false
    Keys.onPressed: function(ev) {
        const ctrl = ev.modifiers & Qt.ControlModifier
        if (ev.key === Qt.Key_F2 && root.selectedFile && root.renamingFile === "") {
            root.renamingFile = root.selectedFile; ev.accepted = true
        }
        if (ev.key === Qt.Key_Delete && root.selectedFile && root.renamingFile === "") {
            root.deleteSelected(); ev.accepted = true
        }
        if (ctrl && ev.key === Qt.Key_C && root.selectedFile) {
            root.clipboardFile = root.currentPath + "/" + root.selectedFile
            root.clipboardCut = false; ev.accepted = true
        }
        if (ctrl && ev.key === Qt.Key_X && root.selectedFile) {
            root.clipboardFile = root.currentPath + "/" + root.selectedFile
            root.clipboardCut = true; ev.accepted = true
        }
        if (ctrl && ev.key === Qt.Key_V) { root.pasteClipboard(); ev.accepted = true }
        if (ctrl && ev.key === Qt.Key_L) { pathInput.forceActiveFocus(); pathInput.selectAll(); ev.accepted = true }
        if (ctrl && ev.key === Qt.Key_F) { searchInput.forceActiveFocus(); ev.accepted = true }
        if (ctrl && ev.key === Qt.Key_N) { root.newFolder(); ev.accepted = true }
        if (ev.key === Qt.Key_Backspace && !pathInput.activeFocus && !searchInput.activeFocus) {
            root.goBack(); ev.accepted = true
        }
    }

    // --- Main container ---
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 900)
        height: Math.min(parent.height - 80, 600)
        radius: 10
        color: Colors.background
        border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.3)
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // --- Toolbar ---
        Rectangle {
            id: toolbar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 44
            color: Qt.darker(Colors.background, 1.1)
            radius: 10

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 10
                color: parent.color
            }

            Row {
                id: navBtns
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 8 }
                spacing: 4

                Repeater {
                    model: [
                        { icon: "", action: "back",    enabled: root.historyIndex > 0 },
                        { icon: "", action: "forward", enabled: root.historyIndex < root.history.length - 1 },
                        { icon: "", action: "up",      enabled: root.currentPath !== "/" },
                        { icon: "", action: "home",    enabled: true },
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 28; height: 28; radius: 6
                        color: navMa.containsMouse && modelData.enabled
                            ? Qt.lighter(Colors.background, 1.4) : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                        opacity: modelData.enabled ? 1.0 : 0.3
                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                            color: Colors.foreground
                        }
                        MouseArea {
                            id: navMa; anchors.fill: parent; hoverEnabled: true
                            enabled: modelData.enabled
                            onClicked: {
                                if (modelData.action === "back")         root.goBack()
                                else if (modelData.action === "forward") root.goForward()
                                else if (modelData.action === "up")      root.goUp()
                                else if (modelData.action === "home")    root.navigate(root.homeDir)
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: pathBox
                anchors {
                    left: navBtns.right; right: rightBtns.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 8; rightMargin: 8
                }
                height: 28; radius: 6
                color: Qt.lighter(Colors.background, 1.3)
                border.color: pathInput.activeFocus ? Colors.color4 : "transparent"
                border.width: 1

                TextInput {
                    id: pathInput
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.currentPath
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.foreground
                    clip: true
                    onAccepted: { root.navigate(text.trim()); focus = false }
                    Keys.onEscapePressed: { text = root.currentPath; focus = false }
                }
            }

            Row {
                id: rightBtns
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
                spacing: 4

                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: nfMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                        color: Colors.foreground
                    }
                    MouseArea { id: nfMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.newFolder() }
                }

                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: hidMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent
                        text: root.showHidden ? "" : ""
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                        color: root.showHidden ? Colors.color4 : Colors.color8
                    }
                    MouseArea { id: hidMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.showHidden = !root.showHidden }
                }

                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: closeMa.containsMouse ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.2) : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                        color: closeMa.containsMouse ? Colors.color1 : Colors.color8
                    }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.visible = false }
                }
            }
        }

        // --- Search bar ---
        Rectangle {
            id: searchBar
            anchors { top: toolbar.bottom; left: parent.left; right: parent.right }
            height: 34; color: Qt.darker(Colors.background, 1.03)

            Rectangle {
                anchors { fill: parent; margins: 5 }
                radius: 6
                color: Qt.lighter(Colors.background, 1.25)
                border.color: searchInput.activeFocus ? Colors.color4 : "transparent"
                border.width: 1

                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                    spacing: 8
                    Text {
                        text: ""
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                        color: Colors.color8
                    }
                    TextInput {
                        id: searchInput
                        width: searchBar.width - 90
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                        color: Colors.foreground
                        onTextChanged: root.searchText = text
                        Keys.onEscapePressed: { text = ""; focus = false }
                    }
                }

                Text {
                    anchors { left: parent.left; leftMargin: 32; verticalCenter: parent.verticalCenter }
                    visible: searchInput.text === "" && !searchInput.activeFocus
                    text: "Search in " + (root.currentPath.split("/").pop() || "/") + "..."
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.color8
                }
            }
        }

        // --- Body ---
        Rectangle {
            id: body
            anchors {
                top: searchBar.bottom; left: parent.left; right: parent.right; bottom: statusBar.top
            }
            color: "transparent"

            // Sidebar
            Rectangle {
                id: sidebar
                anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
                width: 130
                color: Qt.darker(Colors.background, 1.05)

                Rectangle {
                    anchors { top: parent.top; right: parent.right }
                    width: 1; height: parent.height
                    color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.15)
                }

                Column {
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 8 }

                    Repeater {
                        model: root.bookmarks
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width; height: 28; radius: 4
                            color: root.currentPath === modelData.path
                                ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.15)
                                : (bmHov.containsMouse ? Qt.lighter(Colors.background, 1.3) : "transparent")
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Row {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                                spacing: 8
                                Text {
                                    text: modelData.icon
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                                    color: Colors.color4
                                }
                                Text {
                                    text: modelData.name
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                    color: Colors.foreground
                                }
                            }
                            MouseArea {
                                id: bmHov; anchors.fill: parent; hoverEnabled: true
                                onClicked: root.navigate(modelData.path)
                            }
                        }
                    }
                }
            }

            // File area
            Rectangle {
                id: fileArea
                anchors { top: parent.top; left: sidebar.right; right: parent.right; bottom: parent.bottom }
                color: "transparent"

                // Column headers
                Rectangle {
                    id: listHeader
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 24
                    color: Qt.darker(Colors.background, 1.08)

                    Row {
                        anchors { fill: parent; leftMargin: 42 }

                        Text {
                            width: fileArea.width - 200
                            text: "Name"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                            color: Colors.color8
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            width: 70
                            text: "Size"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                            color: Colors.color8
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                        }
                        Text {
                            width: 80
                            text: "Date"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                            color: Colors.color8
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            height: parent.height
                            rightPadding: 10
                        }
                    }
                }

                Flickable {
                    id: fileFlick
                    anchors { top: listHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                    contentHeight: fileCol.implicitHeight
                    clip: true

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    Column {
                        id: fileCol
                        width: parent.width
                        topPadding: 2

                        Repeater {
                            model: root.filteredItems

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: fileCol.width; height: 30; radius: 4
                                color: root.selectedFile === modelData.name
                                    ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.15)
                                    : (itemMa.containsMouse ? Qt.lighter(Colors.background, 1.35) : "transparent")
                                Behavior on color { ColorAnimation { duration: 60 } }

                                Row {
                                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                    spacing: 8

                                    Text {
                                        text: root.fileIcon(modelData)
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                                        color: root.fileIconColor(modelData)
                                        width: 18
                                    }

                                    Text {
                                        visible: root.renamingFile !== modelData.name
                                        text: modelData.name
                                        width: fileArea.width - 200
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                        color: Colors.foreground
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                        height: 30
                                    }

                                    TextInput {
                                        visible: root.renamingFile === modelData.name
                                        width: fileArea.width - 200
                                        text: modelData.name
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                        color: Colors.foreground
                                        height: 26
                                        verticalAlignment: TextInput.AlignVCenter
                                        onVisibleChanged: if (visible) { forceActiveFocus(); selectAll() }
                                        Keys.onReturnPressed: root.renameFile(modelData.name, text)
                                        Keys.onEscapePressed: root.renamingFile = ""
                                    }
                                }

                                Text {
                                    anchors { right: parent.right; rightMargin: 90; verticalCenter: parent.verticalCenter }
                                    text: root.formatSize(modelData.size, modelData.isDir)
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                                    color: Colors.color8
                                    width: 65; horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    text: modelData.date ? modelData.date.substring(5) : ""
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                                    color: Colors.color8
                                    width: 70; horizontalAlignment: Text.AlignRight
                                }

                                MouseArea {
                                    id: itemMa; anchors.fill: parent; hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            root.selectedFile = modelData.name
                                            ctxMenu.targetName  = modelData.name
                                            ctxMenu.targetPath  = root.currentPath + "/" + modelData.name
                                            ctxMenu.targetIsDir = modelData.isDir
                                            var pos = mapToItem(fileArea, mouse.x, mouse.y)
                                            ctxMenu.x = Math.min(pos.x, fileArea.width - ctxMenu.width - 4)
                                            ctxMenu.y = Math.min(pos.y, fileArea.height - ctxMenu.height - 4)
                                            ctxMenu.visible = true
                                        } else {
                                            root.selectedFile = modelData.name
                                            ctxMenu.visible = false
                                        }
                                    }
                                    onDoubleClicked: {
                                        if (modelData.isDir)
                                            root.navigate(root.currentPath + "/" + modelData.name)
                                        else
                                            root.openFile(root.currentPath + "/" + modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }

                // Context menu popup
                Rectangle {
                    id: ctxMenu
                    visible: false
                    z: 100
                    width: 180
                    height: ctxCol.implicitHeight + 8
                    radius: 8
                    color: Qt.darker(Colors.background, 1.12)
                    border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.3)
                    border.width: 1

                    property string targetName:  ""
                    property string targetPath:  ""
                    property bool   targetIsDir: false

                    Column {
                        id: ctxCol
                        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 4 }

                        Repeater {
                            model: [
                                { text: "Open",        sep: false, action: "open",   danger: false },
                                { text: "",            sep: true,  action: "",        danger: false },
                                { text: "Copy",        sep: false, action: "copy",   danger: false },
                                { text: "Cut",         sep: false, action: "cut",    danger: false },
                                { text: "Paste",       sep: false, action: "paste",  danger: false },
                                { text: "",            sep: true,  action: "",        danger: false },
                                { text: "Rename  F2",  sep: false, action: "rename", danger: false },
                                { text: "Delete  Del", sep: false, action: "delete", danger: true  },
                            ]
                            delegate: Item {
                                required property var modelData
                                width: ctxMenu.width
                                height: modelData.sep ? 9 : 28

                                Rectangle {
                                    visible: modelData.sep
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                                    height: 1
                                    color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.25)
                                }

                                Rectangle {
                                    visible: !modelData.sep
                                    anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                    radius: 4
                                    color: menuItemMa.containsMouse
                                        ? (modelData.danger
                                            ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.15)
                                            : Qt.lighter(Colors.background, 1.4))
                                        : "transparent"
                                    Behavior on color { ColorAnimation { duration: 60 } }

                                    Text {
                                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                                        text: modelData.text
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                        color: modelData.danger ? Colors.color1 : Colors.foreground
                                        opacity: modelData.action === "paste" && root.clipboardFile === "" ? 0.4 : 1.0
                                    }

                                    MouseArea {
                                        id: menuItemMa; anchors.fill: parent; hoverEnabled: true
                                        enabled: !(modelData.action === "paste" && root.clipboardFile === "")
                                        onClicked: {
                                            ctxMenu.visible = false
                                            const t = ctxMenu.targetName
                                            const p = ctxMenu.targetPath
                                            const d = ctxMenu.targetIsDir
                                            if (modelData.action === "open") {
                                                if (d) root.navigate(p); else root.openFile(p)
                                            } else if (modelData.action === "copy") {
                                                root.clipboardFile = p; root.clipboardCut = false
                                            } else if (modelData.action === "cut") {
                                                root.clipboardFile = p; root.clipboardCut = true
                                            } else if (modelData.action === "paste") {
                                                root.pasteClipboard()
                                            } else if (modelData.action === "rename") {
                                                root.renamingFile = t
                                            } else if (modelData.action === "delete") {
                                                root.selectedFile = t; root.deleteSelected()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Status bar ---
        Rectangle {
            id: statusBar
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 26
            color: Qt.darker(Colors.background, 1.1)
            radius: 10

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 10
                color: parent.color
            }

            Row {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.filteredItems.length + " item" + (root.filteredItems.length !== 1 ? "s" : "")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                    color: Colors.color8
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedFile
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                    color: Colors.foreground
                    elide: Text.ElideMiddle
                    width: 280
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.clipboardFile !== ""
                    text: (root.clipboardCut ? " cut: " : " copy: ") + root.clipboardFile.split("/").pop()
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                    color: root.clipboardCut ? Colors.color3 : Colors.color2
                }
            }
        }

        // Dismiss context menu on background click
        MouseArea {
            anchors.fill: parent
            z: -1
            propagateComposedEvents: true
            onClicked: function(mouse) {
                ctxMenu.visible = false
                root.selectedFile = ""
                root.renamingFile = ""
                mouse.accepted = false
            }
        }
    }

    // Backdrop - click outside window to close
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.visible = false
    }
}
