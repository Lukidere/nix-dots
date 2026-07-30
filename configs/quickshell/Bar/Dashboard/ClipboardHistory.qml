import QtQuick
import "../../Theme"

// Thin view over the shared ClipboardState singleton.
Item {
    id: root
    width: parent.width; height: parent.height
    readonly property var entries: ClipboardState.entries

    // Header
    Item {
        id: header
        width: parent.width; height: 20
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text {
                visible: root.entries.length > 0
                text: root.entries.length + " items"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                color: Colors.color8
            }
            Text {
                visible: root.entries.length > 0
                text: "Clear"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: clipClearMa.containsMouse ? Colors.color1 : Colors.color8
                Behavior on color { ColorAnimation { duration: 150 } }
                MouseArea {
                    id: clipClearMa; anchors.fill: parent; anchors.margins: -2
                    hoverEnabled: true
                    onClicked: ClipboardState.clear()
                }
            }
        }
    }

    // Empty state
    Text {
        anchors.centerIn: parent
        visible: root.entries.length === 0
        text: "Clipboard empty"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
        color: Colors.color8
    }

    // Scrollable list
    Flickable {
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: 8 }
        contentHeight: clipCol.implicitHeight
        clip: true
        visible: root.entries.length > 0

        Column {
            id: clipCol
            width: parent.width; spacing: 3

            Repeater {
                model: root.entries.length
                delegate: Rectangle {
                    required property int index
                    readonly property var entry: root.entries[index]
                    width: clipCol.width; height: 36
                    radius: 8
                    color: clipMa.containsMouse ? Qt.lighter(Colors.background, 1.3) : Qt.darker(Colors.background, 1.12)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors { left: parent.left; leftMargin: 10; right: clipTs.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: entry.text.replace(/\n/g, " ")
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                        color: Colors.foreground; elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        id: clipTs
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: entry.timestamp
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                        color: Colors.color8
                    }
                    MouseArea {
                        id: clipMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: ClipboardState.copy(entry.text)
                    }
                }
            }
        }
    }
}
