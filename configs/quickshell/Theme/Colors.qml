pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property string _raw: ""

    readonly property var _d: {
        try { return JSON.parse(_raw) } catch(e) { return {} }
    }

    readonly property FileView _watcher: FileView {
        path: "/home/dhm/.cache/wallust/colors.json"
        watchChanges: true
        onTextChanged: root._raw = root._watcher.text()
    }
    property Timer _colorPoll: Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            root._watcher.reload()
            const t = root._watcher.text()
            if (t) root._raw = t
        }
    }
    Component.onCompleted: root._raw = root._watcher.text()

    readonly property color background: _d.special ? _d.special.background : "#1e1e2e"
    readonly property color foreground: _d.special ? _d.special.foreground : "#cdd6f4"
    readonly property color cursor:     _d.special ? _d.special.cursor     : "#cdd6f4"
    readonly property color color0:  _d.colors ? _d.colors.color0  : "#45475a"
    readonly property color color1:  _d.colors ? _d.colors.color1  : "#f38ba8"
    readonly property color color2:  _d.colors ? _d.colors.color2  : "#a6e3a1"
    readonly property color color3:  _d.colors ? _d.colors.color3  : "#f9e2af"
    readonly property color color4:  _d.colors ? _d.colors.color4  : "#89b4fa"
    readonly property color color5:  _d.colors ? _d.colors.color5  : "#f5c2e7"
    readonly property color color6:  _d.colors ? _d.colors.color6  : "#94e2d5"
    readonly property color color7:  _d.colors ? _d.colors.color7  : "#bac2de"
    readonly property color color8:  _d.colors ? _d.colors.color8  : "#585b70"
    readonly property color color9:  _d.colors ? _d.colors.color9  : "#f38ba8"
    readonly property color color10: _d.colors ? _d.colors.color10 : "#a6e3a1"
    readonly property color color11: _d.colors ? _d.colors.color11 : "#f9e2af"
    readonly property color color12: _d.colors ? _d.colors.color12 : "#89b4fa"
    readonly property color color13: _d.colors ? _d.colors.color13 : "#f5c2e7"
    readonly property color color14: _d.colors ? _d.colors.color14 : "#94e2d5"
    readonly property color color15: _d.colors ? _d.colors.color15 : "#a6adc8"
}
