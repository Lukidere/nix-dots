import QtQuick
import "../Theme"

Rectangle {
    id: root
    property int    notifId:  0
    property string appName:  ""
    property string appIcon:  ""
    property string summary:  ""
    property string body:     ""
    property int    timeout:  5000

    width: 320; height: bodyText.visible ? 72 : 52
    radius: 10
    color: Qt.darker(Colors.background, 1.12)
    border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.3)
    border.width: 1

    // Progress bar at bottom showing time remaining
    Rectangle {
        id: progressBar
        anchors { bottom: parent.bottom; left: parent.left; leftMargin: 1; bottomMargin: 1 }
        width: parent.width - 2; height: 3; radius: 2
        color: Colors.color4
        NumberAnimation on width {
            from: root.width - 2; to: 0
            duration: root.timeout
            running: true
        }
    }

    // Dismiss timer
    Timer {
        interval: root.timeout; running: true
        onTriggered: NotifState.remove(root.notifId)
    }

    // App icon — use file path if available, otherwise show glyph
    Item {
        id: iconImg
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: 28; height: 28

        Image {
            id: _iconImage
            anchors.fill: parent
            source: root.appIcon && root.appIcon.includes("/") ? "file://" + root.appIcon : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: status === Image.Ready
        }
        Text {
            anchors.centerIn: parent
            visible: !_iconImage.visible
            text: "\u{F0F3}"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 18
            color: Colors.color4
        }
    }

    Column {
        anchors {
            left: iconImg.right; leftMargin: 10
            right: closeBtn.left; rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Text {
            id: summaryText
            width: parent.width
            text: root.summary || root.appName
            font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true
            color: Colors.foreground
            elide: Text.ElideRight
        }
        Text {
            id: bodyText
            width: parent.width
            text: root.body
            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
            color: Colors.color7
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            visible: root.body !== ""
        }
    }

    // Close button
    Text {
        id: closeBtn
        anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 8 }
        text: "\uF00D"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
        color: closeMa.containsMouse ? Colors.color1 : Colors.color8
        Behavior on color { ColorAnimation { duration: 150 } }
        MouseArea {
            id: closeMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
            onClicked: NotifState.remove(root.notifId)
        }
    }

    // Slide-in from right
    transform: Translate { x: root.x > 0 ? 0 : 0 }
    opacity: 0
    Component.onCompleted: {
        opacity = 1
    }
    Behavior on opacity { NumberAnimation { duration: 200 } }
}
