import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var modelData
    property bool isBottom: false
    property bool isRight:  false
    screen: modelData
    color: "transparent"
    visible: true
    anchors {
        // right strip spans top+bottom; H strips span left+right
        top:    !root.isBottom
        bottom:  root.isBottom || root.isRight
        left:   !root.isRight
        right:  true
    }
    // wider hit zone - easier mouse capture
    implicitHeight: root.isRight ? 0 : 4
    implicitWidth:  root.isRight ? 6 : 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    // mask limits input to hit item - rest of edge strip click-through
    mask: Region { item: hitItem }

    Item {
        id: hitItem
        // right edge → tall vertical strip; top → wide horizontal strip
        x: root.isRight ? 0 : Math.round((parent.width - hitW) / 2)
        y: root.isRight ? Math.round((parent.height - hitH) / 2) : 0
        width:  root.isRight ? parent.width : hitW
        height: root.isRight ? hitH : parent.height
        // hit zone matches panel size (DashboardWindow panelW formula + volPanelRect height)
        readonly property int hitW: Math.min(680, Math.max(560, Math.round(parent.width * 0.34)))
        // right strip: 3px-wide edge strip spanning the panel's height - the ONLY
        // opener now that volPanelArea is keep-open-only (no phantom catch zone)
        readonly property int hitH: 380

        Timer {
            // short dwell so a quick pass to the edge does not open the panel,
            // but a deliberate rest at the 3px edge does
            id: _showDelay; interval: 300
            onTriggered: DashboardState.showVolPanel(root.modelData.name)
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                if (root.isBottom || root.isRight) _showDelay.restart()
                else DashboardState.show(root.modelData.name)
            }
            onExited: {
                _showDelay.stop()
                if (root.isBottom || root.isRight) DashboardState.scheduleHideVolPanel()
                else DashboardState.scheduleHide()
            }
        }
    }
}
