import QtQuick
import "../../Theme"

Item {
    id: root
    width: 44
    readonly property bool   active:    MprisState.active
    readonly property bool   isPlaying: MprisState.playing
    readonly property string trackInfo: MprisState.artist !== ""
        ? MprisState.artist + " - " + MprisState.title : MprisState.title
    readonly property real   trackPos:  MprisState.position
    readonly property real   trackLen:  MprisState.duration

    // Collapsed: only play/pause visible (44px).
    // Expanded: track info + prev above, next below (152px).
    // +3px at bottom for progress bar.
    height: active ? (expanded ? 155 : 47) : 0
    visible: active
    clip: true
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }

    // Hover tracker — acceptedButtons:NoButton so it never steals clicks
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    property bool expanded: hoverArea.containsMouse

    // ── Track info ────────────────────────────────────────────────────
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
        text: root.trackInfo
        width: 40; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
        font.family: "Iosevka Nerd Font"; font.pixelSize: 9
        color: Colors.color6
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // ── Prev button (full-width hit area) ─────────────────────────────
    Item {
        width: 44; height: 36
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 22 }
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Text {
            anchors.centerIn: parent; text: "\uF048"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 14
            color: prevMa.containsMouse ? Qt.lighter(Colors.foreground, 1.5) : Colors.foreground
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: prevMa; anchors.fill: parent; hoverEnabled: true
            onClicked: MprisState.previous()
        }
    }

    // ── Play/Pause (slides down when expanded) ────────────────────────
    Item {
        width: 44; height: 44
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
        anchors.topMargin: root.expanded ? 62 : 0
        Behavior on anchors.topMargin { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }
        Text {
            anchors.centerIn: parent
            text: root.isPlaying ? "\uF04C" : "\uF04B"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 18
            color: ppMa.containsMouse ? Qt.lighter(Colors.color4, 1.4) : Colors.color4
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: ppMa; anchors.fill: parent; hoverEnabled: true
            onClicked: MprisState.playPause()
        }
    }

    // ── Next button (full-width hit area) ─────────────────────────────
    Item {
        width: 44; height: 36
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 110 }
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Text {
            anchors.centerIn: parent; text: "\uF051"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 14
            color: nextMa.containsMouse ? Qt.lighter(Colors.foreground, 1.5) : Colors.foreground
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: nextMa; anchors.fill: parent; hoverEnabled: true
            onClicked: MprisState.next()
        }
    }

    // ── Track progress ────────────────────────────────────────────────
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 3
        visible: root.active
        color: Qt.lighter(Colors.background, 1.5)
        Rectangle {
            width: root.trackLen > 0
                ? parent.width * Math.min(1, root.trackPos / root.trackLen)
                : 0
            height: 3; color: Colors.color4
            Behavior on width { NumberAnimation { duration: 800 } }
        }
    }
}
