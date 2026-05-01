pragma Singleton
import QtQuick

QtObject {
    id: root
    property bool open: false
    property string screenName: ""

    function toggle(scr) { root.screenName = scr || ""; root.open = !root.open }
    function close()     { root.open = false }
}
