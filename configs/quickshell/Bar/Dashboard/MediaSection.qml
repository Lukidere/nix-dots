import QtQuick
import Quickshell.Io
import "../../Theme"

// Music tab - YT Music, horizontal: player left, browser right.
Item {
    id: root

    // Accent injected by DashboardWindow (per-tab color)
    property color accent: Colors.color4

    // Art: prefer mpv's mpris artUrl, fall back to the queued track's cover.
    // Resolve from the stable queue first so searching (which swaps yt.songs)
    // never drops the now-playing cover.
    readonly property string _queueCover: {
        if (yt.nowId === "") return ""
        const inQ = (yt.queue || []).find(x => x.id === yt.nowId)
        if (inQ) return inQ.cover
        const inS = yt.songs.find(x => x.id === yt.nowId)
        return inS ? inS.cover : ""
    }
    readonly property string _art: yt.mpvArt !== "" ? yt.mpvArt : _queueCover
    // Exposed for ambient-art consumers in DashboardWindow
    property string artUrl: _art

    function fmtTime(s) {
        const m = Math.floor(s / 60)
        const ss = Math.floor(s % 60)
        return m + ":" + (ss < 10 ? "0" : "") + ss
    }

    readonly property var yt: YtMusicState

    property string ytBrowse: "search"  // search, playlists, liked
    property string ytView: "browse"    // browse, tracks

    // ── Discord rich presence toggle (systemd user service `discord-rpc`) ──
    property bool rpcActive: false
    Process {
        id: _rpcState; command: ["systemctl","--user","is-active","discord-rpc"]; running: true
        stdout: StdioCollector { onStreamFinished: root.rpcActive = this.text.trim() === "active" }
    }
    Process { id: _rpcToggle; running: false
        onExited: { _rpcState.running = false; _rpcState.running = true } }
    Timer { interval: 5000; running: true; repeat: true
        onTriggered: { _rpcState.running = false; _rpcState.running = true } }
    function toggleRpc() {
        _rpcToggle.command = ["systemctl","--user", root.rpcActive ? "stop" : "start", "discord-rpc"]
        _rpcToggle.running = false; _rpcToggle.running = true
    }

    Row {
        anchors.fill: parent
        spacing: 14
        visible: yt.configured

        // ── Left: player ────────────────────────────────────────────
        Column {
            id: playerCol
            width: Math.round((parent.width - 14) * 0.38)
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter

            // Discord rich presence toggle
            Rectangle {
                width: parent.width; height: 26; radius: 8
                color: rpcMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.25)
                Behavior on color { ColorAnimation { duration: 100 } }
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text {
                        text: "\u{F066F}"; font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                        color: root.rpcActive ? "#5865F2" : Colors.color8
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: root.rpcActive ? "Discord RPC on" : "Discord RPC off"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                        color: root.rpcActive ? Colors.foreground : Colors.color8
                    }
                }
                MouseArea { id: rpcMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggleRpc() }
            }

            Item {
                width: parent.width
                height: width

                Rectangle {
                    anchors.fill: artRect
                    anchors.margins: -6
                    radius: artRect.radius + 6
                    color: "transparent"; border.width: 2
                    border.color: yt.mpvStatus === "Playing"
                        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
                        : "transparent"
                    Behavior on border.color { ColorAnimation { duration: 600 } }
                }
                Rectangle {
                    id: artRect
                    anchors.fill: parent
                    anchors.margins: 10
                    radius: 12; color: Qt.lighter(Colors.background, 1.3); clip: true
                    Image {
                        id: artImg
                        anchors.fill: parent
                        source: root._art !== "" && (root._art.startsWith("file://") || root._art.startsWith("http")) ? root._art : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 512; sourceSize.height: 512
                        smooth: true; mipmap: true; asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent; text: "\uF001"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 48
                        color: Colors.color8; visible: artImg.status !== Image.Ready
                    }
                }
            }

            Column {
                width: parent.width; spacing: 3
                Text {
                    width: parent.width
                    text: yt.mpvTitle !== "" ? yt.mpvTitle : "Nothing playing"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 14; font.bold: true
                    color: yt.mpvTitle !== "" ? Colors.foreground : Colors.color8
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width
                    text: yt.mpvArtist
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.color8; elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: yt.mpvArtist !== ""
                }
            }

            // Track progress
            Column {
                width: parent.width; spacing: 3
                visible: yt.mpvDuration > 0
                Item {
                    width: parent.width; height: 14
                    Rectangle {
                        id: barTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 4; radius: 2
                        color: Qt.lighter(Colors.background, 1.4)
                        Rectangle {
                            width: parent.width * Math.min(1, yt.mpvPosition / Math.max(1, yt.mpvDuration))
                            height: 4; radius: 2; color: root.accent
                            Behavior on width { NumberAnimation { duration: seekMa.pressed ? 0 : 500 } }
                        }
                    }
                    MouseArea {
                        id: seekMa
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onPressed: e => yt.seek(Math.max(0, Math.min(1, e.x / width)) * yt.mpvDuration)
                        onPositionChanged: e => { if (pressed) yt.seek(Math.max(0, Math.min(1, e.x / width)) * yt.mpvDuration) }
                    }
                }
                Item {
                    width: parent.width; height: 12
                    Text { anchors.left: parent.left; text: root.fmtTime(yt.mpvPosition); font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8 }
                    Text { anchors.right: parent.right; text: root.fmtTime(yt.mpvDuration); font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8 }
                }
            }

            Row {
                id: ctlRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                // derive button size from the column width so the row never
                // overflows onto the left panel (5 buttons, the play btn +10)
                readonly property int base: Math.max(24, Math.min(34, Math.floor((playerCol.width - 10 - 4 * spacing) / 5)))
                Repeater {
                    // 0 prev - 1 play/pause - 2 next - 3 loop - 4 stop
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        readonly property bool _loopOn: index === 3 && yt.loopMode !== "None"
                        width: index === 1 ? ctlRow.base + 10 : ctlRow.base
                        height: index === 1 ? ctlRow.base + 10 : ctlRow.base
                        radius: width / 2
                        color: index === 1
                            ? (ytCtlMa.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent)
                            : _loopOn ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                            : (ytCtlMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.25))
                        Behavior on color { ColorAnimation { duration: 100 } }
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: index === 0 ? "" : index === 1 ? (yt.mpvStatus === "Playing" ? "" : "") : index === 2 ? "" : index === 3 ? "" : ""
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: index === 1 ? 15 : 12
                            color: index === 1 ? Colors.background
                                 : parent._loopOn ? root.accent : Colors.foreground
                        }
                        Text {
                            visible: index === 3 && yt.loopMode === "Track"
                            anchors { right: parent.right; top: parent.top; rightMargin: 5; topMargin: 3 }
                            text: "1"; font.family: "Iosevka Nerd Font"; font.pixelSize: 7; font.bold: true
                            color: root.accent
                        }
                        MouseArea {
                            id: ytCtlMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (index === 0) yt.previous()
                                else if (index === 1) yt.playPause()
                                else if (index === 2) yt.next()
                                else if (index === 3) yt.cycleLoop()
                                else yt.stop()
                            }
                        }
                    }
                }
            }
        }

        // ── Right: browser ──────────────────────────────────────────
        Column {
            width: parent.width - playerCol.width - 14
            height: parent.height
            spacing: 8

            // Category pills
            Row {
                width: parent.width; spacing: 4
                Repeater {
                    model: [{k: "search", l: "Search"}, {k: "queue", l: "Queue"}, {k: "playlists", l: "Playlists"}, {k: "liked", l: "Liked"}]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 12) / 4; height: 24; radius: 6
                        color: root.ytBrowse === modelData.k ? root.accent
                             : catMa.containsMouse ? Qt.lighter(Colors.background, 1.5)
                             : Qt.lighter(Colors.background, 1.3)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: modelData.l
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                            color: root.ytBrowse === modelData.k ? Colors.background : Colors.foreground
                        }
                        MouseArea {
                            id: catMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                root.ytBrowse = modelData.k
                                root.ytView = "browse"
                                if (modelData.k === "playlists") yt.getPlaylists()
                                else if (modelData.k === "liked") { yt.getLiked(); root.ytView = "tracks" }
                                else if (modelData.k === "queue") root.ytView = "tracks"
                                else ytSearchInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // Search field
            Rectangle {
                width: parent.width; height: 30; radius: 6
                visible: root.ytBrowse === "search"
                color: Qt.lighter(Colors.background, 1.3)
                border.color: ytSearchInput.activeFocus ? root.accent : "transparent"; border.width: 1
                TextInput {
                    id: ytSearchInput
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.foreground; clip: true
                    // launcher feel: results update as you type (debounced)
                    onTextChanged: _searchDebounce.restart()
                    onAccepted: { _searchDebounce.stop(); yt.search(text); root.ytView = "tracks" }
                }
                Timer {
                    id: _searchDebounce; interval: 320
                    onTriggered: if (ytSearchInput.text.trim() !== "") { yt.search(ytSearchInput.text); root.ytView = "tracks" }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "Search YT Music…"; font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.color8; visible: ytSearchInput.text === "" && !ytSearchInput.activeFocus
                }
            }

            // Loading / error line
            Text {
                width: parent.width
                visible: yt.loading || yt.error !== ""
                text: yt.loading ? "Loading…" : yt.error
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: yt.error !== "" ? Colors.color1 : Colors.color8
                elide: Text.ElideRight
            }

            // Content list
            Flickable {
                width: parent.width
                height: parent.height - y - (backBtn.visible ? 30 : 0)
                contentHeight: listCol.implicitHeight; clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listCol; width: parent.width; spacing: 2

                    // Playlists view
                    Repeater {
                        model: root.ytBrowse === "playlists" && root.ytView === "browse" ? yt.playlists : []
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width; height: 32; radius: 6
                            color: plMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "\u{F0CB9}  " + modelData.title + (modelData.count !== "" ? " (" + modelData.count + ")" : "")
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.foreground
                            }
                            MouseArea { id: plMa; anchors.fill: parent; hoverEnabled: true
                                onClicked: { yt.getPlaylist(modelData.id); root.ytView = "tracks" }
                            }
                        }
                    }

                    // Track list (search results, playlist tracks, liked, queue)
                    Repeater {
                        model: root.ytBrowse === "queue" ? yt.queue
                             : ((root.ytBrowse === "search" || root.ytView === "tracks") ? yt.songs : [])
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: parent.width; height: 36; radius: 6
                            color: yt.nowId === modelData.id ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                                 : songMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Row {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 58 }
                                spacing: 8
                                Image {
                                    width: 26; height: 26; anchors.verticalCenter: parent.verticalCenter
                                    source: modelData.cover; sourceSize.width: 64; sourceSize.height: 64
                                    fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: modelData.title; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: yt.nowId === modelData.id ? root.accent : Colors.foreground; elide: Text.ElideRight; width: Math.max(60, listCol.width - 110) }
                                    Text { text: modelData.artist; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8; elide: Text.ElideRight; width: Math.max(60, listCol.width - 110); visible: modelData.artist !== "" }
                                }
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 30; verticalCenter: parent.verticalCenter }
                                text: root.fmtTime(modelData.duration)
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8
                            }
                            // add-to-queue button
                            Rectangle {
                                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                width: 22; height: 22; radius: 11
                                visible: root.ytBrowse !== "queue"
                                color: addMa.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent; text: "\u{F0415}"
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                                    color: addMa.containsMouse ? root.accent : Colors.color8
                                }
                                MouseArea { id: addMa; anchors.fill: parent; hoverEnabled: true
                                    onClicked: yt.enqueue(modelData) }
                            }
                            MouseArea { id: songMa; anchors.fill: parent; anchors.rightMargin: 28; hoverEnabled: true
                                // search: play just this song (build the queue with +);
                                // playlists/liked/queue: play the whole list from here
                                onClicked: {
                                    if (root.ytBrowse === "search") yt.playQueue([modelData], 0)
                                    else yt.playQueue(root.ytBrowse === "queue" ? yt.queue : yt.songs, index)
                                }
                            }
                        }
                    }
                }
            }

            // Back button for playlist track view
            Rectangle {
                id: backBtn
                width: 60; height: 24; radius: 6
                visible: root.ytView === "tracks" && root.ytBrowse === "playlists"
                color: backMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.3)
                Text { anchors.centerIn: parent; text: "\u{F0141} Back"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.foreground }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; onClicked: { root.ytView = "browse"; yt.getPlaylists() } }
            }
        }
    }

    // Not configured message
    Column {
        width: parent.width; spacing: 8
        visible: !yt.configured
        Text { text: "YT Music not configured"; font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true; color: Colors.foreground }
        Text {
            width: parent.width; wrapMode: Text.WordWrap
            text: "1. Run:  ytmusicapi browser\n2. Paste request headers from an authenticated music.youtube.com tab\n3. Save to ~/.config/qs-ytmusic/browser.json"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color8
        }
        Rectangle {
            width: 90; height: 26; radius: 6; color: root.accent
            Text { anchors.centerIn: parent; text: "Re-check"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.background }
            MouseArea { anchors.fill: parent; onClicked: yt.checkStatus() }
        }
    }
}
