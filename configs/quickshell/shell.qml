import QtQuick
import Quickshell
import "./Bar"
import "./Bar/Dashboard"
import "./Launcher"
import "./Notifications"

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Variants {
        model: Quickshell.screens
        DashboardWindow {}
    }
    Variants {
        model: Quickshell.screens
        TriggerStrip {}
    }
    Variants {
        model: Quickshell.screens
        TooltipOverlay {}
    }
    Variants {
        model: Quickshell.screens
        PowerMenu {}
    }
    Variants {
        model: Quickshell.screens
        NotifWindow {}
    }
    Launcher {}
}
