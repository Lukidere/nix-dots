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
    anchors {
        // ponytail: right strip spans top+bottom; H strips span left+right
        top:    !root.isBottom
        bottom:  root.isBottom || root.isRight
        left:   !root.isRight
        right:  true
    }
    // ponytail: wider hit zone - easier mouse capture
    implicitHeight: root.isRight ? 0 : 10
    implicitWidth:  root.isRight ? 12 : 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    // ponytail: mask limits input to hit item - rest of edge strip click-through
    mask: Region { item: hitItem }

    Item {
        id: hitItem
        // ponytail: right edge → tall vertical strip; top → wide horizontal strip
        x: root.isRight ? 0 : Math.round((parent.width - hitW) / 2)
        y: root.isRight ? Math.round((parent.height - hitH) / 2) : 0
        width:  root.isRight ? parent.width : hitW
        height: root.isRight ? hitH : parent.height
        // ponytail: hit zone matches panel size (DashboardWindow panelW formula + volPanelRect height)
        readonly property int hitW: Math.min(520, Math.max(440, Math.round(parent.width * 0.26)))
        readonly property int hitH: 380

        Timer {
            // ponytail: 40ms feels instant without misfiring on edge skim
            id: _showDelay; interval: 40
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
