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

    property var allApps: []
    Settings {
        id: appUsage
        category: "QuickshellLauncher"
        property string usageData: "{}"
    }
    // ── FIFO toggle ───────────────────────────────────────────────────────────
    // Create FIFO, then start reader. Restart reader after each toggle.
    readonly property Process _setup: Process {
        command: ["sh", "-c", "rm -f /run/user/1000/qs-launcher; mkfifo /run/user/1000/qs-launcher"]
        running: true
        stdout: StdioCollector { onStreamFinished: root._reader.running = true }
    }

    readonly property Process _reader: Process {
        running: false
        command: ["sh", "-c", "read -r _ < /run/user/1000/qs-launcher"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.visible = !root.visible
                root._reader.running = false
                root._reader.running = true
            }
        }
    }

    // ── App loader (Python parses XDG desktop files) ──────────────────────────
    readonly property Process _appLoader: Process {
        command: ["python3", "/tmp/qs-apps.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.allApps = JSON.parse(this.text).map(a => ({
                        name: a.n, genericName: a.g || "", icon: a.i || "",
                        exec: a.e || "", desktopId: a.d
                    }))
                } catch(e) {}
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""
            resultsList.currentIndex = 0
            filterApps("")
            searchInput.forceActiveFocus()
        }
    }

    function filterApps(query) {
        combinedModel.clear()
        const q = query.toLowerCase().trim()
        
        // <-- DODANE: Pobranie historii użycia
        let usage = {}
        try { usage = JSON.parse(appUsage.usageData || "{}") } catch(e) {}

        // Zbieramy wszystkie pasujące aplikacje
        let hits = q === ""
            ? allApps.slice()
            : allApps.filter(a =>
                a.name.toLowerCase().includes(q) ||
                a.genericName.toLowerCase().includes(q)
              )
              
        // <-- DODANE: Sortowanie według popularności (malejąco)
        hits.sort((a, b) => {
            let countA = usage[a.desktopId] || 0
            let countB = usage[b.desktopId] || 0
            return countB - countA
        })

        // Ucinamy wyniki dopiero po posortowaniu
        hits = hits.slice(0, q === "" ? 8 : 6)

        hits.forEach((a, i) => {
            const ic = a.icon
            combinedModel.append({
                label: a.name, sub: a.genericName,
                iconSrc: ic.includes("/") ? ic : "image://theme/" + (ic || "application-x-executable"),
                kind: "app", appIdx: allApps.indexOf(a),
                desktopId: a.desktopId,
                exec: a.exec
            })
        })
        
        if (q.length >= 2) {
            fdProc.running = false
            fdProc.command = ["fd","--max-depth","4","--type","f",q,"/home/dhm"]
            fdProc.running = true
        }
        resultsList.currentIndex = 0
    }
    function launchItem(idx) {
        if (idx < 0 || idx >= combinedModel.count) return
        const item = combinedModel.get(idx)
        
        if (item.kind === "app") {
            // <-- DODANE: Aktualizacja licznika kliknięć
            let usage = {}
            try { usage = JSON.parse(appUsage.usageData || "{}") } catch(e) {}
            usage[item.desktopId] = (usage[item.desktopId] || 0) + 1
            appUsage.usageData = JSON.stringify(usage)
            
            const exec = item.exec.replace(/%[uUfFdDnNickvm]/g, "").trim()
            launchProc.command = ["sh", "-c", exec + " &"]
            launchProc.running = false; launchProc.running = true
        } else {
            launchProc.command = ["sh", "-c", "xdg-open " + JSON.stringify(item.filePath) + " &"]
            launchProc.running = false; launchProc.running = true
        }
        root.visible = false
    }

    // ── Click outside to close ────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    // ── Launcher box ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width: 580; height: 500
        color: Colors.background
        radius: 12
        MouseArea { anchors.fill: parent }

        Column {
            anchors { fill: parent; margins: 14 }
            spacing: 10

            Rectangle {
                width: parent.width; height: 46
                radius: 10
                color: Qt.lighter(Colors.background, 1.3)
                border.color: searchInput.activeFocus ? Colors.color4 : "transparent"
                border.width: 2
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Row {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uF002"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                        color: Colors.color8
                    }
                    TextInput {
                        id: searchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 34
                        font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                        color: Colors.foreground
                        selectionColor: Colors.color4
                        onTextChanged: filterApps(text)
                        Keys.onUpPressed:     { resultsList.currentIndex = Math.max(0, resultsList.currentIndex - 1); event.accepted = true }
                        Keys.onDownPressed:   { resultsList.currentIndex = Math.min(resultsList.count - 1, resultsList.currentIndex + 1); event.accepted = true }
                        Keys.onReturnPressed: { launchItem(resultsList.currentIndex); event.accepted = true }
                        Keys.onEnterPressed:  { launchItem(resultsList.currentIndex); event.accepted = true }
                        Keys.onEscapePressed: { root.visible = false; event.accepted = true }
                    }
                }
            }

            ListView {
                id: resultsList
                width: parent.width
                height: parent.height - 56
                clip: true; model: combinedModel; spacing: 2; currentIndex: 0
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: resultsList.width; height: 50; radius: 8
                    color: resultsList.currentIndex === index ? Colors.color4
                         : (itemMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent")
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Row {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 12
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28; height: 28; smooth: true; mipmap: true
                            source: modelData.iconSrc || "image://theme/application-x-executable"
                            fillMode: Image.PreserveAspectFit
                            onStatusChanged: if (status === Image.Error) source = "image://theme/application-x-executable"
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text {
                                text: modelData.label || ""
                                font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                                color: resultsList.currentIndex === index ? Colors.background : Colors.foreground
                            }
                            Text {
                                text: modelData.sub || ""; font.pixelSize: 11
                                color: resultsList.currentIndex === index ? Qt.lighter(Colors.background,1.6) : Colors.color8
                                visible: (modelData.sub || "") !== ""
                            }
                        }
                    }
                    MouseArea {
                        id: itemMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: launchItem(index)
                        onEntered: resultsList.currentIndex = index
                    }
                }
            }
        }
    }

    ListModel { id: combinedModel }

    readonly property Process fdProc: Process {
        id: fdProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                for (let i = combinedModel.count - 1; i >= 0; i--)
                    if (combinedModel.get(i).kind === "file") combinedModel.remove(i)
                const iconMap = {
                    "png":"image-x-generic","jpg":"image-x-generic","jpeg":"image-x-generic",
                    "mp3":"audio-x-generic","flac":"audio-x-generic","mp4":"video-x-generic",
                    "mkv":"video-x-generic","pdf":"application-pdf",
                    "md":"text-x-generic","txt":"text-plain","zip":"package-x-generic"
                }
                this.text.trim().split("\n").filter(Boolean).slice(0, 5).forEach(path => {
                    const name = path.split("/").pop()
                    const ext  = name.includes(".") ? name.split(".").pop().toLowerCase() : ""
                    combinedModel.append({
                        label: name, sub: path.replace("/home/dhm","~"),
                        iconSrc: "image://theme/" + (iconMap[ext] || (ext ? "text-x-generic" : "folder")),
                        kind: "file", appIdx: -1, filePath: path
                    })
                })
            }
        }
    }

    Process { id: launchProc; running: false }
}
