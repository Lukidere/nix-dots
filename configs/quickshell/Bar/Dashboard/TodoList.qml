import QtQuick
import QtCore
import "../../Theme"

Item {
    id: root
    height: col.implicitHeight

    Settings {
        id: todoStorage
        category: "QuickshellTodo"
        property string items: "[]"
    }

    property var todos: []

    Component.onCompleted: {
        try { root.todos = JSON.parse(todoStorage.items) } catch(e) { root.todos = [] }
    }

    function saveTodos() {
        todoStorage.items = JSON.stringify(root.todos)
    }

    function addTodo(text) {
        if (!text.trim()) return
        root.todos = root.todos.concat([{ text: text.trim(), done: false }])
        saveTodos()
    }

    function toggleTodo(idx) {
        root.todos = root.todos.map((t, i) =>
            i === idx ? { text: t.text, done: !t.done } : t)
        saveTodos()
    }

    function removeTodo(idx) {
        root.todos = root.todos.filter((_, i) => i !== idx)
        saveTodos()
    }

    Column {
        id: col
        width: parent.width
        spacing: 6

        // Input row
        Rectangle {
            width: parent.width; height: 32; radius: 8
            color: Qt.lighter(Colors.background, 1.3)
            border.color: todoInput.activeFocus ? Colors.color4 : "transparent"
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Row {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 16
                    color: Colors.color4
                }
                TextInput {
                    id: todoInput
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28
                    font.pixelSize: 12; font.family: "Iosevka Nerd Font"
                    color: Colors.foreground
                    selectionColor: Colors.color4
                    Keys.onReturnPressed: { root.addTodo(todoInput.text); todoInput.text = "" }
                }
            }
        }

        // Todo items
        Column {
            width: parent.width; spacing: 3

            Repeater {
                model: root.todos
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: col.width; height: 30; radius: 6
                    color: Qt.lighter(Colors.background, 1.2)

                    Row {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 8

                        // Checkbox
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 3
                            color: modelData.done ? Colors.color4 : "transparent"
                            border.color: modelData.done ? Colors.color4 : Colors.color8
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                visible: modelData.done
                                text: "\uF00C"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                                color: Colors.background
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.toggleTodo(index)
                            }
                        }

                        // Label
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 16 - 20 - 24
                            text: modelData.text
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                            color: modelData.done ? Colors.color8 : Colors.foreground
                            font.strikeout: modelData.done
                            elide: Text.ElideRight
                        }

                        // Delete
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uF00D"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                            color: delMa.containsMouse ? Colors.color1 : Colors.color8
                            Behavior on color { ColorAnimation { duration: 100 } }
                            MouseArea {
                                id: delMa; anchors.fill: parent
                                anchors.margins: -4; hoverEnabled: true
                                onClicked: root.removeTodo(index)
                            }
                        }
                    }
                }
            }
        }

        // Empty state
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.todos.length === 0
            text: "No tasks yet"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
            color: Colors.color8
        }
    }
}
