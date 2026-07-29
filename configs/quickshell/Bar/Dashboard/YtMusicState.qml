pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// YT Music client - browse/search via qs-ytmusic.py (ytmusicapi),
// playback via headless mpv (+mpris script → bar controls work).
Item {
    id: root
    visible: false; width: 0; height: 0

    property bool configured: false
    property bool loading:    false
    property string error:    ""
    property var  playlists:  []
    property var  songs:      []
    property string nowId:    ""

    readonly property string _script: Quickshell.env("HOME") + "/.config/quickshell/scripts/qs-ytmusic.py"

    function checkStatus() { _run(["status"]) }
    function search(q)     { if (q.trim() !== "") _run(["search", q]) }
    function getPlaylists(){ _run(["playlists"]) }
    function getPlaylist(id){ _run(["playlist", id]) }
    function getLiked()    { _run(["liked"]) }

    function _run(args) {
        root.error = ""
        root.loading = true
        _proc.running = false
        _proc.command = ["python3", _script].concat(args)
        _proc._cmd = args[0]
        _proc.running = true
    }

    // Play queue starting at index; mpv+mpris exposes prev/next/pause to the bar.
    function playQueue(list, index) {
        // Premium quality: web_music client + cookies.txt (qs-ytmusic.py cookies)
        // + PO tokens from the bgutil-pot container via the yt-dlp plugin.
        const cookies = Quickshell.env("HOME") + "/.config/qs-ytmusic/cookies.txt"
        const args = ["mpv", "--no-video", "--no-terminal",
                      "--ytdl-raw-options=cookies=" + cookies + ",extractor-args=youtube:player_client=web_music",
                      "--playlist-start=" + index]
        for (const t of list)
            args.push("https://music.youtube.com/watch?v=" + t.id)
        root.nowId = list[index] ? list[index].id : ""
        _player.running = false
        _player.command = args
        _player.running = true
    }

    function stop() { _player.running = false; root.nowId = "" }

    // ── mpv-targeted transport (independent from the bar's generic MPRIS) ──
    property string mpvStatus: ""
    property string mpvTitle:  ""
    property string mpvArtist: ""
    property string mpvArt:    ""
    property real   mpvPosition: 0
    property real   mpvDuration: 0

    function playPause() { _ctl(["playerctl", "-p", "mpv", "play-pause"]) }
    function next()      { _ctl(["playerctl", "-p", "mpv", "next"]) }
    function previous()  { _ctl(["playerctl", "-p", "mpv", "previous"]) }
    function seek(sec)   { root.mpvPosition = sec; _ctl(["playerctl", "-p", "mpv", "position", String(Math.max(0, Math.round(sec)))]) }
    function _ctl(cmd) { _ctlProc.running = false; _ctlProc.command = cmd; _ctlProc.running = true }
    readonly property Process _ctlProc: Process {}

    Timer {
        interval: 2000; repeat: true; running: root.nowId !== ""
        triggeredOnStart: true
        onTriggered: { _pollProc.running = false; _pollProc.running = true }
    }
    readonly property Process _pollProc: Process {
        command: ["sh", "-c",
            "playerctl -p mpv status 2>/dev/null; playerctl -p mpv metadata --format '{{title}}\n{{artist}}\n{{mpris:artUrl}}\n{{mpris:length}}' 2>/dev/null; playerctl -p mpv position 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                // mpv gone (queue ended / killed): clear state, timer stops itself
                if (this.text.trim() === "" && !root._player.running) {
                    root.nowId = ""
                    root.mpvStatus = ""; root.mpvTitle = ""; root.mpvArtist = ""; root.mpvArt = ""
                    root.mpvPosition = 0; root.mpvDuration = 0
                    return
                }
                const l = this.text.split("\n")
                root.mpvStatus = l[0] || ""
                root.mpvTitle  = l[1] || ""
                root.mpvArtist = l[2] || ""
                root.mpvArt    = l[3] || ""
                root.mpvDuration = (parseInt(l[4]) || 0) / 1000000
                root.mpvPosition = parseFloat(l[5]) || 0
            }
        }
    }

    readonly property Process _proc: Process {
        property string _cmd: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                let data
                try { data = JSON.parse(this.text) } catch (e) { root.error = "bad response"; return }
                if (data && data.error !== undefined) { root.error = data.error; return }
                if (_proc._cmd === "status")         root.configured = data.configured === true
                else if (_proc._cmd === "playlists") root.playlists = data
                else                                  root.songs = data
            }
        }
    }

    readonly property Process _player: Process {}

    Component.onCompleted: checkStatus()
}
