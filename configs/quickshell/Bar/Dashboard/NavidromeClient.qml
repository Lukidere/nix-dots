import QtQuick
import Quickshell.Io

// Navidrome client stub — full implementation removed, MPRIS is primary player
Item {
    id: root
    visible: false; width: 0; height: 0

    property bool   configured: false
    property string nowTitle:   ""
    property string nowArtist:  ""
    property string nowCover:   ""
    property string nowId:      ""
    property var    albums:     []
    property var    artists:    []
    property var    playlists:  []
    property var    songs:      []

    function saveConfig(url, user, pass) {}
    function coverUrl(id) { return "" }
    function getAlbums() {}
    function getArtists() {}
    function getPlaylists() {}
    function getRandom() {}
    function getAlbum(id) {}
    function getPlaylist(id) {}
    function playQueue(songs, index) {}
    function prevInQueue() {}
    function nextInQueue() {}
}
