import QtQuick
import "../../Theme"
import "../../Notifications"

Item {
    id: root
    width: parent.width; height: parent.height

    // Use a local counter that increments on every history change to force UI refresh
    property int _rev: 0
    Connections {
        target: NotifState
        function onHistoryChanged() { root._rev++ }
    }

    // Header
    Item {
        id: header
        width: parent.width; height: 20
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "NOTIFICATIONS"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
            color: Colors.color6
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8
            Rectangle {
                visible: root._rev >= 0 && NotifState.history.length > 0
                width: countText.implicitWidth + 10; height: 16; radius: 8
                color: Colors.color4
                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: NotifState.history.length
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 9; font.bold: true
                    color: Colors.background
                }
            }
            Text {
                visible: root._rev >= 0 && NotifState.history.length > 0
                text: "Clear"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: clearMa.containsMouse ? Colors.color1 : Colors.color8
                Behavior on color { ColorAnimation { duration: 150 } }
                MouseArea {
                    id: clearMa; anchors.fill: parent; anchors.margins: -2
                    hoverEnabled: true
                    onClicked: NotifState.clearHistory()
                }
            }
        }
    }

    // Empty state
    Text {
        anchors.centerIn: parent
        visible: root._rev >= 0 && NotifState.history.length === 0
        text: "No notifications"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
        color: Colors.color8
    }

    // Scrollable list
    Flickable {
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: 8 }
        contentHeight: notifCol.implicitHeight
        clip: true
        visible: root._rev >= 0 && NotifState.history.length > 0

        Column {
            id: notifCol
            width: parent.width; spacing: 4

            Repeater {
                model: root._rev >= 0 ? NotifState.history.length : 0
                delegate: Rectangle {
                    required property int index
                    readonly property var entry: NotifState.history[index]
                    width: notifCol.width
                    height: nBody.visible ? 64 : 44
                    radius: 8
                    color: Qt.darker(Colors.background, 1.12)
                    border.color: Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.15)
                    border.width: 1

                    Item {
                        id: nIcon
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        width: 24; height: 24
                        Image {
                            anchors.fill: parent
                            source: entry.appIcon && entry.appIcon.includes("/") ? "file://" + entry.appIcon : ""
                            fillMode: Image.PreserveAspectFit; smooth: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "\u{F0F3}"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 16
                            color: Colors.color4
                            visible: !(entry.appIcon && entry.appIcon.includes("/"))
                        }
                    }

                    Column {
                        anchors {
                            left: nIcon.right; leftMargin: 8
                            right: nRight.left; rightMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2
                        Text {
                            width: parent.width
                            text: entry.summary || entry.appName
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 11; font.bold: true
                            color: Colors.foreground; elide: Text.ElideRight
                        }
                        Text {
                            id: nBody
                            width: parent.width
                            text: entry.body
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                            color: Colors.color7; elide: Text.ElideRight
                            maximumLineCount: 1; wrapMode: Text.WordWrap
                            visible: entry.body !== ""
                        }
                    }

                    Column {
                        id: nRight
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Text {
                            anchors.right: parent.right
                            text: entry.timestamp || ""
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                            color: Colors.color8
                        }
                        Text {
                            anchors.right: parent.right
                            text: "\uF00D"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                            color: nCloseMa.containsMouse ? Colors.color1 : Colors.color8
                            Behavior on color { ColorAnimation { duration: 150 } }
                            MouseArea {
                                id: nCloseMa; anchors.fill: parent; anchors.margins: -4
                                hoverEnabled: true
                                onClicked: NotifState.removeFromHistory(entry.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
