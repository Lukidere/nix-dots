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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1

    // --- State ---
    readonly property string homeDir: _normPath(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    property string currentPath:  homeDir
    property var    items:         []
    property string searchText:    ""
    property string pathError:     ""
    property string opError:       ""
    property bool   showHidden:    false
    property string selectedFile:  ""
    property string renamingFile:  ""
    property string clipboardFile: ""
    property bool   clipboardCut:  false
    property var    history:       []
    property int    historyIndex:  -1
    property string sortBy:        "name"
    property bool   sortAsc:       true
    property int    _lsSerial:     0
    property bool   _pendingNewFolderRename: false
    property var    bookmarks: [
        { name: "Home", path: homeDir, icon: "\uf015" },
    ]

    // sidebar lists only dirs that exist - checked once at startup
    readonly property Process _bmProc: Process {
        command: ["sh", "-c", 'for d in Documents Downloads Music Pictures Videos; do [ -d "$HOME/$d" ] && echo "$d"; done; true']
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const icons = {
                    Documents: "\uf15c", Downloads: "\uf019", Music: "\uf001",
                    Pictures: "\uf03e", Videos: "\uf008"
                }
                const bms = [{ name: "Home", path: root.homeDir, icon: "\uf015" }]
                for (const d of this.text.trim().split("\n").filter(Boolean))
                    bms.push({ name: d, path: root.homeDir + "/" + d, icon: icons[d] || "\uf07b" })
                root.bookmarks = bms
            }
        }
    }

    readonly property var filteredItems: {
        if (!searchText) return items
        const q = searchText.toLowerCase()
        return items.filter(function(f) { return f.name.toLowerCase().includes(q) })
    }

    // --- FIFO trigger ---
    readonly property string _fifoPath: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-fm"
    readonly property Process _setup: Process {
        command: ["sh", "-c", "rm -f " + JSON.stringify(root._fifoPath) + "; mkfifo " + JSON.stringify(root._fifoPath)]
        running: true
        stdout: StdioCollector { onStreamFinished: root._reader.running = true }
    }
    readonly property Process _reader: Process {
        running: false
        command: ["sh", "-c", "read -r _ < " + JSON.stringify(root._fifoPath)]
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
                const serial = root._lastSerial
                const raw = this.text.trim()
                if (raw === "__NOTFOUND__") {
                    if (serial === root._lsSerial) {
                        root.items = []
                        root.pathError = "Directory not found: " + root.currentPath
                    }
                    return
                }
                if (serial !== root._lsSerial) return
                root.pathError = ""
                const lines = raw.split("\n")
                const list = []
                lines.forEach(function(line) {
                    if (!line) return
                    const parts = line.split("\t")
                    if (parts.length < 5) return
                    // fields: type, name(may contain tabs), size, date, perms
                    const name = parts.slice(1, parts.length - 3).join("\t")
                    if (!root.showHidden && name.startsWith(".")) return
                    list.push({
                        type:  parts[0],
                        name:  name,
                        size:  parseInt(parts[parts.length - 3]) || 0,
                        date:  parts[parts.length - 2] || "",
                        perms: parts[parts.length - 1] || "",
                        isDir: parts[0] === "d",
                        isLink: parts[0] === "l"
                    })
                })
                list.sort(function(a, b) {
                    if (a.isDir !== b.isDir) return a.isDir ? -1 : 1
                    if (root.sortBy === "size") return root.sortAsc ? (a.size - b.size) : (b.size - a.size)
                    if (root.sortBy === "date") return root.sortAsc
                        ? a.date.localeCompare(b.date)
                        : b.date.localeCompare(a.date)
                    return root.sortAsc
                        ? a.name.toLowerCase().localeCompare(b.name.toLowerCase())
                        : b.name.toLowerCase().localeCompare(a.name.toLowerCase())
                })
                root.items = list
                if (root._pendingNewFolderRename) {
                    root._pendingNewFolderRename = false
                    for (let i = 0; i < list.length; i++) {
                        if (list[i].name === "New Folder") {
                            root.selectedFile = "New Folder"
                            root.renamingFile = "New Folder"
                            break
                        }
                    }
                }
            }
        }
    }
    property int _lastSerial: 0

    // --- File operations ---
    Process {
        id: _opProc
        running: false
        onRunningChanged: {
            if (!running) {
                if (exitCode !== 0) {
                    root.opError = "Operation failed (exit " + exitCode + ")"
                    root._pendingNewFolderRename = false
                } else
                    root.refresh()
                if (root.opError !== "") {
                    errorClearTimer.restart()
                }
            }
        }
    }
    Process {
        id: _openProc
        running: false
    }
    Process {
        id: _termProc
        running: false
    }
    Timer {
        id: errorClearTimer
        interval: 5000
        onTriggered: root.opError = ""
    }

    // --- Helper functions ---
    function _normPath(p) {
        const s = String(p)
        if (s.startsWith("file://")) return s.slice(7)
        return s
    }

    function _refocus() { keyHandler.forceActiveFocus() }

    function refresh() {
        root._lsSerial++
        root._lastSerial = root._lsSerial
        _lsProc.command = ["sh", "-c",
            "[ -d \"$1\" ] && find \"$1\" -maxdepth 1 -mindepth 1 -printf '%y\\t%f\\t%s\\t%TY-%Tm-%Td\\t%M\\n' 2>/dev/null || echo __NOTFOUND__",
            "_", root.currentPath
        ]
        _lsProc.running = false
        _lsProc.running = true
    }

    function navigate(path) {
        const p = _normPath(path)
        if (historyIndex < history.length - 1)
            history = history.slice(0, historyIndex + 1)
        history = history.concat([p])
        historyIndex = history.length - 1
        currentPath = p
        selectedFile = ""
        renamingFile = ""
    }

    function goBack() {
        if (historyIndex > 0) { historyIndex--; currentPath = history[historyIndex]; selectedFile = ""; renamingFile = "" }
    }
    function goForward() {
        if (historyIndex < history.length - 1) { historyIndex++; currentPath = history[historyIndex]; selectedFile = ""; renamingFile = "" }
    }
    function goUp() {
        const parts = currentPath.split("/").filter(p => p !== "")
        if (parts.length > 0) {
            parts.pop()
            navigate(parts.length === 0 ? "/" : "/" + parts.join("/"))
        }
    }

    function openFile(path) {
        _openProc.command = ["xdg-open", path]
        _openProc.running = false; _openProc.running = true
    }
    function deleteSelected() {
        if (!root.selectedFile) return
        deleteConfirmDialog.targetPath = root.currentPath + "/" + root.selectedFile
        deleteConfirmDialog.visible = true
    }
    function renameFile(oldName, newName) {
        if (!newName || newName === oldName) { root.renamingFile = ""; return }
        _opProc.command = ["mv", "--",
            root.currentPath + "/" + oldName,
            root.currentPath + "/" + newName
        ]
        root.renamingFile = ""
        _opProc.running = false; _opProc.running = true
    }
    function pasteClipboard() {
        if (!root.clipboardFile) return
        const src  = root.clipboardFile
        const dest = root.currentPath + "/"
        if (root.clipboardCut) {
            _opProc.command = ["mv", "--", src, dest]
        } else {
            _opProc.command = ["cp", "-r", "--", src, dest]
        }
        root.clipboardFile = ""
        _opProc.running = false; _opProc.running = true
    }
    function newFolder() {
        root._pendingNewFolderRename = true
        _opProc.command = ["mkdir", "-p", "--", root.currentPath + "/New Folder"]
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
    onVisibleChanged: { if (visible) { _refocus(); renamingFile = "" } }

    Component.onCompleted: {
        history = [currentPath]
        historyIndex = 0
    }

    // --- Dedicated key handler (focus lives here) ---
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (deleteConfirmDialog.visible) { deleteConfirmDialog.visible = false; keyHandler.forceActiveFocus(); return }
            if (root.renamingFile !== "") { root.renamingFile = ""; return }
            if (ctxMenu.visible) { ctxMenu.visible = false; return }
            root.visible = false
        }
        Keys.onPressed: function(ev) {
            const ctrl = ev.modifiers & Qt.ControlModifier
            if (ev.key === Qt.Key_F2 && root.selectedFile && root.renamingFile === "") {
                root.renamingFile = root.selectedFile; ev.accepted = true; return
            }
            if (ev.key === Qt.Key_Delete && root.selectedFile && root.renamingFile === "") {
                root.deleteSelected(); ev.accepted = true; return
            }
            if (ctrl && ev.key === Qt.Key_C && root.selectedFile) {
                root.clipboardFile = root.currentPath + "/" + root.selectedFile
                root.clipboardCut = false; ev.accepted = true; return
            }
            if (ctrl && ev.key === Qt.Key_X && root.selectedFile) {
                root.clipboardFile = root.currentPath + "/" + root.selectedFile
                root.clipboardCut = true; ev.accepted = true; return
            }
            if (ctrl && ev.key === Qt.Key_V) {
                root.pasteClipboard(); ev.accepted = true; return
            }
            if (ctrl && ev.key === Qt.Key_L) {
                pathInput.forceActiveFocus(); pathInput.selectAll(); ev.accepted = true; return
            }
            if (ctrl && ev.key === Qt.Key_F) {
                searchInput.forceActiveFocus(); ev.accepted = true; return
            }
            if (ctrl && ev.key === Qt.Key_N) {
                root.newFolder(); ev.accepted = true; return
            }
            if (ctrl && ev.key === Qt.Key_T) {
                const term = Quickshell.env("TERMINAL") || "kitty"
                _termProc.command = [term]
                _termProc.workingDirectory = root.currentPath
                _termProc.running = false; _termProc.running = true
                ev.accepted = true; return
            }
            if (ev.key === Qt.Key_Up && !pathInput.activeFocus && !searchInput.activeFocus && root.renamingFile === "") {
                if (root.filteredItems.length === 0) return
                const idx = root.filteredItems.findIndex(f => f.name === root.selectedFile)
                if (idx > 0) {
                    root.selectedFile = root.filteredItems[idx - 1].name
                    ev.accepted = true
                } else if (idx === -1 && root.filteredItems.length > 0) {
                    root.selectedFile = root.filteredItems[root.filteredItems.length - 1].name
                    ev.accepted = true
                }
                return
            }
            if (ev.key === Qt.Key_Down && !pathInput.activeFocus && !searchInput.activeFocus && root.renamingFile === "") {
                if (root.filteredItems.length === 0) return
                const idx = root.filteredItems.findIndex(f => f.name === root.selectedFile)
                if (idx >= 0 && idx < root.filteredItems.length - 1) {
                    root.selectedFile = root.filteredItems[idx + 1].name
                    ev.accepted = true
                } else if (idx === -1 && root.filteredItems.length > 0) {
                    root.selectedFile = root.filteredItems[0].name
                    ev.accepted = true
                }
                return
            }
            if (ev.key === Qt.Key_Return && root.selectedFile && !pathInput.activeFocus && !searchInput.activeFocus && root.renamingFile === "") {
                if (deleteConfirmDialog.visible) return
                const item = root.items.find(f => f.name === root.selectedFile)
                if (item) {
                    if (item.isDir)
                        root.navigate(root.currentPath + "/" + item.name)
                    else
                        root.openFile(root.currentPath + "/" + item.name)
                    ev.accepted = true
                }
                return
            }
            if (ev.key === Qt.Key_Backspace && !pathInput.activeFocus && !searchInput.activeFocus) {
                root.goBack(); ev.accepted = true; return
            }
        }
    }

    // --- Backdrop: click outside to close ---
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    // --- Main window ---
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
            onClicked: {
                ctxMenu.visible = false
                root.selectedFile = ""
                root.renamingFile = ""
                root._refocus()
            }
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
                height: 10; color: parent.color
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
                        color: navMa.containsMouse && modelData.enabled ? Qt.lighter(Colors.background, 1.4) : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                        opacity: modelData.enabled ? 1.0 : 0.3
                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: Colors.foreground
                        }
                        MouseArea {
                            id: navMa; anchors.fill: parent; hoverEnabled: true; enabled: modelData.enabled
                            onClicked: {
                                if      (modelData.action === "back")    root.goBack()
                                else if (modelData.action === "forward") root.goForward()
                                else if (modelData.action === "up")      root.goUp()
                                else if (modelData.action === "home")    root.navigate(root.homeDir)
                                root._refocus()
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: pathBox
                anchors {
                    left: navBtns.right; right: rightBtns.left
                    verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8
                }
                height: 28; radius: 6
                color: Qt.lighter(Colors.background, 1.3)
                border.color: pathInput.activeFocus ? Colors.color4 : "transparent"; border.width: 1
                TextInput {
                    id: pathInput
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.currentPath
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.foreground
                    clip: true
                    onAccepted: { root.navigate(text.trim()); root._refocus() }
                    Keys.onEscapePressed: { text = root.currentPath; root._refocus() }
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
                    Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 13; color: Colors.foreground }
                    MouseArea { id: nfMa; anchors.fill: parent; hoverEnabled: true; onClicked: { root.newFolder(); root._refocus() } }
                }
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: hidMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: root.showHidden ? "" : ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: root.showHidden ? Colors.color4 : Colors.color8 }
                    MouseArea { id: hidMa; anchors.fill: parent; hoverEnabled: true; onClicked: { root.showHidden = !root.showHidden; root._refocus() } }
                }
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: closeMa.containsMouse ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.2) : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: closeMa.containsMouse ? Colors.color1 : Colors.color8 }
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
                radius: 6; color: Qt.lighter(Colors.background, 1.25)
                border.color: searchInput.activeFocus ? Colors.color4 : "transparent"; border.width: 1
                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                    spacing: 8
                    Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color8 }
                    TextInput {
                        id: searchInput
                        width: searchBar.width - 90
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.foreground
                        onTextChanged: root.searchText = text
                        Keys.onEscapePressed: { text = ""; root._refocus() }
                    }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 32; verticalCenter: parent.verticalCenter }
                    visible: searchInput.text === "" && !searchInput.activeFocus
                    text: "Search in " + (root.currentPath.split("/").pop() || "/") + "..."
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.color8
                }
            }
        }

        // --- Body ---
        Rectangle {
            id: body
            anchors { top: searchBar.bottom; left: parent.left; right: parent.right; bottom: statusBar.top }
            color: "transparent"

            // Sidebar
            Rectangle {
                id: sidebar
                anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
                width: 130; color: Qt.darker(Colors.background, 1.05)
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
                                Text { text: modelData.icon; font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: Colors.color4 }
                                Text { text: modelData.name; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.foreground }
                            }
                            MouseArea {
                                id: bmHov; anchors.fill: parent; hoverEnabled: true
                                onClicked: { root.navigate(modelData.path); root._refocus() }
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

                Rectangle {
                    id: listHeader
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 24; color: Qt.darker(Colors.background, 1.08)
                    Row {
                        anchors { fill: parent; leftMargin: 42 }
                        Rectangle {
                            width: fileArea.width - 200; height: parent.height
                            color: sortNameMa.containsMouse ? Qt.lighter(Colors.background, 1.2) : "transparent"
                            Behavior on color { ColorAnimation { duration: 60 } }
                            Row {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                Text { text: "Name"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: root.sortBy === "name" ? Colors.color4 : Colors.color8; verticalAlignment: Text.AlignVCenter }
                                Text { text: root.sortBy === "name" ? (root.sortAsc ? "" : "") : ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 8; color: Colors.color4; verticalAlignment: Text.AlignVCenter }
                            }
                            MouseArea { id: sortNameMa; anchors.fill: parent; hoverEnabled: true; onClicked: { if (root.sortBy === "name") root.sortAsc = !root.sortAsc; else { root.sortBy = "name"; root.sortAsc = true } } }
                        }
                        Rectangle {
                            width: 70; height: parent.height
                            color: sortSizeMa.containsMouse ? Qt.lighter(Colors.background, 1.2) : "transparent"
                            Behavior on color { ColorAnimation { duration: 60 } }
                            Row {
                                anchors { fill: parent; rightMargin: 8 }
                                Text { text: "Size"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: root.sortBy === "size" ? Colors.color4 : Colors.color8; horizontalAlignment: Text.AlignRight; width: parent.width - 12; verticalAlignment: Text.AlignVCenter }
                                Text { text: root.sortBy === "size" ? (root.sortAsc ? "" : "") : ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 8; color: Colors.color4; width: 12; horizontalAlignment: Text.AlignCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            MouseArea { id: sortSizeMa; anchors.fill: parent; hoverEnabled: true; onClicked: { if (root.sortBy === "size") root.sortAsc = !root.sortAsc; else { root.sortBy = "size"; root.sortAsc = true } } }
                        }
                        Rectangle {
                            width: 80; height: parent.height
                            color: sortDateMa.containsMouse ? Qt.lighter(Colors.background, 1.2) : "transparent"
                            Behavior on color { ColorAnimation { duration: 60 } }
                            Row {
                                anchors { fill: parent; rightMargin: 10 }
                                Text { text: "Date"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: root.sortBy === "date" ? Colors.color4 : Colors.color8; horizontalAlignment: Text.AlignRight; width: parent.width - 12; verticalAlignment: Text.AlignVCenter }
                                Text { text: root.sortBy === "date" ? (root.sortAsc ? "" : "") : ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 8; color: Colors.color4; width: 12; horizontalAlignment: Text.AlignCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            MouseArea { id: sortDateMa; anchors.fill: parent; hoverEnabled: true; onClicked: { if (root.sortBy === "date") root.sortAsc = !root.sortAsc; else { root.sortBy = "date"; root.sortAsc = true } } }
                        }
                    }
                }

                // Error / empty state overlay
                Rectangle {
                    anchors { top: listHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                    visible: root.pathError !== "" || (root.filteredItems.length === 0 && root.pathError === "")
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: root.pathError !== ""
                            ? "  " + root.pathError
                            : "  Empty directory"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 12
                        color: root.pathError !== "" ? Colors.color1 : Colors.color8
                        opacity: 0.6
                    }
                }

                // Right-click on empty background
                MouseArea {
                    anchors { top: listHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                    z: -1
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            ctxMenu.targetName  = ""
                            ctxMenu.targetPath  = ""
                            ctxMenu.targetIsDir = false
                            ctxMenu.x = Math.min(mouse.x, fileArea.width  - ctxMenu.width  - 4)
                            ctxMenu.y = Math.min(mouse.y + listHeader.height, fileArea.height - ctxMenu.height - 4)
                            ctxMenu.visible = true
                        }
                        root._refocus()
                    }
                }

                Flickable {
                    id: fileFlick
                    anchors { top: listHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                    contentHeight: fileCol.implicitHeight
                    clip: true

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
                                opacity: (root.clipboardCut && root.clipboardFile === root.currentPath + "/" + modelData.name) ? 0.5 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 60 } }

                                Row {
                                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                    spacing: 8
                                    Text {
                                        text: root.fileIcon(modelData)
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                                        color: root.fileIconColor(modelData); width: 18
                                    }
                                    Text {
                                        visible: root.renamingFile !== modelData.name
                                        text: modelData.name; width: fileArea.width - 200
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.foreground
                                        elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter; height: 30
                                    }
                                    TextInput {
                                        visible: root.renamingFile === modelData.name
                                        width: fileArea.width - 200; text: modelData.name
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.foreground
                                        height: 26; verticalAlignment: TextInput.AlignVCenter
                                        onVisibleChanged: if (visible) { forceActiveFocus(); selectAll() }
                                        Keys.onReturnPressed: { root.renameFile(modelData.name, text); root._refocus() }
                                        Keys.onEscapePressed: { root.renamingFile = ""; root._refocus() }
                                    }
                                }

                                Text {
                                    anchors { right: parent.right; rightMargin: 90; verticalCenter: parent.verticalCenter }
                                    text: root.formatSize(modelData.size, modelData.isDir)
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color8
                                    width: 65; horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    text: modelData.date ? modelData.date.substring(5) : ""
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color8
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
                                        root._refocus()
                                    }
                                    onDoubleClicked: {
                                        if (modelData.isDir)
                                            root.navigate(root.currentPath + "/" + modelData.name)
                                        else
                                            root.openFile(root.currentPath + "/" + modelData.name)
                                        root._refocus()
                                    }
                                }
                            }
                        }
                    }
                }

                // Context menu
                Rectangle {
                    id: ctxMenu
                    visible: false; z: 100
                    width: 180; height: ctxCol.implicitHeight + 8
                    radius: 8; color: Qt.darker(Colors.background, 1.12)
                    border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.3); border.width: 1

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
                                { text: "",            sep: true,  action: "",        danger: false },
                                { text: "Terminal Ctrl+T", sep: false, action: "terminal", danger: false },
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

                                    readonly property bool _disabled:
                                        (modelData.action === "paste"  && root.clipboardFile === "") ||
                                        (modelData.action === "open"   && ctxMenu.targetName === "") ||
                                        (modelData.action === "copy"   && ctxMenu.targetName === "") ||
                                        (modelData.action === "cut"    && ctxMenu.targetName === "") ||
                                        (modelData.action === "rename" && ctxMenu.targetName === "") ||
                                        (modelData.action === "delete" && ctxMenu.targetName === "")

                                    color: mima.containsMouse && !_disabled
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
                                        opacity: parent._disabled ? 0.35 : 1.0
                                    }

                                    MouseArea {
                                        id: mima; anchors.fill: parent; hoverEnabled: true
                                        enabled: !parent._disabled
                                        onClicked: {
                                            const t = ctxMenu.targetName
                                            const p = ctxMenu.targetPath
                                            const d = ctxMenu.targetIsDir
                                            ctxMenu.visible = false
                                            if      (modelData.action === "open")   { if (d) root.navigate(p); else root.openFile(p) }
                                            else if (modelData.action === "copy")   { root.clipboardFile = p; root.clipboardCut = false }
                                            else if (modelData.action === "cut")    { root.clipboardFile = p; root.clipboardCut = true }
                                            else if (modelData.action === "paste")  { root.pasteClipboard() }
                                            else if (modelData.action === "rename") { root.renamingFile = t }
                                            else if (modelData.action === "delete") { root.selectedFile = t; root.deleteSelected() }
                                            else if (modelData.action === "terminal") {
                                                const term = Quickshell.env("TERMINAL") || "kitty"
                                                _termProc.command = [term]
                                                _termProc.workingDirectory = d ? p : root.currentPath
                                                _termProc.running = false; _termProc.running = true
                                            }
                                            root._refocus()
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
            height: 26; color: Qt.darker(Colors.background, 1.1); radius: 10
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 10; color: parent.color
            }
            Row {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 16
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.opError === ""
                    text: root.filteredItems.length + " item" + (root.filteredItems.length !== 1 ? "s" : "")
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color8
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.opError !== ""
                    text: "  " + root.opError
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.opError === ""
                    text: root.selectedFile; elide: Text.ElideMiddle; width: 280
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.foreground
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.opError === "" && root.clipboardFile !== ""
                    text: (root.clipboardCut ? " cut: " : " copy: ") + root.clipboardFile.split("/").pop()
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                    color: root.clipboardCut ? Colors.color3 : Colors.color2
                }
            }
        }

        // --- Delete confirmation dialog ---
        Rectangle {
            id: deleteConfirmDialog
            visible: false; z: 200
            anchors.centerIn: parent
            width: 300; height: delCol.implicitHeight + 40
            radius: 10; color: Colors.background
            border.color: Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.3); border.width: 1
            property string targetPath: ""
            onVisibleChanged: if (visible) forceActiveFocus()

            Column {
                id: delCol
                anchors { fill: parent; margins: 20 }
                spacing: 12
                Text {
                    width: parent.width
                    text: "Move '" + deleteConfirmDialog.targetPath.split("/").pop() + "' to trash?"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: Colors.foreground
                    wrapMode: Text.Wrap
                }
                Row {
                    width: parent.width; spacing: 8
                    Rectangle {
                        width: (parent.width - 8) / 2; height: 28; radius: 4
                        color: cancelMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : Qt.darker(Colors.background, 1.1)
                        Behavior on color { ColorAnimation { duration: 60 } }
                        Text { anchors.centerIn: parent; text: "Cancel"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.foreground }
                        MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; onClicked: { deleteConfirmDialog.visible = false; root._refocus() } }
                    }
                    Rectangle {
                        width: (parent.width - 8) / 2; height: 28; radius: 4
                        color: confirmMa.containsMouse ? Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.2) : Qt.darker(Colors.background, 1.1)
                        Behavior on color { ColorAnimation { duration: 60 } }
                        Text { anchors.centerIn: parent; text: "Delete"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color1 }
                        MouseArea {
                            id: confirmMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (_opProc.running) return
                                deleteConfirmDialog.visible = false
                                _opProc.command = ["gio", "trash", "--", deleteConfirmDialog.targetPath]
                                _opProc.running = false; _opProc.running = true
                                root._refocus()
                            }
                        }
                    }
                }
            }

            Keys.onEscapePressed: { visible = false; root._refocus() }
            Keys.onReturnPressed: {
                if (_opProc.running) return
                _opProc.command = ["gio", "trash", "--", deleteConfirmDialog.targetPath]
                _opProc.running = false; _opProc.running = true
                visible = false
                root._refocus()
            }
        }
    }
}
