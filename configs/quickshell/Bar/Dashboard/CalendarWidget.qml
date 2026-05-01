import QtQuick
import QtQuick.Layouts
import "../../Theme"

Item {
    id: root
    height: cal.implicitHeight

    property var _now: new Date()
    property int viewMonth: _now.getMonth()
    property int viewYear:  _now.getFullYear()

    Timer { interval: 60000; running: true; repeat: true; onTriggered: root._now = new Date() }

    readonly property bool isCurrentMonth: viewMonth === _now.getMonth() && viewYear === _now.getFullYear()

    function isoWeek(d) {
        const dt = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        const day = dt.getUTCDay() || 7
        dt.setUTCDate(dt.getUTCDate() + 4 - day)
        const yearStart = new Date(Date.UTC(dt.getUTCFullYear(), 0, 1))
        return Math.ceil((((dt - yearStart) / 86400000) + 1) / 7)
    }

    function calCells(year, month, todayDate) {
        const days = new Date(year, month + 1, 0).getDate()
        const firstDow = (new Date(year, month, 1).getDay() + 6) % 7
        let cells = []
        for (let i = 0; i < firstDow; i++) cells.push({day: 0, isToday: false})
        for (let d = 1; d <= days; d++) cells.push({day: d, isToday: d === todayDate})
        return cells
    }

    function prevMonth() {
        if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear-- }
        else root.viewMonth--
    }
    function nextMonth() {
        if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear++ }
        else root.viewMonth++
    }
    function goToday() {
        root.viewMonth = root._now.getMonth()
        root.viewYear  = root._now.getFullYear()
    }

    readonly property string monthName: {
        const names = ["January","February","March","April","May","June",
                       "July","August","September","October","November","December"]
        return names[root.viewMonth]
    }

    Column {
        id: cal
        width: parent.width
        spacing: 8

        // Navigation header
        Item {
            width: parent.width; height: 20

            Text {
                id: prevBtn
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "\u{F0141}"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                color: prevMa.containsMouse ? Colors.color4 : Colors.foreground
                Behavior on color { ColorAnimation { duration: 100 } }
                MouseArea { id: prevMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: root.prevMonth() }
            }

            Text {
                anchors.centerIn: parent
                text: root.monthName + " " + root.viewYear
                font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true
                color: Colors.foreground
            }

            Text {
                id: nextBtn
                anchors { right: weekLabel.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: "\u{F0142}"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                color: nextMa.containsMouse ? Colors.color4 : Colors.foreground
                Behavior on color { ColorAnimation { duration: 100 } }
                MouseArea { id: nextMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: root.nextMonth() }
            }

            Text {
                id: weekLabel
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: root.isCurrentMonth ? "W" + root.isoWeek(root._now) : ""
                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                color: Colors.color8
            }
        }

        // Day of week header + date header
        Item {
            width: parent.width; height: 14
            visible: root.isCurrentMonth
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: Qt.formatDate(root._now, "dddd, d MMMM")
                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                color: Colors.color8
            }
        }

        GridLayout {
            width: parent.width
            columns: 7; columnSpacing: 0; rowSpacing: 2

            Repeater {
                model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                    color: Colors.color8
                }
            }

            Repeater {
                model: root.calCells(root.viewYear, root.viewMonth,
                           root.isCurrentMonth ? root._now.getDate() : -1)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        anchors.centerIn: parent
                        color: modelData.isToday ? Colors.color4 : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.day > 0 ? modelData.day : ""
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                        color: modelData.isToday ? Colors.background : Colors.foreground
                    }
                }
            }
        }

        // "Today" button when not on current month
        Rectangle {
            width: 60; height: 22; radius: 6
            visible: !root.isCurrentMonth
            anchors.horizontalCenter: parent.horizontalCenter
            color: todayMa.containsMouse ? Qt.lighter(Colors.color4, 1.2) : Colors.color4
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                anchors.centerIn: parent
                text: "Today"
                font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                color: Colors.background
            }
            MouseArea { id: todayMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.goToday() }
        }
    }
}
