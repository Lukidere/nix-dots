import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root

    property int mode: 0  // 0 = MPRIS, 1 = Navidrome

    // Exposed for ambient-art consumers in DashboardWindow
    property string artUrl: root.mpArtUrl

    // ── MPRIS state ─────────────────────────────────────────────────
    property string mpStatus:   "Stopped"
    property string mpTitle:    "Nothing playing"
    property string mpArtist:   ""
    property string mpAlbum:    ""
    property string mpArtUrl:   ""
    property real   mpPosition: 0
    property real   mpDuration: 0

    readonly property Process _metaProc: Process {
        command: ["sh", "-c",
            "playerctl status 2>/dev/null; echo '---';" +
            "playerctl metadata --format '{{title}}|{{artist}}|{{album}}|{{mpris:artUrl}}|{{mpris:length}}' 2>/dev/null; echo '---';" +
            "playerctl position 2>/dev/null"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("---\n")
                const st = (parts[0] || "").trim()
                if (st === "Playing" || st === "Paused") root.mpStatus = st
                else root.mpStatus = "Stopped"
                if (parts.length > 1) {
                    const f = (parts[1] || "").trim().split("|")
                    root.mpTitle   = f[0] || "Unknown"
                    root.mpArtist  = f[1] || ""
                    root.mpAlbum   = f[2] || ""
                    root.mpArtUrl  = f[3] || ""
                    const len      = parseInt(f[4] || "0")
                    root.mpDuration = len > 0 ? len / 1000000 : 0
                }
                if (parts.length > 2) {
                    const p = parseFloat((parts[2] || "").trim())
                    root.mpPosition = isNaN(p) ? 0 : p
                }
            }
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: { root._metaProc.running = false; root._metaProc.running = true }
    }

    Process { id: prevProc; command: ["playerctl", "previous"]; running: false }
    Process { id: playProc; command: ["playerctl", "play-pause"]; running: false }
    Process { id: nextProc; command: ["playerctl", "next"]; running: false }

    function fmtTime(s) {
        const m = Math.floor(s / 60)
        const ss = Math.floor(s % 60)
        return m + ":" + (ss < 10 ? "0" : "") + ss
    }

    // ── Navidrome state ─────────────────────────────────────────────
    NavidromeClient { id: navi }

    property string ndBrowse: "albums"  // albums, artists, playlists, random
    property string ndView: "browse"    // browse, tracks, setup

    // ── Layout ──────────────────────────────────────────────────────
    Column {
        anchors.fill: parent; spacing: 10

        // Mode switcher: MPRIS / Navidrome
        Row {
            width: parent.width; spacing: 4
            Repeater {
                model: ["MPRIS", "Navidrome"]
                delegate: Rectangle {
                    required property int index
                    required property string modelData
                    width: (parent.width - 4) / 2; height: 28; radius: 6
                    color: root.mode === index ? Colors.color4
                         : modeMa.containsMouse ? Qt.lighter(Colors.background, 1.5)
                         : Qt.lighter(Colors.background, 1.3)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent; text: modelData
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                        color: root.mode === index ? Colors.background : Colors.foreground
                    }
                    MouseArea { id: modeMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            root.mode = index
                            if (index === 1 && !navi.configured) root.ndView = "setup"
                            else if (index === 1) root.ndView = "browse"
                        }
                    }
                }
            }
        }

        // ── MPRIS player ────────────────────────────────────────────
        Column {
            width: parent.width; spacing: 14
            visible: root.mode === 0

            Item {
                width: parent.width; height: 90
                // Glow ring — pulses when playing
                Rectangle {
                    width: 88; height: 88; radius: 12
                    anchors { left: parent.left; leftMargin: -4; verticalCenter: parent.verticalCenter }
                    color: "transparent"
                    border.width: 2
                    border.color: root.mpStatus === "Playing"
                        ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.55)
                        : "transparent"
                    Behavior on border.color { ColorAnimation { duration: 600 } }
                }

                Rectangle {
                    id: artRect
                    width: 80; height: 80
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    radius: 8; color: Qt.lighter(Colors.background, 1.3); clip: true
                    Image {
                        id: artImg; anchors.fill: parent
                        source: root.mpArtUrl !== "" && (root.mpArtUrl.startsWith("file://") || root.mpArtUrl.startsWith("http"))
                              ? root.mpArtUrl : ""
                        fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true; asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent; text: "\uF001"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 24
                        color: Colors.color8; visible: artImg.status !== Image.Ready
                    }
                }
                Column {
                    anchors { left: artRect.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    Text { width: parent.width; text: root.mpTitle; font.family: "Iosevka Nerd Font"; font.pixelSize: 13; font.bold: true; color: Colors.foreground; elide: Text.ElideRight }
                    Text { width: parent.width; text: root.mpArtist; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.color8; elide: Text.ElideRight; visible: root.mpArtist !== "" }
                    Text { width: parent.width; text: root.mpAlbum; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color6; elide: Text.ElideRight; visible: root.mpAlbum !== "" }
                }
            }

            Column {
                width: parent.width; spacing: 4
                Rectangle {
                    width: parent.width; height: 4; radius: 2; color: Qt.lighter(Colors.background, 1.4)
                    Rectangle {
                        width: root.mpDuration > 0 ? parent.width * Math.min(1, root.mpPosition / root.mpDuration) : 0
                        height: 4; radius: 2; color: Colors.color4
                        Behavior on width { NumberAnimation { duration: 500 } }
                    }
                }
                Item {
                    width: parent.width; height: 14
                    Text { anchors.left: parent.left; text: root.fmtTime(root.mpPosition); font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color8 }
                    Text { anchors.right: parent.right; text: root.mpDuration > 0 ? root.fmtTime(root.mpDuration) : "--:--"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color8 }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: 54; height: 40; radius: 8
                        color: ctrlMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.25)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: index === 0 ? "\uF049" : index === 1 ? (root.mpStatus === "Playing" ? "\uF04C" : "\uF04B") : "\uF050"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 16; color: Colors.foreground
                        }
                        MouseArea {
                            id: ctrlMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: { const p = index === 0 ? prevProc : index === 1 ? playProc : nextProc; p.running = false; p.running = true }
                        }
                    }
                }
            }
        }

        // ── Navidrome setup ─────────────────────────────────────────
        Column {
            width: parent.width; spacing: 10
            visible: root.mode === 1 && root.ndView === "setup"

            Text { text: "Navidrome Setup"; font.family: "Iosevka Nerd Font"; font.pixelSize: 13; font.bold: true; color: Colors.foreground }

            Column {
                width: parent.width; spacing: 6
                Repeater {
                    model: [{label: "URL", ph: "http://192.168.88.6:4533"}, {label: "User", ph: "username"}, {label: "Password", ph: "password"}]
                    delegate: Column {
                        width: parent.width; spacing: 2
                        Text { text: modelData.label; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color6 }
                        Rectangle {
                            width: parent.width; height: 30; radius: 6
                            color: Qt.lighter(Colors.background, 1.3)
                            border.color: setupInput.activeFocus ? Colors.color4 : "transparent"; border.width: 1
                            TextInput {
                                id: setupInput; anchors { fill: parent; margins: 8 }
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                color: Colors.foreground
                                echoMode: index === 2 ? TextInput.Password : TextInput.Normal
                                text: index === 0 ? "http://192.168.88.6:4533" : ""
                                Component.onCompleted: {
                                    if (index === 0) setupUrl = this
                                    else if (index === 1) setupUser = this
                                    else setupPass = this
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 32; radius: 6
                color: saveMa.containsMouse ? Qt.lighter(Colors.color4, 1.2) : Colors.color4
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "Save & Connect"; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.background }
                MouseArea {
                    id: saveMa; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        if (setupUrl && setupUser && setupPass) {
                            navi.saveConfig(setupUrl.text, setupUser.text, setupPass.text)
                            root.ndView = "browse"
                        }
                    }
                }
            }
        }

        property var setupUrl: null
        property var setupUser: null
        property var setupPass: null

        // ── Navidrome browser ───────────────────────────────────────
        Column {
            width: parent.width; spacing: 8
            visible: root.mode === 1 && root.ndView === "browse" && navi.configured

            // Category pills
            Row {
                width: parent.width; spacing: 4
                Repeater {
                    model: [{k: "albums", l: "Albums"}, {k: "artists", l: "Artists"}, {k: "playlists", l: "Playlists"}, {k: "random", l: "Random"}]
                    delegate: Rectangle {
                        width: (parent.width - 12) / 4; height: 24; radius: 6
                        color: root.ndBrowse === modelData.k ? Colors.color4
                             : catMa.containsMouse ? Qt.lighter(Colors.background, 1.5)
                             : Qt.lighter(Colors.background, 1.3)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: modelData.l
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                            color: root.ndBrowse === modelData.k ? Colors.background : Colors.foreground
                        }
                        MouseArea {
                            id: catMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                root.ndBrowse = modelData.k
                                root.ndView = "browse"
                                if (modelData.k === "albums") navi.getAlbums()
                                else if (modelData.k === "artists") navi.getArtists()
                                else if (modelData.k === "playlists") navi.getPlaylists()
                                else navi.getRandom()
                            }
                        }
                    }
                }
            }

            // Now playing bar (compact, if something is playing)
            Rectangle {
                width: parent.width; height: 36; radius: 6
                visible: navi.nowTitle !== ""
                color: Qt.lighter(Colors.background, 1.2)
                Row {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 8
                    Image {
                        width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter
                        source: navi.nowCover; fillMode: Image.PreserveAspectCrop
                        smooth: true; mipmap: true; asynchronous: true; visible: status === Image.Ready
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text { text: navi.nowTitle; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true; color: Colors.foreground; elide: Text.ElideRight; width: 200 }
                        Text { text: navi.nowArtist; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8; elide: Text.ElideRight; width: 200 }
                    }
                }
                Row {
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    Repeater {
                        model: 3
                        delegate: Text {
                            required property int index
                            text: index === 0 ? "\uF049" : index === 1 ? "\uF04C" : "\uF050"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: npMa.containsMouse ? Colors.color4 : Colors.foreground
                            MouseArea { id: npMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                                onClicked: {
                                    if (index === 0) navi.prevInQueue()
                                    else if (index === 1) { playProc.running = false; playProc.running = true }
                                    else navi.nextInQueue()
                                }
                            }
                        }
                    }
                }
            }

            // Content list
            Flickable {
                width: parent.width
                height: Math.max(100, root.height - (root.mode === 1 ? 140 : 0) - (navi.nowTitle !== "" ? 46 : 0))
                contentHeight: listCol.implicitHeight; clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listCol; width: parent.width; spacing: 2

                    // Albums view
                    Repeater {
                        model: root.ndBrowse === "albums" ? navi.albums : []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: parent.width; height: 44; radius: 6
                            color: albMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Row {
                                anchors { fill: parent; leftMargin: 6 }
                                spacing: 8
                                Image {
                                    width: 36; height: 36; anchors.verticalCenter: parent.verticalCenter
                                    source: navi.coverUrl(modelData.coverArt)
                                    fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true; asynchronous: true
                                    Rectangle { anchors.fill: parent; color: "transparent"; radius: 4; border.color: Qt.rgba(1,1,1,0.1); border.width: 1 }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: modelData.title; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.foreground; elide: Text.ElideRight; width: 260 }
                                    Text { text: modelData.artist + " \u00B7 " + modelData.songCount + " tracks"; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8; elide: Text.ElideRight; width: 260 }
                                }
                            }
                            MouseArea { id: albMa; anchors.fill: parent; hoverEnabled: true
                                onClicked: { navi.getAlbum(modelData.id); root.ndView = "tracks" }
                            }
                        }
                    }

                    // Artists view
                    Repeater {
                        model: root.ndBrowse === "artists" ? navi.artists : []
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width; height: 32; radius: 6
                            color: artMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                text: modelData.name + " (" + modelData.albumCount + " albums)"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.foreground
                            }
                            MouseArea { id: artMa; anchors.fill: parent; hoverEnabled: true }
                        }
                    }

                    // Playlists view
                    Repeater {
                        model: root.ndBrowse === "playlists" ? navi.playlists : []
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width; height: 32; radius: 6
                            color: plMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "\u{F0CB9}  " + modelData.name + " (" + modelData.songCount + ")"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.foreground
                            }
                            MouseArea { id: plMa; anchors.fill: parent; hoverEnabled: true
                                onClicked: { navi.getPlaylist(modelData.id); root.ndView = "tracks" }
                            }
                        }
                    }

                    // Random songs / track list view
                    Repeater {
                        model: (root.ndBrowse === "random" || root.ndView === "tracks") ? navi.songs : []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: parent.width; height: 36; radius: 6
                            color: navi.nowId === modelData.id ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.2)
                                 : songMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Row {
                                anchors { fill: parent; leftMargin: 8 }
                                spacing: 8
                                Text {
                                    width: 20; anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.track > 0 ? modelData.track : (index + 1)
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                                    color: Colors.color8; horizontalAlignment: Text.AlignRight
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: modelData.title; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: navi.nowId === modelData.id ? Colors.color4 : Colors.foreground; elide: Text.ElideRight; width: 240 }
                                    Text { text: modelData.artist; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8; elide: Text.ElideRight; width: 240; visible: modelData.artist !== "" }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.fmtTime(modelData.duration)
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8
                                }
                            }
                            MouseArea { id: songMa; anchors.fill: parent; hoverEnabled: true
                                onClicked: navi.playQueue(navi.songs, index)
                            }
                        }
                    }
                }
            }

            // Back button for track view
            Rectangle {
                width: 60; height: 24; radius: 6
                visible: root.ndView === "tracks"
                color: backMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.3)
                Text { anchors.centerIn: parent; text: "\u{F0141} Back"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.foreground }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.ndView = "browse" }
            }
        }

        // Not configured message
        Column {
            width: parent.width; spacing: 8
            visible: root.mode === 1 && !navi.configured && root.ndView !== "setup"
            Text { text: "Navidrome not configured"; font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: Colors.color8 }
            Rectangle {
                width: 80; height: 26; radius: 6; color: Colors.color4
                Text { anchors.centerIn: parent; text: "Setup"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.background }
                MouseArea { anchors.fill: parent; onClicked: root.ndView = "setup" }
            }
        }
    }
}
