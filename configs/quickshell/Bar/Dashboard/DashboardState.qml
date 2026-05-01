pragma Singleton
import QtQuick

QtObject {
    id: root
    property string activeScreenName: ""

    function show(screenName) {
        _hideTimer.stop()
        root.activeScreenName = screenName
    }

    function scheduleHide() {
        _hideTimer.restart()
    }

    property Timer _hideTimer: Timer {
        interval: 300
        onTriggered: root.activeScreenName = ""
    }
}
