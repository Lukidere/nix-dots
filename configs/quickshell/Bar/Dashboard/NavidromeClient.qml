import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false; width: 0; height: 0

    property string baseUrl:  ""
    property string user:     ""
    property string pass:     ""
    property string token:    ""
    property string salt:     ""
    property bool   configured: false
    property bool   connected:  false

    property var albums:    []
    property var artists:   []
    property var playlists: []
    property var songs:     []
    property var queue:     []
    property int queueIdx:  -1

    property string nowId:     ""
    property string nowTitle:  ""
    property string nowArtist: ""
    property string nowAlbum:  ""
    property string nowCover:  ""

    signal dataReady(string kind)

    // Read config
    Process {
        id: _configProc
        command: ["sh", "-c", "cat ~/.config/quickshell/navidrome.conf 2>/dev/null || echo ''"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                for (const line of lines) {
                    const eq = line.indexOf("=")
                    if (eq < 0) continue
                    const k = line.substring(0, eq).trim()
                    const v = line.substring(eq + 1).trim()
                    if (k === "url")  root.baseUrl = v
                    if (k === "user") root.user = v
                    if (k === "pass") root.pass = v
                }
                if (root.baseUrl && root.user && root.pass) {
                    root.configured = true
                    root._genToken()
                }
            }
        }
    }

    function _genToken() {
        root.salt = "qs" + Math.floor(Math.random() * 999999)
        _tokenProc.command = ["sh", "-c",
            "printf '%s' " + JSON.stringify(root.pass + root.salt) + " | md5sum | cut -d' ' -f1"]
        _tokenProc.running = false; _tokenProc.running = true
    }

    Process {
        id: _tokenProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.token = this.text.trim()
                if (root.token) {
                    root.connected = true
                    root.getAlbums()
                }
            }
        }
    }

    function _authParams() {
        return "u=" + encodeURIComponent(root.user) +
               "&t=" + root.token + "&s=" + root.salt +
               "&v=1.16.1&c=quickshell&f=json"
    }

    function apiUrl(endpoint, extra) {
        return root.baseUrl + "/rest/" + endpoint + "?" + root._authParams() + (extra || "")
    }

    function coverUrl(coverId) {
        if (!coverId) return ""
        return root.baseUrl + "/rest/getCoverArt?" + root._authParams() + "&id=" + coverId + "&size=200"
    }

    function streamUrl(songId) {
        return root.baseUrl + "/rest/stream?" + root._authParams() + "&id=" + songId
    }

    // API calls
    Process {
        id: _apiProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseResponse(this.text)
        }
    }

    property string _apiKind: ""

    function _apiCall(endpoint, extra, kind) {
        root._apiKind = kind
        _apiProc.command = ["sh", "-c",
            "curl -sf '" + root.apiUrl(endpoint, extra) + "' 2>/dev/null"]
        _apiProc.running = false; _apiProc.running = true
    }

    function _parseResponse(text) {
        const kind = root._apiKind
        try {
            const d = JSON.parse(text)
            const r = d["subsonic-response"] || {}
            if (r.status !== "ok") return

            if (kind === "albums") {
                const list = (r.albumList2 || {}).album || []
                root.albums = list.map(function(a) { return {
                    id: a.id, title: a.name || a.title || "", artist: a.artist || "",
                    coverArt: a.coverArt || "", songCount: a.songCount || 0
                }})
                root.dataReady("albums")
            }
            else if (kind === "artists") {
                const indices = (r.artists || {}).index || []
                let arts = []
                for (let ii = 0; ii < indices.length; ii++) {
                    const idx = indices[ii]
                    const al = idx.artist || []
                    for (let j = 0; j < al.length; j++) {
                        arts.push({ id: al[j].id, name: al[j].name || "", albumCount: al[j].albumCount || 0 })
                    }
                }
                root.artists = arts
                root.dataReady("artists")
            }
            else if (kind === "playlists") {
                const list = (r.playlists || {}).playlist || []
                root.playlists = list.map(function(p) { return {
                    id: p.id, name: p.name || "", songCount: p.songCount || 0,
                    coverArt: p.coverArt || ""
                }})
                root.dataReady("playlists")
            }
            else if (kind === "album" || kind === "random" || kind === "playlist") {
                let list = []
                if (kind === "album") {
                    list = (r.album || {}).song || []
                } else if (kind === "random") {
                    list = (r.randomSongs || {}).song || []
                } else if (kind === "playlist") {
                    list = (r.playlist || {}).entry || []
                }
                root.songs = list.map(function(s) { return {
                    id: s.id, title: s.title || "", artist: s.artist || "",
                    album: s.album || "", duration: s.duration || 0,
                    coverArt: s.coverArt || "", track: s.track || 0
                }})
                root.dataReady("songs")
            }
        } catch(e) {}
    }

    function getAlbums()    { _apiCall("getAlbumList2", "&type=newest&size=30", "albums") }
    function getArtists()   { _apiCall("getArtists", "", "artists") }
    function getPlaylists() { _apiCall("getPlaylists", "", "playlists") }
    function getRandom()    { _apiCall("getRandomSongs", "&size=30", "random") }
    function getAlbum(id)   { _apiCall("getAlbum", "&id=" + id, "album") }
    function getPlaylist(id){ _apiCall("getPlaylist", "&id=" + id, "playlist") }

    // Playback
    Process { id: _playProc; running: false }

    function playSong(song) {
        root.nowId     = song.id
        root.nowTitle  = song.title
        root.nowArtist = song.artist
        root.nowAlbum  = song.album
        root.nowCover  = root.coverUrl(song.coverArt)
        _playProc.command = ["mpv", "--no-video", "--force-window=no", root.streamUrl(song.id)]
        _playProc.running = false; _playProc.running = true
    }

    function playQueue(songs, startIdx) {
        root.queue = songs
        root.queueIdx = startIdx || 0
        if (root.queue.length > 0) root.playSong(root.queue[root.queueIdx])
    }

    function nextInQueue() {
        if (root.queueIdx < root.queue.length - 1) {
            root.queueIdx++
            root.playSong(root.queue[root.queueIdx])
        }
    }

    function prevInQueue() {
        if (root.queueIdx > 0) {
            root.queueIdx--
            root.playSong(root.queue[root.queueIdx])
        }
    }

    // Save config
    Process { id: _saveProc; running: false }

    function saveConfig(url, usr, pw) {
        _saveProc.command = ["sh", "-c",
            "mkdir -p ~/.config/quickshell && printf 'url=%s\\nuser=%s\\npass=%s\\n' " +
            JSON.stringify(url) + " " + JSON.stringify(usr) + " " + JSON.stringify(pw) +
            " > ~/.config/quickshell/navidrome.conf"]
        _saveProc.running = false; _saveProc.running = true
        root.baseUrl = url; root.user = usr; root.pass = pw
        root.configured = true
        root._genToken()
    }
}
