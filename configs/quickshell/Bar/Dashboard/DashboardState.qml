pragma Singleton
import QtQuick

QtObject {
    id: root
    property string activeScreenName: ""
    property string volPanelScreen:   ""

    function show(screenName) {
        _hideTimer.stop()
        root.activeScreenName = screenName
    }

    function scheduleHide() {
        _hideTimer.restart()
    }

    function showVolPanel(screenName) {
        _volHideTimer.stop()
        root.volPanelScreen = screenName
    }

    function scheduleHideVolPanel() {
        _volHideTimer.restart()
    }

    property Timer _hideTimer: Timer {
        interval: 300
        onTriggered: root.activeScreenName = ""
    }

    property Timer _volHideTimer: Timer {
        interval: 400
        onTriggered: root.volPanelScreen = ""
    }
}
