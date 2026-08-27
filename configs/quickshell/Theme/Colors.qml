pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property string _raw: ""

    // crossfade duration when the wallust palette changes (wallpaper switch)
    property int transitionMs: 450

    readonly property var _d: {
        try { return JSON.parse(_raw) } catch(e) { return {} }
    }

    readonly property FileView _watcher: FileView {
        path: "/home/dhm/.cache/wallust/colors.json"
        watchChanges: true
        onTextChanged: root._raw = root._watcher.text()
    }
    property Timer _colorPoll: Timer {
        // fallback only: WallpaperSection calls Colors.reload() the instant wallust
        // finishes, so this just catches out-of-band changes (CLI wallust) slowly
        interval: 2000; running: true; repeat: true
        onTriggered: {
            root._watcher.reload()
            const t = root._watcher.text()
            if (t) root._raw = t
        }
    }
    // Re-read the palette immediately (called right after wallust finishes, so
    // the swap is instant instead of waiting for the poll or a missed inotify).
    function reload() {
        root._watcher.reload()
        const t = root._watcher.text()
        if (t) root._raw = t
    }

    Component.onCompleted: root._raw = root._watcher.text()

    // Bindings still track colors.json; the Behaviors animate each change so the
    // whole UI crossfades to the new palette instead of snapping.
    property color background: _d.special ? _d.special.background : "#1e1e2e"
    property color foreground: _d.special ? _d.special.foreground : "#cdd6f4"
    property color cursor:     _d.special ? _d.special.cursor     : "#cdd6f4"
    property color color0:  _d.colors ? _d.colors.color0  : "#45475a"
    property color color1:  _d.colors ? _d.colors.color1  : "#f38ba8"
    property color color2:  _d.colors ? _d.colors.color2  : "#a6e3a1"
    property color color3:  _d.colors ? _d.colors.color3  : "#f9e2af"
    property color color4:  _d.colors ? _d.colors.color4  : "#89b4fa"
    property color color5:  _d.colors ? _d.colors.color5  : "#f5c2e7"
    property color color6:  _d.colors ? _d.colors.color6  : "#94e2d5"
    property color color7:  _d.colors ? _d.colors.color7  : "#bac2de"
    property color color8:  _d.colors ? _d.colors.color8  : "#585b70"
    property color color9:  _d.colors ? _d.colors.color9  : "#f38ba8"
    property color color10: _d.colors ? _d.colors.color10 : "#a6e3a1"
    property color color11: _d.colors ? _d.colors.color11 : "#f9e2af"
    property color color12: _d.colors ? _d.colors.color12 : "#89b4fa"
    property color color13: _d.colors ? _d.colors.color13 : "#f5c2e7"
    property color color14: _d.colors ? _d.colors.color14 : "#94e2d5"
    property color color15: _d.colors ? _d.colors.color15 : "#a6adc8"

    Behavior on background { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on foreground { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on cursor     { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color0  { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color1  { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color2  { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color3  { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color4  { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color5  { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color6  { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color7  { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color8  { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color9  { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color10 { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color11 { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color12 { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color13 { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color14 { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
    Behavior on color15 { ColorAnimation { duration: root.transitionMs; easing.type: Easing.InOutQuad } }
}
