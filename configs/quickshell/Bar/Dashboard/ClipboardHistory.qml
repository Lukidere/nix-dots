import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    width: parent.width; height: parent.height

    property var entries: []
    property string _lastClip: ""

    // Watch clipboard via wl-paste (works on Wayland without focus)
    Process {
        id: clipWatcher
        command: ["wl-paste", "--watch", "cat"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const clip = this.text.trim()
                if (clip !== "" && clip !== root._lastClip) {
                    root._lastClip = clip
                    const entry = {
                        text: clip,
                        timestamp: new Date().toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'})
                    }
                    let filtered = root.entries.filter(e => e.text !== clip)
                    root.entries = [entry].concat(filtered).slice(0, 50)
                }
            }
        }
    }

    // Also poll periodically in case watcher misses something
    readonly property Process _clipPoll: Process {
        command: ["wl-paste", "--no-newline"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const clip = this.text.trim()
                if (clip !== "" && clip !== root._lastClip) {
                    root._lastClip = clip
                    const entry = {
                        text: clip,
                        timestamp: new Date().toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'})
                    }
                    let filtered = root.entries.filter(e => e.text !== clip)
                    root.entries = [entry].concat(filtered).slice(0, 50)
                }
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true
            onTriggered: { root._clipPoll.running = false; root._clipPoll.running = true } }

    Process { id: _clipCopy; running: false }

    // Header
    Item {
        id: header
        width: parent.width; height: 20
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "CLIPBOARD"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 10
            color: Colors.color6
        }
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
                    onClicked: root.entries = []
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
                        onClicked: {
                            root._lastClip = entry.text
                            _clipCopy.command = ["sh", "-c", "printf '%s' '" + entry.text.replace(/'/g, "'\\''") + "' | wl-copy"]
                            _clipCopy.running = false; _clipCopy.running = true
                        }
                    }
                }
            }
        }
    }
}
