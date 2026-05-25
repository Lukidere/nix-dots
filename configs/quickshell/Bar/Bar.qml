import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../Theme"
import "./widgets"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors { left: true; top: true; bottom: true }
    exclusiveZone: 56
    implicitWidth: (wifiWidget.menuOpen || btWidget.menuOpen || batWidget.menuOpen) ? 56 + 280 : 56
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    Rectangle {
        x: 0; y: 0; width: 56; height: parent.height
        color: Colors.background
    }

    Item {
        id: barContent
        x: 0; y: 0; width: 56; height: parent.height
        opacity: 0
        Component.onCompleted: startupAnim.start()
        NumberAnimation { id: startupAnim; target: barContent; property: "opacity"; from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }

        Column {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
            spacing: 4
            Cachy {}
            Clock { barScreen: root.modelData }
            Cpu { barScreen: root.modelData }
        }

        Rectangle {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            anchors.verticalCenterOffset: -54
            width: 20; height: 1; color: Colors.color8; opacity: 0.25
        }
        Rectangle {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            anchors.verticalCenterOffset: 54
            width: 20; height: 1; color: Colors.color8; opacity: 0.25
        }

        Column {
            anchors { centerIn: parent }
            spacing: 4
            Mpris {}
            Workspaces { barScreen: root.modelData }
            ActiveWindow { barScreen: root.modelData }
        }

        Column {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 }
            spacing: 4
            TrayWidget      { barWindow: root; barScreen: root.modelData }
            AudioGroup      { id: wifiWidget }
            BrightnessGroup { id: btWidget }
            Battery         { id: batWidget; barScreen: root.modelData }
            PowerButton     { barScreen: root.modelData }
        }
    }

    Connections {
        target: wifiWidget
        function onMenuOpenChanged() { if (wifiWidget.menuOpen) { btWidget.menuOpen = false; batWidget.menuOpen = false } }
    }
    Connections {
        target: btWidget
        function onMenuOpenChanged() { if (btWidget.menuOpen) { wifiWidget.menuOpen = false; batWidget.menuOpen = false } }
    }
    Connections {
        target: batWidget
        function onMenuOpenChanged() { if (batWidget.menuOpen) { wifiWidget.menuOpen = false; btWidget.menuOpen = false } }
    }

    Rectangle {
        id: wifiPopup
        x: 60
        y: Math.max(8, Math.min(root.height - height - 8, root.height - 440))
        width: 272
        height: Math.min(root.height - 16, wifiFlick.contentHeight + 24)
        visible: opacity > 0
        opacity: wifiWidget.menuOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: Qt.darker(Colors.background, 1.08)
        border.color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.25)
        border.width: 1; radius: 10; clip: true

        Flickable {
            id: wifiFlick
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 12 }
            height: Math.min(root.height - 40, contentHeight)
            contentHeight: wifiColumn.implicitHeight
            contentWidth: width
            clip: true

            Column {
                id: wifiColumn
                width: wifiFlick.width - 24
                x: 12
                spacing: 6

                Row {
                    width: parent.width; spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: wifiWidget.ethOn ? "\u{F0200}" : "\u{F092B}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 16
                        color: wifiWidget.ethOn ? Colors.color5 : Colors.color4
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: wifiWidget.ethOn ? "Network" : "Wi-Fi"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 13; font.bold: true
                        color: Colors.foreground
                    }
                    Item { width: parent.width - 148; height: 1 }
                    Rectangle {
                        visible: !wifiWidget.ethOn
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38; height: 18; radius: 9
                        color: wifiWidget.wifiOn ? Colors.color4 : Qt.lighter(Colors.background, 1.5)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: wifiWidget.wifiOn ? "ON" : "OFF"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 9; font.bold: true
                            color: wifiWidget.wifiOn ? Colors.background : Colors.color6
                        }
                        MouseArea { anchors.fill: parent; onClicked: wifiWidget.toggleWifi() }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter; text: "\u2715"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: Colors.color8
                        MouseArea { anchors.fill: parent; onClicked: wifiWidget.menuOpen = false }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.2) }

                // Current connection info
                Column {
                    width: parent.width; spacing: 4
                    visible: wifiWidget.wifiName !== "" || wifiWidget.ethOn

                    Item {
                        width: parent.width; height: 14
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: "Connected"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color2
                        }
                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: wifiWidget.wifiIP; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color6
                        }
                    }
                    Text {
                        text: wifiWidget.ethOn ? (wifiWidget.ethConn || "Ethernet") : wifiWidget.wifiName
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true; color: Colors.foreground
                    }
                    Item {
                        width: parent.width; height: 12
                        visible: wifiWidget.wifiName !== ""
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: "Signal"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color6
                        }
                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 6
                            Text {
                                text: wifiWidget.wifiSignal + "%"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.foreground
                            }
                            Rectangle {
                                width: 56; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter
                                color: Qt.lighter(Colors.background, 1.4)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, wifiWidget.wifiSignal / 100))
                                    height: 4; radius: 2
                                    color: wifiWidget.wifiSignal > 60 ? Colors.color2 : wifiWidget.wifiSignal > 30 ? Colors.color3 : Colors.color1
                                    Behavior on width { NumberAnimation { duration: 400 } }
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 26; radius: 6
                        visible: wifiWidget.wifiName !== ""
                        color: dcHover.hovered ? Qt.lighter(Colors.color1, 1.2) : Qt.rgba(Colors.color1.r, Colors.color1.g, Colors.color1.b, 0.8)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        HoverHandler { id: dcHover }
                        Text { anchors.centerIn: parent; text: "Disconnect"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.background }
                        MouseArea { anchors.fill: parent; onClicked: wifiWidget.disconnectWifi() }
                    }
                }

                Rectangle {
                    width: parent.width; height: 1
                    color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.2)
                    visible: wifiWidget.wifiOn
                }

                Text {
                    visible: wifiWidget.wifiOn && wifiWidget.networks.length > 0
                    text: "AVAILABLE NETWORKS (" + wifiWidget.networks.length + ")"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color6
                }

                // Password prompt
                Column {
                    width: parent.width; spacing: 6
                    visible: wifiWidget.promptSSID !== ""

                    Text {
                        width: parent.width
                        text: "Password for \u201C" + wifiWidget.promptSSID + "\u201D"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                        color: Colors.foreground; wrapMode: Text.WordWrap; elide: Text.ElideRight
                    }
                    Rectangle {
                        width: parent.width; height: 30; radius: 6
                        color: Qt.lighter(Colors.background, 1.3)
                        border.color: wifiPassInput.activeFocus ? Colors.color4 : Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.3)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Item {
                            anchors { fill: parent; margins: 8 }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: wifiPassInput.text === ""
                                text: "Password..."; font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                color: Colors.color8; opacity: 0.6
                            }
                            TextInput {
                                id: wifiPassInput
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                echoMode: TextInput.Password; color: Colors.foreground
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                onVisibleChanged: { if (visible) forceActiveFocus() }
                                Keys.onReturnPressed: {
                                    if (text.length > 0) { wifiWidget.connectWithPassword(wifiWidget.promptSSID, text); text = "" }
                                }
                            }
                        }
                    }
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 64; height: 24; radius: 6
                            color: connBtnHov.hovered ? Qt.lighter(Colors.color4, 1.2) : Colors.color4
                            Behavior on color { ColorAnimation { duration: 100 } }
                            HoverHandler { id: connBtnHov }
                            Text { anchors.centerIn: parent; text: "Connect"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.background }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (wifiPassInput.text.length > 0) { wifiWidget.connectWithPassword(wifiWidget.promptSSID, wifiPassInput.text); wifiPassInput.text = "" }
                                }
                            }
                        }
                        Rectangle {
                            width: 56; height: 24; radius: 6
                            color: canBtnHov.hovered ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.3)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            HoverHandler { id: canBtnHov }
                            Text { anchors.centerIn: parent; text: "Cancel"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.foreground }
                            MouseArea { anchors.fill: parent; onClicked: { wifiWidget.promptSSID = ""; wifiPassInput.text = "" } }
                        }
                    }
                }

                // Network list
                Column {
                    width: parent.width; spacing: 2
                    visible: wifiWidget.wifiOn && wifiWidget.promptSSID === ""

                    Repeater {
                        model: wifiWidget.networks
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width; height: 40; radius: 6
                            property bool isConnecting: wifiWidget.connectingSSID === modelData.ssid
                            color: modelData.inUse
                                ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.15)
                                : isConnecting
                                    ? Qt.rgba(Colors.color3.r, Colors.color3.g, Colors.color3.b, 0.1)
                                    : netRowHov.hovered
                                        ? Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.1)
                                        : "transparent"
                            HoverHandler { id: netRowHov }
                            Row {
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                spacing: 8
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.signal > 70 ? "\u{F092B}" : modelData.signal > 40 ? "\u{F092A}" : "\u{F0928}"
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                                    color: modelData.inUse ? Colors.color4 : Colors.color6
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text {
                                        text: modelData.ssid
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                        color: modelData.inUse ? Colors.color4 : Colors.foreground
                                        font.bold: modelData.inUse; elide: Text.ElideRight; width: 150
                                    }
                                    Text {
                                        text: (modelData.security ? "\u{F0341} " + modelData.security : "Open") + "  \u00B7  " + modelData.signal + "%"
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8
                                    }
                                }
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: modelData.inUse ? "Connected" : isConnecting ? "Connecting..." : ""
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 9
                                color: modelData.inUse ? Colors.color2 : Colors.color3
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !modelData.inUse && wifiWidget.connectingSSID === ""
                                onClicked: wifiWidget.connectToNetwork(modelData.ssid)
                            }
                        }
                    }
                }

                Text {
                    visible: !wifiWidget.wifiOn
                    width: parent.width; text: "Wi-Fi is off"
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.color8
                }
                Text {
                    visible: wifiWidget.wifiOn && wifiWidget.networks.length === 0 && wifiWidget.promptSSID === ""
                    width: parent.width; text: "Scanning..."
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.color8
                }
                Item { width: 1; height: 4 }
            }
        }
    }

    Rectangle {
        id: btPopupRect
        x: 60
        y: Math.max(8, Math.min(root.height - height - 8, root.height - 420))
        width: 272
        height: Math.min(root.height - 16, btFlick.contentHeight + 24)
        visible: opacity > 0
        opacity: btWidget.menuOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: Qt.darker(Colors.background, 1.08)
        border.color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.25)
        border.width: 1; radius: 10; clip: true

        Flickable {
            id: btFlick
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 12 }
            height: Math.min(root.height - 40, contentHeight)
            contentHeight: btColumn.implicitHeight
            contentWidth: width
            clip: true

            Column {
                id: btColumn
                width: btFlick.width - 24
                x: 12
                spacing: 6

                Row {
                    width: parent.width; spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: NetworkState.btConn ? "\u{F00B1}" : "\u{F00AF}"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 16
                        color: NetworkState.btConn ? Colors.color4 : Colors.foreground
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Bluetooth"; font.family: "Iosevka Nerd Font"; font.pixelSize: 13; font.bold: true; color: Colors.foreground
                    }
                    Item { width: parent.width - 158; height: 1 }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38; height: 18; radius: 9
                        color: NetworkState.btOn ? Colors.color4 : Qt.lighter(Colors.background, 1.5)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: NetworkState.btOn ? "ON" : "OFF"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 9; font.bold: true
                            color: NetworkState.btOn ? Colors.background : Colors.color6
                        }
                        MouseArea { anchors.fill: parent; onClicked: btWidget.toggleBluetooth() }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter; text: "\u2715"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: Colors.color8
                        MouseArea { anchors.fill: parent; onClicked: btWidget.menuOpen = false }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.2) }

                // Connected device info
                Column {
                    width: parent.width; spacing: 4
                    visible: NetworkState.btConn

                    Text { text: "Connected"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color2 }
                    Item {
                        width: parent.width; height: 16
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: NetworkState.btDevice; font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true; color: Colors.foreground
                        }
                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: NetworkState.btMAC; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 1
                    color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.2)
                    visible: NetworkState.btOn
                }

                // Paired devices
                Column {
                    width: parent.width; spacing: 4
                    visible: NetworkState.btOn && NetworkState.pairedDevs.length > 0

                    Text { text: "PAIRED DEVICES (" + NetworkState.pairedDevs.length + ")"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color6 }

                    Repeater {
                        model: NetworkState.pairedDevs
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width; height: 40; radius: 6
                            color: pdHov.hovered ? Qt.lighter(Colors.background, 1.3) : "transparent"
                            HoverHandler { id: pdHov }
                            Row {
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                spacing: 8
                                Text {
                                    text: "\u{F00AF}"; font.family: "Iosevka Nerd Font"; font.pixelSize: 13
                                    color: modelData.connected ? Colors.color4 : Colors.color6
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: modelData.name; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: modelData.connected ? Colors.color4 : Colors.foreground; font.bold: modelData.connected }
                                    Text { text: modelData.mac; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8 }
                                }
                            }
                            Row {
                                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                spacing: 4
                                Text {
                                    visible: btWidget.busyMAC === modelData.mac
                                    text: modelData.connected ? "Disconnecting..." : "Connecting..."
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color3
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    visible: btWidget.busyMAC !== modelData.mac
                                    width: modelData.connected ? 80 : 64; height: 22; radius: 6
                                    color: btnConnHov.hovered ? (modelData.connected ? Qt.lighter(Colors.color1, 1.2) : Qt.lighter(Colors.color4, 1.2)) : (modelData.connected ? Colors.color1 : Colors.color4)
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    HoverHandler { id: btnConnHov }
                                    Text { anchors.centerIn: parent; text: modelData.connected ? "Disconnect" : "Connect"; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.background }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: modelData.connected ? btWidget.disconnectDevice(modelData.mac) : btWidget.connectDevice(modelData.mac)
                                    }
                                }
                                Rectangle {
                                    visible: !modelData.connected && btWidget.busyMAC !== modelData.mac
                                    width: 50; height: 22; radius: 6
                                    color: rmvHov.hovered ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.3)
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    HoverHandler { id: rmvHov }
                                    Text { anchors.centerIn: parent; text: "Remove"; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.foreground }
                                    MouseArea { anchors.fill: parent; onClicked: btWidget.removeDevice(modelData.mac) }
                                }
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.2); visible: NetworkState.btOn }

                // Scan controls
                Item {
                    width: parent.width; height: 28
                    visible: NetworkState.btOn

                    Rectangle {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        width: scanLbl.implicitWidth + 20; height: 24; radius: 6
                        color: btWidget.scanning ? (scanHov.hovered ? Qt.lighter(Colors.color3, 1.2) : Colors.color3) : (scanHov.hovered ? Qt.lighter(Colors.color4, 1.2) : Colors.color4)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        HoverHandler { id: scanHov }
                        Text {
                            id: scanLbl; anchors.centerIn: parent
                            text: btWidget.scanning ? "\u{F0453}  Scanning..." : "\u{F0453}  Scan"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.background
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (btWidget.scanning) {
                                    btWidget.scanning = false
                                    btWidget._scanOff.running = false; btWidget._scanOff.running = true
                                } else {
                                    btWidget.scannedDevs = []
                                    btWidget.scanning = true
                                    btWidget._scanOn.running = false; btWidget._scanOn.running = true
                                }
                            }
                        }
                    }
                }

                // Scanned devices
                Column {
                    width: parent.width; spacing: 2
                    visible: btWidget.scanning && btWidget.scannedDevs.length > 0

                    Text { text: "AVAILABLE (" + btWidget.scannedDevs.length + ")"; font.family: "Iosevka Nerd Font"; font.pixelSize: 10; color: Colors.color6 }

                    Repeater {
                        model: btWidget.scannedDevs
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width; height: 40; radius: 6
                            color: sdHov.hovered ? Qt.lighter(Colors.background, 1.3) : "transparent"
                            HoverHandler { id: sdHov }
                            Row {
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                spacing: 8
                                Text { text: "\u{F00AF}"; font.family: "Iosevka Nerd Font"; font.pixelSize: 13; color: Colors.color6; anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: modelData.name; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.foreground }
                                    Text { text: modelData.mac; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8 }
                                }
                            }
                            Row {
                                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                Text { visible: btWidget.busyMAC === modelData.mac; text: "Pairing..."; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color3; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    visible: btWidget.busyMAC !== modelData.mac
                                    width: 40; height: 22; radius: 6
                                    color: pairHov.hovered ? Qt.lighter(Colors.color4, 1.2) : Colors.color4
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    HoverHandler { id: pairHov }
                                    Text { anchors.centerIn: parent; text: "Pair"; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.background }
                                    MouseArea { anchors.fill: parent; onClicked: btWidget.pairDevice(modelData.mac) }
                                }
                            }
                        }
                    }
                }

                Text { visible: !NetworkState.btOn; width: parent.width; text: "Bluetooth is off"; horizontalAlignment: Text.AlignHCenter; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.color8 }
                Text { visible: NetworkState.btOn && NetworkState.pairedDevs.length === 0 && !btWidget.scanning; width: parent.width; text: "No paired devices"; horizontalAlignment: Text.AlignHCenter; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.color8 }
                Text { visible: btWidget.scanning && btWidget.scannedDevs.length === 0; width: parent.width; text: "Searching for devices..."; horizontalAlignment: Text.AlignHCenter; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: Colors.color8 }
                Item { width: 1; height: 4 }
            }
        }
    }

    Rectangle {
        id: batPopup
        x: 60
        y: Math.max(8, Math.min(root.height - height - 8, root.height - 220))
        width: 268; height: batColumn.implicitHeight + 24
        visible: opacity > 0
        opacity: batWidget.menuOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: Qt.darker(Colors.background, 1.08)
        border.color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.25)
        border.width: 1; radius: 10

        property string profile:     "balanced"
        property bool   profileBusy: false

        Process {
            id: _profilePoll
            command: ["powerprofilesctl", "get"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: { const p = this.text.trim(); if (p) batPopup.profile = p }
            }
        }
        Timer {
            interval: 5000; running: true; repeat: true
            onTriggered: { _profilePoll.running = false; _profilePoll.running = true }
        }
        Process {
            id: _profileSet
            running: false
            onRunningChanged: {
                if (!running) {
                    batPopup.profileBusy = false
                    _profilePoll.running = false; _profilePoll.running = true
                }
            }
        }

        Column {
            id: batColumn
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            spacing: 10

            Row {
                width: parent.width; spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter; text: batWidget.icon; font.family: "Iosevka Nerd Font"; font.pixelSize: 22; color: batWidget.batColor }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                    Text { text: batWidget.ready ? batWidget.pct + "%" : "—"; font.family: "Iosevka Nerd Font"; font.pixelSize: 16; font.bold: true; color: batWidget.batColor }
                    Text { text: batWidget.status; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; color: Colors.color8 }
                }
                Item { width: parent.width - 160; height: 1 }
                Text {
                    anchors.verticalCenter: parent.verticalCenter; text: "\u2715"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 12; color: Colors.color8
                    MouseArea { anchors.fill: parent; onClicked: batWidget.menuOpen = false }
                }
            }

            Rectangle {
                width: parent.width; height: 4; radius: 2
                color: Qt.lighter(Colors.background, 1.5)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, batWidget.pct / 100))
                    height: 4; radius: 2; color: batWidget.batColor
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.2) }
            Text { text: "POWER PROFILE"; font.family: "Iosevka Nerd Font"; font.pixelSize: 9; font.bold: true; color: Colors.color6 }

            Row {
                width: parent.width; spacing: 6
                Repeater {
                    model: [
                        { id: "power-saver",  label: "Saver",    icon: "\u{F0209}" },
                        { id: "balanced",     label: "Balanced", icon: "\u{F0140}" },
                        { id: "performance",  label: "Perf",     icon: "\u{F04B5}" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        property bool active: batPopup.profile === modelData.id
                        width: (parent.width - 12) / 3; height: 52; radius: 8
                        color: active ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.2) : profHover.hovered ? Qt.rgba(Colors.color8.r, Colors.color8.g, Colors.color8.b, 0.1) : Qt.lighter(Colors.background, 1.2)
                        border.color: active ? Qt.rgba(Colors.color4.r, Colors.color4.g, Colors.color4.b, 0.5) : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        HoverHandler { id: profHover }
                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; font.family: "Iosevka Nerd Font"; font.pixelSize: 16; color: active ? Colors.color4 : Colors.color8; Behavior on color { ColorAnimation { duration: 150 } } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.family: "Iosevka Nerd Font"; font.pixelSize: 8; color: active ? Colors.color4 : Colors.color8 }
                        }
                        MouseArea {
                            anchors.fill: parent; enabled: !batPopup.profileBusy && !active
                            onClicked: {
                                batPopup.profile = modelData.id; batPopup.profileBusy = true
                                _profileSet.command = ["powerprofilesctl", "set", modelData.id]
                                _profileSet.running = false; _profileSet.running = true
                            }
                        }
                    }
                }
            }
            Item { width: 1; height: 2 }
        }
    }
}
