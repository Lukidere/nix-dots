import QtQuick
import "."

// ponytail: lush section header - replaces 3px-bar + CAPS pattern
Item {
    id: sh
    property string label
    property string ico: ""
    property string badge: ""
    property color accent: Colors.color4
    width: parent.width; height: 36

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.rgba(sh.accent.r, sh.accent.g, sh.accent.b, 0.07)
        Behavior on color { ColorAnimation { duration: 180 } }
    }
    Rectangle {
        x: 0; y: 4; width: 4; height: parent.height - 8; radius: 2
        color: sh.accent
        Behavior on color { ColorAnimation { duration: 180 } }
    }
    Row {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
        spacing: 10
        Text {
            visible: sh.ico !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: sh.ico
            font.family: "Iosevka Nerd Font"; font.pixelSize: 16
            color: sh.accent
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: sh.label
            font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true
            font.letterSpacing: 1.5
            color: Colors.foreground
        }
    }
    Rectangle {
        visible: sh.badge !== ""
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
        width: badgeText.implicitWidth + 14; height: 18; radius: 9
        color: Qt.rgba(sh.accent.r, sh.accent.g, sh.accent.b, 0.18)
        Behavior on color { ColorAnimation { duration: 180 } }
        Text {
            id: badgeText
            anchors.centerIn: parent
            text: sh.badge
            font.family: "Iosevka Nerd Font"; font.pixelSize: 10; font.bold: true
            color: sh.accent
            Behavior on color { ColorAnimation { duration: 180 } }
        }
    }
}
