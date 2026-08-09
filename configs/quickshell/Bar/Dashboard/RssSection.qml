import QtQuick
import "../../Theme"

// News tab - merged RSS/Atom feed list; click opens the article in the browser.
Item {
    id: root

    property color accent: Colors.color2
    readonly property var rss: RssState

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width: parent.width; height: 22
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: rss.items.length > 0 ? rss.items.length + " stories" : "News"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: Colors.color6
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: rss.loading ? "Loading…" : "\u{F0450}  Refresh"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: refreshMa.containsMouse ? root.accent : Colors.color8
                MouseArea { id: refreshMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                    onClicked: rss.refresh()
                }
            }
        }

        Text {
            width: parent.width
            visible: rss.error !== ""
            text: rss.error
            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
            color: Colors.color1; wrapMode: Text.WordWrap
        }

        Flickable {
            width: parent.width
            height: parent.height - 30
            contentHeight: newsCol.implicitHeight; clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: newsCol; width: parent.width; spacing: 2

                Repeater {
                    model: rss.items
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 46; radius: 6
                        color: itemMa.containsMouse
                            ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.07)
                            : "transparent"

                        Column {
                            anchors { left: parent.left; leftMargin: 12; right: dateText.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Text {
                                width: parent.width
                                text: modelData.title
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                color: Colors.foreground
                                elide: Text.ElideRight; wrapMode: Text.NoWrap; maximumLineCount: 1
                            }
                            Text {
                                width: parent.width
                                text: modelData.source
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                                color: root.accent
                                elide: Text.ElideRight; wrapMode: Text.NoWrap; maximumLineCount: 1
                            }
                        }
                        Text {
                            id: dateText
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: modelData.date
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 8
                            color: Colors.color8
                        }
                        MouseArea { id: itemMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: if (modelData.link !== "") Qt.openUrlExternally(modelData.link)
                        }
                    }
                }
            }
        }
    }
}
