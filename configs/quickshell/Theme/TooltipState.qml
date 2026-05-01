pragma Singleton
import QtQuick

QtObject {
    id: root
    property string text: ""
    property real   screenY: 0
    property bool   visible: false
    property var    screen: null

    function show(txt, sy, scr) {
        root.text    = txt
        root.screenY = sy
        root.screen  = scr || null
        root.visible = true
    }
    function hide() {
        root.visible = false
    }
}
