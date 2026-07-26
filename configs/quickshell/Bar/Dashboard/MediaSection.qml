import QtQuick
import "../../Theme"

// Music tab - YT Music only. The bar's Mpris widget stays generic;
// everything here targets the dashboard-owned mpv player.
Item {
    id: root

    // Exposed for ambient-art consumers in DashboardWindow
    property string artUrl: yt.mpvArt

    function fmtTime(s) {
        const m = Math.floor(s / 60)
        const ss = Math.floor(s % 60)
        return m + ":" + (ss < 10 ? "0" : "") + ss
    }

    YtMusicClient { id: yt }

    property string ytBrowse: "search"  // search, playlists, liked
    property string ytView: "browse"    // browse, tracks

    Column {
        anchors.fill: parent
        spacing: 10

        // ── Now playing header (mpv) ────────────────────────────────
        Item {
            width: parent.width; height: 90
            visible: yt.nowId !== ""

            Rectangle {
                width: 88; height: 88; radius: 12
                anchors.centerIn: artRect
                color: "transparent"; border.width: 2
                border.color: yt.mpvStatus === "Playing"
                    ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.55)
                    : "transparent"
                Behavior on border.color { ColorAnimation { duration: 600 } }
            }

            Rectangle {
                id: artRect
                width: 80; height: 80
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                radius: 8; color: Qt.lighter(Colors.background, 1.3); clip: true
                Image {
                    id: artImg
                    anchors.fill: parent
                    source: yt.mpvArt !== "" && (yt.mpvArt.startsWith("file://") || yt.mpvArt.startsWith("http")) ? yt.mpvArt : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true; mipmap: true; asynchronous: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent; text: ""
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 24
                    color: Colors.color8; visible: artImg.status !== Image.Ready
                }
            }

            Column {
                anchors { left: artRect.right; leftMargin: 12; right: ctrlRow.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 4
                Text { width: parent.width; text: yt.mpvTitle; font.family: "Iosevka Nerd Font"; font.pixelSize: 13; font.bold: true; color: Colors.foreground; elide: Text.ElideRight }
                Text { width: parent.width; text: yt.mpvArtist; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.color8; elide: Text.ElideRight; visible: yt.mpvArtist !== "" }
            }

            Row {
                id: ctrlRow
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 4
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        width: 30; height: 30; radius: 6
                        color: ytCtlMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.25)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: index === 0 ? "" : index === 1 ? (yt.mpvStatus === "Playing" ? "" : "") : index === 2 ? "" : ""
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: Colors.foreground
                        }
                        MouseArea {
                            id: ytCtlMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (index === 0) yt.previous()
                                else if (index === 1) yt.playPause()
                                else if (index === 2) yt.next()
                                else yt.stop()
                            }
                        }
                    }
                }
            }
        }

        // ── Browser ─────────────────────────────────────────────────
        Column {
            width: parent.width; spacing: 8
            visible: yt.configured

            // Category pills
            Row {
                width: parent.width; spacing: 4
                Repeater {
                    model: [{k: "search", l: "Search"}, {k: "playlists", l: "Playlists"}, {k: "liked", l: "Liked"}]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 8) / 3; height: 24; radius: 6
                        color: root.ytBrowse === modelData.k ? Colors.color4
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
                border.color: ytSearchInput.activeFocus ? Colors.color4 : "transparent"; border.width: 1
                TextInput {
                    id: ytSearchInput
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.foreground; clip: true
                    onAccepted: { yt.search(text); root.ytView = "tracks" }
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
                height: Math.max(100, root.height - 120 - (yt.nowId !== "" ? 100 : 0))
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

                    // Track list (search results, playlist tracks, liked)
                    Repeater {
                        model: (root.ytBrowse === "search" || root.ytView === "tracks") ? yt.songs : []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: parent.width; height: 36; radius: 6
                            color: yt.nowId === modelData.id ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.2)
                                 : songMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Row {
                                anchors { fill: parent; leftMargin: 8 }
                                spacing: 8
                                Image {
                                    width: 26; height: 26; anchors.verticalCenter: parent.verticalCenter
                                    source: modelData.cover; sourceSize.width: 64; sourceSize.height: 64
                                    fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: modelData.title; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: yt.nowId === modelData.id ? Colors.color4 : Colors.foreground; elide: Text.ElideRight; width: 230 }
                                    Text { text: modelData.artist; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8; elide: Text.ElideRight; width: 230; visible: modelData.artist !== "" }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.fmtTime(modelData.duration)
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8
                                }
                            }
                            MouseArea { id: songMa; anchors.fill: parent; hoverEnabled: true
                                onClicked: yt.playQueue(yt.songs, index)
                            }
                        }
                    }
                }
            }

            // Back button for playlist track view
            Rectangle {
                width: 60; height: 24; radius: 6
                visible: root.ytView === "tracks" && root.ytBrowse === "playlists"
                color: backMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.3)
                Text { anchors.centerIn: parent; text: "\u{F0141} Back"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.foreground }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; onClicked: { root.ytView = "browse"; yt.getPlaylists() } }
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
                width: 90; height: 26; radius: 6; color: Colors.color4
                Text { anchors.centerIn: parent; text: "Re-check"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.background }
                MouseArea { anchors.fill: parent; onClicked: yt.checkStatus() }
            }
        }
    }
}
