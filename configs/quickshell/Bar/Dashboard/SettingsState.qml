pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io
import "../../Theme"
import "../../Notifications"

// Persisted GUI settings + the live commands that apply them. Storage lives in a
// non-home-manager path (~/.config/qs-settings/settings.json) because the managed
// configs (~/.config/quickshell, niri, wallust) are immutable Nix store symlinks.
// Everything is applied at runtime via wpctl/gammastep/niri msg/wallust and
// re-applied on startup from the JSON, rather than by editing any config file.
QtObject {
    id: root

    readonly property string _home: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")
    readonly property string _dir:  _home + "/.config/qs-settings"
    readonly property string _path: _dir + "/settings.json"

    // ── persisted settings (defaults mirror today's hardcoded behaviour) ──
    property int    nightTemp:   4000   // gammastep colour temperature (K)
    property int    nightStart:  18     // auto night-light on  at this hour
    property int    nightEnd:    6      // auto night-light off at this hour
    property bool   micLoopback: false  // pw-loopback to easyeffects_source
    property bool   dndPersist:  false  // remember NotifState.dnd across sessions
    property bool   dndValue:    false  // last dnd state (restored when dndPersist)
    property string defaultSink: ""     // wpctl default audio sink node id
    property string wallustPalette: ""  // "" = use wallust.toml default
    property var    outputScales: ({})  // { "eDP-1": 2.0, "HDMI-A-1": 1.0 }

    // ── live-read lists for the pickers (not persisted) ──
    property var sinks:   []   // [{ id, name, active }]
    property var outputs: []   // [{ name, scale }]

    property bool _loaded: false

    // ---- load ---------------------------------------------------------------
    property FileView _fv: FileView {
        path: root._path
        onLoaded:      { root._ingest(root._fv.text()); root._afterLoad() }
        onLoadFailed:  root._afterLoad()   // no file yet: keep defaults, still apply
    }

    function _ingest(txt) {
        if (!txt) return
        var d
        try { d = JSON.parse(txt) } catch (e) { return }
        if (d.nightTemp    !== undefined) nightTemp    = d.nightTemp
        if (d.nightStart   !== undefined) nightStart   = d.nightStart
        if (d.nightEnd     !== undefined) nightEnd     = d.nightEnd
        if (d.micLoopback  !== undefined) micLoopback  = d.micLoopback
        if (d.dndPersist   !== undefined) dndPersist   = d.dndPersist
        if (d.dndValue     !== undefined) dndValue     = d.dndValue
        if (d.defaultSink  !== undefined) defaultSink  = d.defaultSink
        if (d.wallustPalette !== undefined) wallustPalette = d.wallustPalette
        if (d.outputScales !== undefined) outputScales = d.outputScales
    }

    function _afterLoad() {
        root._loaded = true
        refreshSinks()
        refreshOutputs()
        applyAll()
    }

    // ---- save (write via a shell that never interpolates data into the script) ----
    property Process _writeProc: Process { running: false }
    property Timer _saveDebounce: Timer {
        interval: 300; repeat: false
        onTriggered: {
            var obj = {
                nightTemp: root.nightTemp, nightStart: root.nightStart, nightEnd: root.nightEnd,
                micLoopback: root.micLoopback, dndPersist: root.dndPersist, dndValue: root.dndValue,
                defaultSink: root.defaultSink, wallustPalette: root.wallustPalette,
                outputScales: root.outputScales
            }
            // dir/json passed as $1/$2 - never spliced into the script text
            root._writeProc.command = ["sh", "-c",
                'mkdir -p "$1" && printf "%s" "$2" > "$1/settings.json"',
                "_", root._dir, JSON.stringify(obj, null, 2)]
            root._writeProc.running = false
            root._writeProc.running = true
        }
    }
    function save() { if (root._loaded) root._saveDebounce.restart() }

    // ---- apply-on-startup ---------------------------------------------------
    function applyAll() {
        if (defaultSink !== "")  _applySink(defaultSink)
        _applyLoopback(micLoopback)
        for (var name in outputScales) _applyScale(name, outputScales[name])
        if (wallustPalette !== "") _applyWallust(wallustPalette)
        if (dndPersist) NotifState.dnd = dndValue
    }

    // mirror NotifState.dnd into storage while persistence is enabled
    property Connections _dndWatch: Connections {
        target: NotifState
        function onDndChanged() {
            if (root.dndPersist) { root.dndValue = NotifState.dnd; root.save() }
        }
    }

    // ---- audio: default sink ------------------------------------------------
    property Process _sinkList: Process {
        command: ["wpctl", "status"]
        running: false
        stdout: StdioCollector { onStreamFinished: root._parseSinks(this.text) }
    }
    property Process _sinkSet: Process { running: false }

    function refreshSinks() { root._sinkList.running = false; root._sinkList.running = true }

    // parse the "Audio > Sinks:" block of `wpctl status`
    function _parseSinks(txt) {
        var out = []
        var lines = txt.split("\n")
        var inSinks = false
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i]
            // section headers carry tree chars ("│ ├─ Sinks:") so match loosely
            if (/(^|─|\s)Sinks:/.test(l)) { inSinks = true; continue }
            if (inSinks) {
                if (/(Sources|Filters|Streams|Sink endpoints):/.test(l)) break
                // e.g. " │  *   49. Family 17h ... [vol: 0.50]"
                var m = l.match(/^\s*[│├└─\s]*(\*?)\s*(\d+)\.\s+(.+?)\s*(\[vol.*)?$/)
                if (m) out.push({ active: m[1] === "*", id: m[2], name: m[3].trim() })
            }
        }
        root.sinks = out
    }
    function setDefaultSink(id) {
        defaultSink = id
        _applySink(id)
        save()
        // update the active marker in place (a refetch would reorder rows and
        // make them jump under the cursor)
        var arr = sinks.slice()
        for (var i = 0; i < arr.length; i++)
            arr[i] = { active: arr[i].id === id, id: arr[i].id, name: arr[i].name }
        sinks = arr
    }
    function _applySink(id) {
        root._sinkSet.command = ["wpctl", "set-default", id]
        root._sinkSet.running = false; root._sinkSet.running = true
    }

    // ---- night light --------------------------------------------------------
    property Process _tempApply: Process { running: false }
    property Timer _tempDebounce: Timer {
        interval: 120; repeat: false
        onTriggered: {
            root._tempApply.command = ["sh","-c","gammastep -m drm -O " + root.nightTemp + " >/dev/null 2>&1"]
            root._tempApply.running = false; root._tempApply.running = true
        }
    }
    function setNightTemp(t)        { nightTemp = t; _tempDebounce.restart(); save() }
    function setNightSchedule(s, e) { nightStart = s; nightEnd = e; save() }

    // ---- mic loopback -------------------------------------------------------
    property Process _loopOn:  Process { command: ["sh","-c","pw-loopback --capture-props='node.target=easyeffects_source' >/dev/null 2>&1 &"]; running: false }
    property Process _loopOff: Process { command: ["pkill","-f","pw-loopback"]; running: false }
    function toggleMicLoopback() {
        micLoopback = !micLoopback
        _applyLoopback(micLoopback)
        save()
    }
    function _applyLoopback(on) {
        if (on) { root._loopOn.running = false; root._loopOn.running = true }
        else    { root._loopOff.running = false; root._loopOff.running = true }
    }

    // ---- dnd persistence ----------------------------------------------------
    function setDndPersist(on) { dndPersist = on; if (on) dndValue = NotifState.dnd; save() }

    // ---- display: per-output scale via niri IPC -----------------------------
    property Process _outList: Process {
        command: ["niri", "msg", "-j", "outputs"]
        running: false
        stdout: StdioCollector { onStreamFinished: root._parseOutputs(this.text) }
    }
    property Process _outSet: Process { running: false }

    function refreshOutputs() { root._outList.running = false; root._outList.running = true }

    function _parseOutputs(txt) {
        var out = []
        try {
            var d = JSON.parse(txt)
            for (var name in d) {
                var o = d[name]
                var scale = (o.logical && o.logical.scale) ? o.logical.scale : 1.0
                out.push({ name: name, scale: scale })
            }
        } catch (e) { return }
        root.outputs = out
    }
    function setOutputScale(name, scale) {
        // new object ref so the change actually notifies bindings (mutating the
        // same ref in place does not trigger a QML property update)
        var m = Object.assign({}, outputScales); m[name] = scale; outputScales = m
        _applyScale(name, scale)
        save()
        // no refetch: niri reflows logical positions on a scale change, and a
        // refresh mid-interaction makes the control jump. UI reads outputScales.
    }
    function _applyScale(name, scale) {
        root._outSet.command = ["niri", "msg", "output", name, "scale", String(scale)]
        root._outSet.running = false; root._outSet.running = true
    }

    // ---- appearance: hand-edited palette (writes wallust's colors.json) ------
    // The written file is the persistence: Colors reads it on start, it survives
    // reboot, and a wallpaper switch naturally overwrites it via wallust.
    property Process _palWrite: Process { running: false; onExited: Colors.reload() }
    function applyCustomPalette(obj) {
        // obj = { special:{background,foreground,cursor}, colors:{color0..15} }
        root._palWrite.command = ["sh","-c",'printf "%s" "$2" > "$1"',
            "_", root._home + "/.cache/wallust/colors.json", JSON.stringify(obj, null, 2)]
        root._palWrite.running = false; root._palWrite.running = true
    }

    // ---- appearance: wallust palette override (re-run on current wallpaper) --
    property Process _wallust: Process { running: false; onExited: Colors.reload() }
    function setWallustPalette(p) {
        wallustPalette = p
        _applyWallust(p)
        save()
    }
    function _applyWallust(p) {
        // resolve the live wallpaper from awww, then re-theme with the chosen palette
        // after wallust, run the contrast fixer: it lifts low-contrast accents
        // vs the background (softdark makes them unreadable), patches colors.json
        // + ghostty's palette, and reloads ghostty so open terminals repaint
        root._wallust.command = ["sh","-c",
            'wp=$(awww query 2>/dev/null | grep -oP "image: \\K.*" | head -1); ' +
            '[ -n "$wp" ] && wallust run "$wp" --palette "$1"; ' +
            'python3 "$HOME/.config/quickshell/scripts/qs-contrast.py"',
            "_", p]
        root._wallust.running = false; root._wallust.running = true
    }
}
