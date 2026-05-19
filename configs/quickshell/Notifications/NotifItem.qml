import QtQuick
import "../Theme"

Rectangle {
    id: root
    property int    notifId:   0
    property string appName:   ""
    property string appIcon:   ""
    property string summary:   ""
    property string body:      ""
    property int    timeout:   5000
    property real   createdAt: Date.now()

    readonly property int _elapsed:   Math.max(0, Math.min(timeout - 50, Date.now() - createdAt))
    readonly property int _remaining: timeout - _elapsed

    width: 320; height: bodyText.visible ? 84 : 64
    radius: 10
    color: Qt.darker(Colors.background, 1.12)
    border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.3)
    border.width: 1

    property real swipeX:     0
    property real _swipeFade: 1.0
    property bool _dragging:  false

    Behavior on swipeX {
        enabled: !root._dragging
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
    Behavior on _swipeFade {
        enabled: !root._dragging
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    DragHandler {
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: {
            root._dragging = active
            if (!active) {
                if (Math.abs(root.swipeX) > 100) {
                    NotifState.remove(root.notifId)
                } else {
                    root.swipeX    = 0
                    root._swipeFade = 1.0
                }
            }
        }
        onTranslationChanged: {
            root.swipeX     = translation.x
            root._swipeFade = Math.max(0, 1 - Math.abs(translation.x) / 220)
        }
    }

    // Progress bar at bottom showing time remaining
    Rectangle {
        id: progressBar
        anchors { bottom: parent.bottom; left: parent.left; leftMargin: 1; bottomMargin: 1 }
        width: root.timeout > 0 ? (root.width - 2) * (root._remaining / root.timeout) : 0
        height: 3; radius: 2
        color: Colors.color4
        NumberAnimation on width {
            from: root.timeout > 0 ? (root.width - 2) * (root._remaining / root.timeout) : 0
            to: 0
            duration: root._remaining
            running: true
        }
    }

    // Dismiss timer
    Timer {
        interval: root._remaining; running: true
        onTriggered: NotifState.remove(root.notifId)
    }

    // App icon
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
            width: parent.width
            text: root.appName
            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
            color: Colors.color8
            elide: Text.ElideRight
            visible: root.appName !== ""
        }
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

    property real slideX: root._elapsed < 400 ? 340 : 0
    transform: Translate { x: root.slideX + root.swipeX }
    opacity: (root._elapsed < 400 ? 0 : 1) * root._swipeFade
    scale: root._elapsed < 400 ? 0.92 : 1.0

    Component.onCompleted: {
        if (root._elapsed < 400) {
            slideAnim.start()
            fadeAnim.start()
            scaleAnim.start()
        }
    }
    NumberAnimation {
        id: slideAnim; target: root; property: "slideX"
        from: 340; to: 0; duration: 300; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: fadeAnim; target: root; property: "opacity"
        from: 0; to: 1; duration: 220
    }
    NumberAnimation {
        id: scaleAnim; target: root; property: "scale"
        from: 0.92; to: 1.0; duration: 300; easing.type: Easing.OutCubic
    }
}
