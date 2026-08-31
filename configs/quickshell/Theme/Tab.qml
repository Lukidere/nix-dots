pragma Singleton
import QtQuick
import "."

QtObject {
    // per-tab identity - accent + display name + nerd-font icon
    function accent(i) {
        return [
            Colors.color4,   // 0 Controls - blue
            Colors.color6,   // 1 Media - teal
            Colors.color5,   // 2 Wallpapers - pink
            Colors.color3,   // 3 Inbox - yellow
            Colors.color1,   // 4 System - red
            Colors.color6,   // 5 Mail - teal
            Colors.color2,   // 6 News - green
            Colors.color7    // 7 Settings - subtle
        ][i] || Colors.color4
    }
    function name(i) {
        return ["CONTROLS", "MEDIA", "WALLPAPERS", "INBOX", "SYSTEM", "MAIL", "NEWS", "SETTINGS"][i] || ""
    }
    function icon(i) {
        return ["", "", "", "", "", "\uF0E0", "\uF09E", "\uF013"][i] || ""
    }
}
