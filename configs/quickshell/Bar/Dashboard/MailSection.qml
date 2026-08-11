import QtQuick
import "../../Theme"

// Mail tab - inbox list (unread bold), click opens simplified body and marks read.
Item {
    id: root

    property color accent: Colors.color4
    readonly property var gm: GmailState

    // ── Inbox list ──────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 8
        visible: gm.configured && !gm.readOpen

        Item {
            width: parent.width; height: 22
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: gm.unreadCount > 0 ? gm.unreadCount + " unread" : "Inbox"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: Colors.color6
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: gm.loading ? "Loading…" : "\u{F0450}  Refresh"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: refreshMa.containsMouse ? root.accent : Colors.color8
                MouseArea { id: refreshMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                    onClicked: gm.refresh()
                }
            }
        }

        Text {
            width: parent.width
            visible: gm.error !== ""
            text: gm.error
            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
            color: Colors.color1; wrapMode: Text.WordWrap
        }

        Flickable {
            id: listFlick
            width: parent.width
            height: parent.height - 30
            contentHeight: mailCol.implicitHeight; clip: true
            boundsBehavior: Flickable.StopAtBounds

            // thin scrollbar indicator (plain QtQuick, no Controls dep)
            Rectangle {
                z: 2
                width: 4; radius: 2
                visible: listFlick.contentHeight > listFlick.height
                color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.6)
                x: listFlick.contentX + listFlick.width - width
                height: listFlick.height * listFlick.visibleArea.heightRatio
                y: listFlick.contentY + listFlick.visibleArea.yPosition * listFlick.height
            }

            Column {
                id: mailCol; width: parent.width - 8; spacing: 2

                Repeater {
                    model: gm.mails
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 44; radius: 6
                        color: mailMa.containsMouse
                            ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.07)
                            : "transparent"

                        Rectangle {
                            visible: modelData.unread
                            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                            width: 6; height: 6; radius: 3
                            color: root.accent
                        }
                        Column {
                            anchors { left: parent.left; leftMargin: 16; right: dateText.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Text {
                                width: parent.width
                                text: modelData.subject
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                font.bold: modelData.unread
                                color: Colors.foreground
                                elide: Text.ElideRight; wrapMode: Text.NoWrap; maximumLineCount: 1
                            }
                            Text {
                                width: parent.width
                                text: modelData.from
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                                font.bold: modelData.unread
                                color: Colors.color8
                                elide: Text.ElideRight; wrapMode: Text.NoWrap; maximumLineCount: 1
                            }
                        }
                        Text {
                            id: dateText
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: modelData.date.split(" ").slice(0, 3).join(" ")
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 8
                            color: Colors.color8
                        }
                        MouseArea { id: mailMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: gm.openMail(modelData.uid)
                        }
                    }
                }
            }
        }
    }

    // ── Mail body view ──────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 8
        visible: gm.configured && gm.readOpen

        Item {
            width: parent.width; height: 24
            Rectangle {
                width: 60; height: 24; radius: 6
                color: backMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.3)
                Text { anchors.centerIn: parent; text: "\u{F0141} Back"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.foreground }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; onClicked: gm.closeMail() }
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "Open in Gmail"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: gmailMa.containsMouse ? root.accent : Colors.color8
                MouseArea { id: gmailMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                    onClicked: Qt.openUrlExternally("https://mail.google.com")
                }
            }
        }

        Column {
            width: parent.width; spacing: 2
            Text {
                width: parent.width
                text: gm.readSubject
                font.family: "Iosevka Nerd Font"; font.pixelSize: 13; font.bold: true
                color: Colors.foreground; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: gm.readFrom + "  ·  " + gm.readDate
                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                color: Colors.color8; elide: Text.ElideRight
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.lighter(Colors.background, 1.4) }

        Flickable {
            id: bodyFlick
            width: parent.width
            height: parent.height - 90
            contentHeight: bodyText.implicitHeight + 8; clip: true
            boundsBehavior: Flickable.StopAtBounds

            // thin scrollbar indicator (plain QtQuick, no Controls dep)
            Rectangle {
                z: 2
                width: 4; radius: 2
                visible: bodyFlick.contentHeight > bodyFlick.height
                color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.6)
                x: bodyFlick.contentX + bodyFlick.width - width
                height: bodyFlick.height * bodyFlick.visibleArea.heightRatio
                y: bodyFlick.contentY + bodyFlick.visibleArea.yPosition * bodyFlick.height
            }

            Text {
                id: bodyText
                width: parent.width - 8
                text: gm.readBody !== "" ? gm.readBody : (gm.loading ? "Loading…" : "")
                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                color: Colors.foreground
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
        }
    }

    // ── Not configured ──────────────────────────────────────────────
    Column {
        width: parent.width; spacing: 8
        visible: !gm.configured
        Text { text: "Gmail not configured"; font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true; color: Colors.foreground }
        Text {
            width: parent.width; wrapMode: Text.WordWrap
            text: "1. Google Account → Security → 2-Step Verification → App passwords\n2. Generate one for Mail\n3. Write  address@gmail.com:app-password  into ~/.config/qs-gmail/credentials  (chmod 600)"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color8
        }
        Rectangle {
            width: 90; height: 26; radius: 6; color: root.accent
            Text { anchors.centerIn: parent; text: "Re-check"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.background }
            MouseArea { anchors.fill: parent; onClicked: gm.checkStatus() }
        }
    }
}
