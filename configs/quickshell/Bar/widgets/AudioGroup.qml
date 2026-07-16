import QtQuick
import "../../Theme"

// ponytail: misnamed - this is the WiFi bar widget. Thin view over NetworkState
// (single source of truth shared with the dashboard); all polling lives there.
Item {
    id: root
    width: 44; height: 44

    property bool   menuOpen:   false
    property string promptSSID: ""      // non-empty → show password prompt for this SSID

    // Forwarders - keep Bar.qml's wifiWidget.* bindings unchanged
    readonly property bool   wifiOn:         NetworkState.wifiOn
    readonly property string wifiName:       NetworkState.wifiName
    readonly property string wifiIP:         NetworkState.wifiIP
    readonly property int    wifiSignal:     NetworkState.wifiSignal
    readonly property bool   ethOn:          NetworkState.ethOn
    readonly property string ethConn:        NetworkState.ethConn
    readonly property var    networks:       NetworkState.networks
    readonly property string connectingSSID: NetworkState.connectingSSID

    function toggleWifi()                    { NetworkState.toggleWifi() }
    function disconnectWifi()                { NetworkState.disconnectWifi() }
    function connectToNetwork(ssid, secured) { promptSSID = ""; NetworkState.connectToNetwork(ssid, secured) }
    function connectWithPassword(ssid, pass) { promptSSID = ""; NetworkState.connectWithPassword(ssid, pass) }

    onMenuOpenChanged: {
        NetworkState.wifiMenuOpen = menuOpen
        if (menuOpen) NetworkState.refreshWifi()
    }

    // Failed connect on a secured network → reopen the password prompt (exit-code driven)
    Connections {
        target: NetworkState
        function onLastWifiErrorChanged() {
            if (NetworkState.lastWifiError !== "" && NetworkState.lastAttemptSecured)
                root.promptSSID = NetworkState.lastAttemptSSID
        }
    }

    // ── Bar button icon ───────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        text: root.ethOn            ? "\u{F0200}"
            : !root.wifiOn          ? "\u{F092D}"
            : root.wifiName === ""  ? "\u{F092C}"
            : root.wifiSignal > 75  ? "\u{F092B}"
            : root.wifiSignal > 50  ? "\u{F092A}"
            : root.wifiSignal > 25  ? "\u{F0929}"
            :                         "\u{F0928}"
        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
        color: root.ethOn            ? Colors.color5
             : root.wifiName !== ""  ? Colors.foreground
             : root.wifiOn           ? Colors.color8
             :                         Colors.color1
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    MouseArea { anchors.fill: parent; onClicked: root.menuOpen = !root.menuOpen }
}
